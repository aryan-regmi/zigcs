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

    // FIXME: Implement this!
    pub fn query(self: *Self, comptime mutable_types: ?[]const type, comptime immutable_types: ?[]const type) !Query {
        _ = self;
        _ = mutable_types;

        // TODO: Get names of the types and find the relevant info in the entity map
        std.debug.print("\tQuery Types: \n", .{});
        inline for (immutable_types.?) |immutable_type| {
            std.debug.print("\t\t{}\n", .{immutable_type});
        }

        return Query{};
    }
};

/// Represents mutable components in queries.
pub const Mut = struct {};

/// Represents immutable components in queries.
pub const Ref = struct {};

pub const Query = struct {
    // TODO: Add iterator
    // TODO: Add getComponent()
};
