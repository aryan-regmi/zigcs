const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Context = @import("context.zig").Context;
const World = @import("world.zig").World;

pub const System = *const fn (ctx: Context) anyerror!void;

// TODO: Add stages to run systems in!
pub const App = struct {
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
    fn runSystem(ctx: Context, system: System) !void {
        try system(ctx);
    }

    /// Runs all the systems in the [App](App)
    pub fn run(self: *Self) !void {
        var threads = try std.ArrayList(std.Thread).initCapacity(self.allocator, self.systems.items.len);
        defer threads.deinit();

        var mutex = std.Thread.Mutex{};

        for (self.systems.items) |system| {
            // FIXME: Make sharing the world thread-safe (mutex on world?)
            var ctx = Context.init(&self.world, &mutex);
            try threads.append(try std.Thread.spawn(.{}, runSystem, .{ ctx, system }));
        }

        for (threads.items) |thr| {
            thr.join();
        }
    }
};

// NOTE: Change to c_allocator if running valgrind!
test "can spawn entities" {
    std.testing.log_level = .debug;

    // const allocator = std.heap.c_allocator;
    const allocator = testing.allocator;

    const testSystems = struct {
        fn system1(ctx: Context) !void {
            const e1 = ctx.spawn().build();
            std.log.debug("[System 1] Entity {}", .{e1});

            const e2 = ctx.spawn().build();
            std.log.debug("[System 1] Entity {}", .{e2});
        }

        fn system2(ctx: Context) !void {
            const e1 = ctx.spawn().build();
            std.log.debug("[System 2] Entity {}", .{e1});

            const e2 = ctx.spawn().build();
            std.log.debug("[System 2] Entity {}", .{e2});
        }

        fn system3(ctx: Context) !void {
            // NOTE: Sleep so this runs last
            std.time.sleep(1000);
            try testing.expectEqual(ctx.world.num_entities, 4);
        }
    };

    // var app = App.init(testing.allocator);
    var app = App.init(allocator);
    defer app.deinit();

    try app.addSystem(testSystems.system1);
    try app.addSystem(testSystems.system2);
    try app.addSystem(testSystems.system3);
    try app.run();
}

test "can spawn entities with components" {
    // const allocator = std.heap.c_allocator;
    const allocator = testing.allocator;

    const Health = struct { hp: usize };
    const Age = struct { age: usize };

    const SpawnEntitySystem = struct {
        // TODO: Write tests to check for components!!
        fn run(ctx: Context) !void {
            const NPC = ctx.spawn().with(Health{ .hp = 50 }).build();
            _ = NPC;

            const PLAYER = ctx
                .spawn()
                .with(Age{ .age = 22 })
                .with(Health{ .hp = 99 })
                .build();
            _ = PLAYER;
        }
    };

    // var app = App.init(testing.allocator);
    var app = App.init(allocator);
    defer app.deinit();

    try app.addSystem(SpawnEntitySystem.run);
    try app.run();
}
