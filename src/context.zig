const std = @import("std");
const storage = @import("storage.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const World = @import("world.zig").World;
const Entity = storage.Entity;

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
    pub fn query(self: *Self, comptime QueryTypes: anytype) Query(QueryTypes) {
        _ = self;

        inline for (QueryTypes) |_type| {
            std.debug.print("\t{}\n", .{_type});
        }

        return Query(QueryTypes){};
    }
};

/// Represents mutable components in queries.
pub fn Mut(comptime T: type) type {
    return struct { _val: T };
}

/// Represents immutable components in queries.
pub fn Ref(comptime T: type) type {
    return struct { _val: T };
}

pub fn Query(comptime QueryTypes: anytype) type {
    _ = QueryTypes;
    return struct {};
}
