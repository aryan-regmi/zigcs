const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const System = *const fn (ctx: Context) void;

const Context = struct {};

const App = struct {
    const Self = @This();

    allocator: Allocator,
    systems: ArrayList(System),

    pub fn init(allocator: Allocator) Self {
        return Self{ .allocator = allocator, .systems = ArrayList(System).init(allocator) };
    }

    pub fn deinit(self: *const Self) void {
        self.systems.deinit();
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self.systems.append(system);
    }

    // TODO: Move to a scheduler struct eventually?
    fn runSystem(ctx: Context, system: System) void {
        system(ctx);
    }

    pub fn run(self: *Self) !void {
        var threads = try std.ArrayList(std.Thread).initCapacity(self.allocator, self.systems.items.len);
        defer threads.deinit();

        for (self.systems.items) |system| {
            var ctx = Context{};
            try threads.append(try std.Thread.spawn(.{}, runSystem, .{ ctx, system }));
        }

        for (threads.items) |thr| {
            thr.join();
        }
    }
};

test "can create app and run systems" {
    const testSystems = struct {
        fn system1(_: Context) void {
            std.log.debug("\nSystem 1", .{});
        }

        fn system2(_: Context) void {
            std.log.debug("\nSystem 2", .{});
        }
    };

    var app = App.init(testing.allocator);
    defer app.deinit();

    try app.addSystem(testSystems.system1);
    try app.addSystem(testSystems.system2);
    try app.run();
}
