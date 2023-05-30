const std = @import("std");
const storage = @import("storage.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const World = @import("world.zig").World;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;

pub const Context = struct {
    const Self = @This();

    allocator: Allocator,

    world: *World,
    world_mutex: *Mutex,

    pub fn spawn(self: *Self) !Entity {
        self.world_mutex.lock();
        var entity = self.world.spawnEntity();
        self.world_mutex.unlock();

        return entity;
    }

    // TODO: Add queries
};
