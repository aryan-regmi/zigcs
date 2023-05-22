const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const System = *const fn (ctx: *Context) anyerror!void;

const Entity = usize;

const World = struct {
    const Self = @This();

    num_entities: usize,

    fn spawnEntity(self: *Self) Entity {
        const entity = self.num_entities;
        self.num_entities += 1;
        return entity;
    }
};

const Context = struct {
    const Self = @This();

    world: *World,

    pub fn init(world: *World) Self {
        return Self{ .world = world };
    }

    pub fn spawn(self: *Self) Entity {
        return self.world.*.spawnEntity();
    }
};

const App = struct {
    const Self = @This();

    allocator: Allocator,
    world: World,
    systems: ArrayList(System),

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .systems = ArrayList(System).init(allocator),
            .world = World{ .num_entities = 0 },
        };
    }

    pub fn deinit(self: *const Self) void {
        self.systems.deinit();
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self.systems.append(system);
    }

    // TODO: Move to a scheduler struct eventually?
    fn runSystem(ctx: *Context, system: System) !void {
        try system(ctx);
    }

    pub fn run(self: *Self) !void {
        var threads = try std.ArrayList(std.Thread).initCapacity(self.allocator, self.systems.items.len);
        defer threads.deinit();

        var ctx = Context.init(&self.world);

        for (self.systems.items) |system| {
            // FIXME: Make sharing the world thread-safe (mutex?)
            try threads.append(try std.Thread.spawn(.{}, runSystem, .{ &ctx, system }));
        }

        for (threads.items) |thr| {
            thr.join();
        }
    }
};

test "can spawn entities with systems" {
    const testSystems = struct {
        fn system1(ctx: *Context) !void {
            var entity1 = ctx.spawn();
            try testing.expectEqual(entity1, 0);

            var entity2 = ctx.spawn();
            try testing.expectEqual(entity2, 1);
        }

        fn system2(ctx: *Context) !void {
            // NOTE: Sleep so system2 runs after system1
            std.time.sleep(100);

            var entity3 = ctx.spawn();
            try testing.expectEqual(entity3, 2);

            var entity4 = ctx.spawn();
            try testing.expectEqual(entity4, 3);
        }
    };

    var app = App.init(testing.allocator);
    defer app.deinit();

    try app.addSystem(testSystems.system1);
    try app.addSystem(testSystems.system2);
    try app.run();
}
