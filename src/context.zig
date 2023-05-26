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
        var entity = try self.world.spawnEntity();
        self.world_mutex.unlock();

        return entity;
    }

    pub fn addComponent(self: *Self, entity: Entity, component: anytype) !void {
        self.world_mutex.lock();
        try self.world.withComponent(entity, component);
        self.world_mutex.unlock();
    }

    // pub fn query(self: *Self, comptime component_types: []type) void {
    //     inline for (component_types) |t| {
    //         var x = self.world.getComponent(0, t).?;
    //         _ = x;
    //     }
    // }
};
