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

test "Can spawn entities with components" {
    const ALLOC = testing.allocator;

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

    try app.addStage(StageID{ .Idx = 0 }, &[_]System{TestSystems.system1});
    try app.addStage(StageID{ .Idx = 1 }, &[_]System{TestSystems.system2});

    try app.run();
}

test "Can query for components" {
    const ALLOC = testing.allocator;

    const TestSystems = struct {
        fn setupSystem(ctx: *Context) !void {
            var player1 = try ctx.spawn();
            try player1.addComponent(ctx, Name{ .first = "Aryan", .last = "Regmi" });
            try player1.addComponent(ctx, Location{ .x = 90, .y = 10 });

            var npc = try ctx.spawn();
            try npc.addComponent(ctx, Velocity{});
            try npc.addComponent(ctx, Location{});

            var npc2 = try ctx.spawn();
            try npc2.addComponent(ctx, Velocity{});
            try npc2.addComponent(ctx, Location{});

            std.debug.print("Setup System\n", .{});
        }

        fn querySystem(ctx: *Context) !void {
            std.debug.print("Query System\n", .{});

            // Query players
            {
                var players_query = ctx.query(.{
                    Mut(Location),
                    Ref(Name),
                }).?;
                defer players_query.deinit();

                var player = try players_query.single();
                var player_pos = try players_query.getComponentMut(player, Location);
                try testing.expectEqual(Location{ .x = 90, .y = 10 }, player_pos.*);
                player_pos.x = 10;

                // Update mutable value (Location)
                var updated_pos = try players_query.getComponent(player, Location);
                try testing.expectEqual(Location{ .x = 10, .y = 10 }, updated_pos.*);

                var player_name = try players_query.getComponent(player, Name);
                try testing.expectEqual(Name{ .first = "Aryan", .last = "Regmi" }, player_name.*);
            }

            // Query npcs
            {
                var npcs_query = ctx.query(.{
                    Ref(Location),
                    Ref(Velocity),
                }).?;
                defer npcs_query.deinit();

                var npcs = npcs_query.iterator();
                while (npcs.next()) |entity| {
                    var npc_pos = try npcs_query.getComponent(entity, Location);
                    try testing.expectEqual(Location{}, npc_pos.*);

                    var npc_vel = try npcs_query.getComponent(entity, Velocity);
                    try testing.expectEqual(Velocity{}, npc_vel.*);
                }
            }
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

    try app.addStage(StageID{ .Idx = 0 }, &[_]System{TestSystems.setupSystem});
    try app.addStage(StageID{ .Idx = 1 }, &[_]System{TestSystems.querySystem});

    std.debug.print("=>\n", .{});
    try app.run();
}

// TODO: Add tests to check performace limits of ECS: Spawn a bunch of entities and add components and query them.
