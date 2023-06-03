const std = @import("std");
const storage = @import("storage.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const World = @import("world.zig").World;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;
const NullableErasedComponent = storage.NullableErasedComponent;

/// A context used for the systems.
pub const Context = struct {
    const Self = @This();

    _allocator: Allocator,

    _world: *World,
    _world_mutex: *Mutex,

    /// Spawn a new Entity.
    pub fn spawn(self: *Self) !Entity {
        self._world_mutex.lock();
        var entity = self._world.spawnEntity();
        self._world_mutex.unlock();

        return entity;
    }

    // FIXME:: Implement this!
    pub fn query(self: *Self, comptime mutable_types: ?[]const type, comptime immutable_types: ?[]const type) !QueryBuilder {
        _ = mutable_types;
        _ = self;

        // NOTE: Just debugging for now!
        //
        // TODO: Get names of the types and find the relavent info in the entity map?
        inline for (immutable_types.?) |immutable_type| {
            std.debug.print("{}\n", .{immutable_type});
        }

        return QueryBuilder{};
    }
};

pub const QueryBuilder = struct {
    // FIXME:: Implement this!
    pub fn build(self: *QueryBuilder) !Query {
        _ = self;
        return Query{};
    }
};

pub const Query = struct {

    // TODO: Add iterator
    // TODO: Add getComponent()
};
