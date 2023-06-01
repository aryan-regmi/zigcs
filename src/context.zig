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

    fn componentTypeListContainsComponent(component_types_list: [][]const u8, component_type: []const u8) bool {
        for (component_types_list) |component_type_| {
            if (std.mem.eql(u8, component_type_, component_type)) {
                return true;
            }
        }

        return false;
    }

    /// Returns a query to grab the components from.
    pub fn build(self: *QueryBuilder) !Query {
        var components_map: std.AutoArrayHashMapUnmanaged(u64, []ErasedComponent) = .{};

        for (self._query_types.items) |query_type| {
            self._ctx._world_mutex.lock();

            // TODO: Only store entities that have the requested component in the entity map?
            var entity_map = self._ctx._world._entity_map;
            var valid_components: std.ArrayListUnmanaged(ErasedComponent) = .{};
            var current_entity: u64 = undefined;
            for (entity_map.keys()) |entity_id| {
                var entity_component_types: std.ArrayListUnmanaged([]const u8) = entity_map.get(entity_id).?;

                // If entity_component_types contains the query_type, then grab that component storage
                if (componentTypeListContainsComponent(entity_component_types.items, query_type)) {
                    var component_storage = self._ctx._world.getComponentStorage(query_type).?;

                    // TODO: Grab the component value for that entity from the component_storage
                    var component: NullableErasedComponent = component_storage.items[entity_id];

                    try valid_components.append(self._allocator, component.Some);
                    current_entity = entity_id;
                }
            }
            try components_map.put(self._allocator, current_entity, try valid_components.toOwnedSlice(self._allocator));

            self._ctx._world_mutex.unlock();
        }

        // Free up the memory allocatoed to store the query types.
        self._query_types.deinit(self._allocator);

        return Query{
            ._allocator = self._allocator,
            ._component_map = components_map, // TODO: Add actual components here
        };
    }
};

pub const Query = struct {
    _allocator: Allocator,

    /// Maps an entity to the list of components associated with it
    _component_map: std.AutoArrayHashMapUnmanaged(u64, []ErasedComponent),

    pub fn deinit(self: *Query) void {
        // TODO: Free all memory of component map!
        _ = self;
    }

    // TODO: Add getComponent function to get a component at an index
    // TODO: Add iterator to iterate over non-null components in the component storages (needs to `zip`/join the ArrayLists)
};
