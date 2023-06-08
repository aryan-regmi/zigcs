const std = @import("std");
const testing = std.testing;
const zigcs = @import("zigcs");
const App = zigcs.App;
const Context = zigcs.Context;
const System = zigcs.System;
const Stage = zigcs.Stage;
const StageID = zigcs.StageID;
const Ref = zigcs.Ref;
const Mut = zigcs.Mut;

// test "Can spawn entities with components" {
//     const ALLOC = testing.allocator;
//
//     const Location = struct {
//         x: f32 = 0,
//         y: f32 = 0,
//     };
//
//     const Name = struct {
//         first: []const u8,
//         last: []const u8,
//     };
//
//     const TestSystems = struct {
//         fn system1(ctx: *Context) !void {
//             var e0 = try ctx.spawn();
//             try e0.addComponent(ctx, Name{ .first = "Aryan", .last = "Regmi" });
//             try e0.addComponent(ctx, Location{ .x = 90, .y = 10 });
//
//             try testing.expectEqual(@as(u64, 0), e0.id);
//         }
//
//         fn system2(ctx: *Context) !void {
//             var e1 = try ctx.spawn();
//             try e1.addComponent(ctx, Location{});
//
//             try testing.expectEqual(@as(u64, 1), e1.id);
//         }
//     };
//
//     var app = try App.init(ALLOC);
//     defer app.deinit();
//
//     var stage1 = [_]System{TestSystems.system1};
//     var stage2 = [_]System{TestSystems.system2};
//     try app.addStage(StageID{ .Idx = 0 }, &stage1);
//     try app.addStage(StageID{ .Idx = 1 }, &stage2);
//
//     try app.run();
// }

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

    const Velocity = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    const TestSystems = struct {
        fn setupSystem(ctx: *Context) !void {
            var player1 = try ctx.spawn();
            try player1.addComponent(ctx, Name{ .first = "Aryan", .last = "Regmi" });
            try player1.addComponent(ctx, Location{ .x = 90, .y = 10 });

            var player2 = try ctx.spawn();
            try player2.addComponent(ctx, Name{ .first = "Another", .last = "Person" });
            try player2.addComponent(ctx, Location{ .x = 30, .y = 50 });

            var npc = try ctx.spawn();
            try npc.addComponent(ctx, Location{});

            var unused = try ctx.spawn();
            try unused.addComponent(ctx, Velocity{});

            std.debug.print("=>\nSetup System\n", .{});
        }

        fn querySystem(ctx: *Context) !void {
            std.debug.print("Query System\n", .{});

            var players_query = ctx.query(.{
                Mut(Location),
                Ref(Name),
            }).?;
            defer players_query.deinit();

            var players = players_query.iterator().?;
            defer players.deinit();

            while (players.next()) |entity| {
                var player_pos = players_query.getComponent(entity, Location);
                _ = player_pos;
                var player_name = players_query.getComponent(entity, Name);
                _ = player_name;
            }

            // NOTE: This will cause a compile time error!
            // var invalid = ctx.query(.{ Location, Name });
        }

        // NOTE: This is just to make sure stages and systems run independent of each other.
        fn freestandingSystem(_: *Context) !void {
            std.time.sleep(100);

            for (0..100_000) |i| {
                _ = i + 1;
            }

            std.debug.print("Freestanding System\n", .{});
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
