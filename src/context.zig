const std = @import("std");
const World = @import("world.zig").World;
const EntityBuilder = @import("entity.zig").EntityBuilder;

pub const Context = struct {
    const Self = @This();

    world: *World,
    world_mutex: *std.Thread.Mutex,

    pub fn init(world: *World, mutex: *std.Thread.Mutex) Self {
        return Self{ .world = world, .world_mutex = mutex };
    }

    pub fn spawn(self: Self) EntityBuilder {
        return EntityBuilder.init(self);
    }
};
