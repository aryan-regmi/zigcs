const std = @import("std");
const testing = std.testing;
const zigcs = @import("zigcs");
const App = zigcs.App;
const Context = zigcs.Context;
const System = zigcs.System;
const Stage = zigcs.Stage;
const StageID = zigcs.StageID;

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
            try ctx.addComponent(e0, Location{ .x = 20, .y = 50 });

            var e1 = try ctx.spawn();
            try ctx.addComponent(e1, Location{});
        }

        fn system2(ctx: *Context) !void {
            _ = ctx;
            // TODO: Query for component values
            //
            // comptime var types = [_]type{ Name, Location };
            // ctx.query(&types);

            std.debug.print("System2!\n", .{});
        }

        fn system3(ctx: *Context) !void {
            _ = ctx;
            std.debug.print("System3!\n", .{});
        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    var stage0_systems = [_]System{TestSystems.system1};
    try app.addStage(StageID{ .Named = .{
        .name = "Setup",
        .order = 0,
    } }, &stage0_systems);

    var stage1_systems = [_]System{TestSystems.system2};
    try app.addStage(StageID{ .Named = .{
        .name = "Queries",
        .order = 1,
    } }, &stage1_systems);

    try app.run();
}
