const std = @import("std");
const testing = std.testing;
const context = @import("context.zig");
const App = @import("app.zig").App;
const Context = context.Context;
const EntityBuilder = context.EntityBuilder;

// NOTE: ECS was implemented using methods described here: https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/

// TODO: Move these (integration) tests to the tests/ directory, and import the lib as a module

test "Can add and run systems in App" {
    const ALLOC = testing.allocator;

    const TestSystems = struct {
        fn system1(_: *Context) !void {
            std.debug.print("\nSystem 1", .{});
        }

        fn system2(_: *Context) !void {
            std.debug.print("\nSystem 2", .{});
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
            std.time.sleep(1);

            var e0 = try ctx.spawn();
            try ctx.addComponent(e0, Name{ .first = "Aryan", .last = "Regmi" });
            std.debug.print("\nSystem 1: Entity {}", .{e0});
        }

        fn system2(ctx: *Context) !void {
            std.time.sleep(1);

            var e1 = try ctx.spawn();
            try ctx.addComponent(e1, Location{});
            std.debug.print("\nSystem 2: Entity {}", .{e1});
        }
    };

    var app = try App.init(ALLOC);
    defer app.deinit();

    std.debug.print("\n", .{});
    try app.addSystem(TestSystems.system1);
    try app.addSystem(TestSystems.system2);

    try app.run();
}
