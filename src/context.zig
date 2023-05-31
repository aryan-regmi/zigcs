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

    /// Create query builder.
    pub fn buildQuery(self: *Self) QueryBuilder {
        return QueryBuilder{
            ._allocator = self._allocator,
            ._ctx = self,
        };
    }
};

pub const QueryBuilder = struct {
    _allocator: Allocator,

    _ctx: *Context,

    _query_types: std.ArrayListUnmanaged([]const u8) = .{},

    // TODO: Differentiate btwn mutable and immutable queries, so the mutex isn't held by each immutable query
    //
    /// Specify type to query.
    pub fn with(self: *QueryBuilder, comptime ComponentType: type) !void {
        try self._query_types.append(self._allocator, @typeName(ComponentType));
    }

    /// Returns a query to grab the components from.
    pub fn build(self: *QueryBuilder) !Query {
        //  Grab the corresponding ArrayLists from the world!
        var map: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(NullableErasedComponent)) = .{};
        for (self._query_types.items) |query_type| {
            self._ctx._world_mutex.lock();
            var component_storage = self._ctx._world.getComponentStorage(query_type).?;
            try map.put(self._allocator, query_type, component_storage);
            self._ctx._world_mutex.unlock();
        }

        // Free up the memory allocatoed to store the query types.
        self._query_types.deinit(self._allocator);

        return Query{ ._allocator = self._allocator, ._component_storages = map };
    }
};

pub const Query = struct {
    _allocator: Allocator,

    _component_storages: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(NullableErasedComponent)),

    /// Frees the memory used by the component storages map.
    ///
    /// NOTE: This doesn't free the memory used by the ArrayLists in the map, as those are allocated and freed by the world.
    pub fn deinit(self: *Query) void {
        self._component_storages.deinit(self._allocator);
    }

    // TODO: Add getComponent function to get a component at an index
    // TODO: Add iterator to iterate over non-null components in the component storages (needs to `zip`/join the ArrayLists)
};
