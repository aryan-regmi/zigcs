const testing = @import("std").testing;
const App = @import("app.zig").App;

// NOTE: ECS was implemented using methods described here: https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/

test "Can create App and spawn Entity" {
    const ALLOCATOR = testing.allocator;

    var app = try App.init(ALLOCATOR);
    defer app.deinit();

    const PLAYER = try app.spawnEntity();
    _ = PLAYER;
}

test "Can add components to an Entity" {
    const ALLOCATOR = testing.allocator;

    const Name = struct {
        name: []const u8,
    };

    const Location = struct {
        x: f32 = 0,
        y: f32 = 0,
        z: f32 = 0,
    };

    var app = try App.init(ALLOCATOR);
    defer app.deinit();

    const PLAYER = try app.spawnEntity();
    try app.withComponent(PLAYER, Name{ .name = "Aryan" }); // Add Name
    try app.withComponent(PLAYER, Location{}); // Add Location
    try app.withComponent(PLAYER, Name{ .name = "Aryan Regmi" }); // Update Name
}
