const std = @import("std");
const testing = std.testing;
const zigcs = @import("zigcs");
const App = zigcs.App;
const Context = zigcs.Context;

test "Can add and run systems in App" {
    const ALLOC = testing.allocator;

    const TestSystems = struct {
        fn system1(_: *Context) !void {
            const val = 2 + 2;
            try testing.expectEqual(4, val);
        }

        fn system2(_: *Context) !void {
            const val = 3 + 3;
            try testing.expectEqual(6, val);
        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    try app.addSystem(TestSystems.system1);
    try app.addSystem(TestSystems.system2);

    try app.run();
}

test "Can spawn entities with components" {
    const ALLOC = testing.allocator;

    const Location = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    const Name = struct {
        first: []const u8,
        last: []const u8,
    };

    const TestSystems = struct {
        fn system1(ctx: *Context) !void {
            var e0 = try ctx.spawn();
            try ctx.addComponent(e0, Name{ .first = "Aryan", .last = "Regmi" });
            try ctx.addComponent(e0, Location{ .x = 90, .y = 10 });

            try testing.expectEqual(@as(u64, 0), e0);
        }

        fn system2(ctx: *Context) !void {
            std.time.sleep(2); // Sleep so `system2` runs after `system1` (just so tests pass)

            var e1 = try ctx.spawn();
            try ctx.addComponent(e1, Location{});

            try testing.expectEqual(@as(u64, 1), e1);
        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    // std.debug.print("\n", .{});
    try app.addSystem(TestSystems.system1);
    try app.addSystem(TestSystems.system2);

    try app.run();
}

test "Can query for entities" {
    const ALLOC = testing.allocator;

    const Location = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    const Name = struct {
        first: []const u8,
        last: []const u8,
    };

    const TestSystems = struct {
        fn system1(ctx: *Context) !void {
            var e0 = try ctx.spawn();
            try ctx.addComponent(e0, Name{ .first = "Aryan", .last = "Regmi" });
            try ctx.addComponent(e0, Location{ .x = 90, .y = 10 });

            var e1 = try ctx.spawn();
            try ctx.addComponent(e1, Location{});
        }

        fn system2(ctx: *Context) !void {
            _ = ctx;
            // TODO: Query for component values

            // ctx.query()

        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    // std.debug.print("\n", .{});
    try app.addSystem(TestSystems.system1);
    try app.addSystem(TestSystems.system2);

    try app.run();
}
