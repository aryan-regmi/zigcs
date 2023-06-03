const std = @import("std");
const testing = std.testing;
const zigcs = @import("zigcs");
const App = zigcs.App;
const Context = zigcs.Context;
const System = zigcs.System;
const Stage = zigcs.Stage;
const StageID = zigcs.StageID;

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
            try e0.addComponent(ctx, Name{ .first = "Aryan", .last = "Regmi" });
            try e0.addComponent(ctx, Location{ .x = 90, .y = 10 });

            try testing.expectEqual(@as(u64, 0), e0.id);
        }

        fn system2(ctx: *Context) !void {
            var e1 = try ctx.spawn();
            try e1.addComponent(ctx, Location{});

            try testing.expectEqual(@as(u64, 1), e1.id);
        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    var stage1 = [_]System{TestSystems.system1};
    var stage2 = [_]System{TestSystems.system2};
    try app.addStage(StageID{ .Idx = 0 }, &stage1);
    try app.addStage(StageID{ .Idx = 1 }, &stage2);

    try app.run();
}

test "Can query for components" {
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
        fn setupSystem(ctx: *Context) !void {
            var e0 = try ctx.spawn();
            try e0.addComponent(ctx, Name{ .first = "Aryan", .last = "Regmi" });
            try e0.addComponent(ctx, Location{ .x = 90, .y = 10 });

            var e1 = try ctx.spawn();
            try e1.addComponent(ctx, Location{});

            std.log.warn("Setup System", .{});
        }

        fn querySystem(ctx: *Context) !void {
            std.log.warn("Query System", .{});

            var locations_query = try ctx.query(null, &[_]type{Location});
            var locations = try locations_query.build();
            _ = locations;

            var players_query = try ctx.query(null, &[_]type{ Location, Name });
            var players = try players_query.build();
            _ = players;
        }

        // NOTE: This is just to make sure stages and systems run independent of each other.
        fn freestandingSystem(_: *Context) !void {
            std.time.sleep(100);

            for (0..100_000) |i| {
                _ = i + 1;
            }

            std.log.warn("Freestanding System", .{});
        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    try app.addSystem(TestSystems.freestandingSystem);

    var stage1 = [_]System{TestSystems.setupSystem};
    var stage2 = [_]System{TestSystems.querySystem};
    try app.addStage(StageID{ .Idx = 0 }, &stage1);
    try app.addStage(StageID{ .Idx = 1 }, &stage2);

    try app.run();
}
