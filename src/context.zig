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

    allocator: Allocator,

    world: *World,
    world_mutex: *Mutex,

    /// Spawn a new Entity.
    pub fn spawn(self: *Self) !Entity {
        self.world_mutex.lock();
        var entity = self.world.spawnEntity();
        self.world_mutex.unlock();

        return entity;
    }

    /// Create query builder.
    pub fn buildQuery(self: *Self) QueryBuilder {
        return QueryBuilder{
            .allocator = self.allocator,
            .ctx = self,
        };
    }
};

pub const QueryBuilder = struct {
    allocator: Allocator,

    ctx: *Context,

    query_types: std.ArrayListUnmanaged([:0]const u8) = .{},

    // TODO: Differentiate btwn mutable and immutable queries, so the mutex isn't held by each immutable query
    //
    /// Specify type to query.
    pub fn with(self: *QueryBuilder, comptime ComponentType: type) !void {
        try self.query_types.append(self.allocator, @typeName(ComponentType));
    }

    /// Returns a query to grab the components from.
    pub fn build(self: *QueryBuilder) !Query {

        //  Grab the corresponding ArrayLists from the world!
        var map: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(NullableErasedComponent)) = .{};
        for (self.query_types.items) |query_type| {
            self.ctx.world_mutex.lock();
            var component_storage = self.ctx.world.getComponentStorage(query_type).?;
            try map.put(self.allocator, query_type, component_storage);
            self.ctx.world_mutex.unlock();
        }

        // Free up the memory allocatoed to store the query types.
        self.query_types.deinit(self.allocator);

        return Query{ .allocator = self.allocator, .component_storages = map };
    }
};

pub const Query = struct {
    allocator: Allocator,

    component_storages: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(NullableErasedComponent)),

    /// Frees the memory used by the component storages map.
    ///
    /// NOTE: This doesn't free the memory used by the ArrayLists in the map, as those are allocated and freed by the world.
    pub fn deinit(self: *Query) void {
        self.component_storages.deinit(self.allocator);
    }

    // TODO: Add getComponent function to get a component at an index
    // TODO: Add iterator to iterate over non-null components in the component storages (needs to `zip`/join the ArrayLists)
};
