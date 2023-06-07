const std = @import("std");
const storage = @import("storage.zig");
const query = @import("query.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const World = @import("world.zig").World;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;
const Query = query.Query;

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

    pub fn query(self: *Self, comptime QueryTypes: anytype) !Query(QueryTypes) {
        var query_components: std.AutoArrayHashMapUnmanaged(u64, std.ArrayListUnmanaged(ErasedComponent)) = .{};

        // Grab entity map from world
        self._world_mutex.lock(); // TODO: Make it so mutex is only accuired if there are `Mut` queries?
        const entity_map = self._world._entity_map;
        self._world_mutex.unlock();

        inline for (QueryTypes) |_type| {
            // Make sure QueryTypes are either `Ref` or `Mut`
            comptime {
                if (!(std.meta.trait.hasField("_zigcs_mutable_query_type")(_type) and std.meta.trait.hasField("_val")(_type))) {
                    @compileError("Invalid query type: Must pass `Ref(T)` or `Mut(T)`");
                }
            }

            // Grab the storage from the world
            self._world_mutex.lock();
            var erased_storage = self._world.getComponentStorage(_type.TYPE_NAME).?;

            var component_storage = erased_storage.asComponentStorage(_type.TYPE);

            // Get non-null entries from the storage
            var associated_entities = entity_map.getPtr(_type.TYPE_NAME).?;
            for (associated_entities.items) |entity_id| {
                var component_list = query_components.getPtr(entity_id);
                var erased_component = ErasedComponent{
                    ._type_name = _type.TYPE_NAME,
                    ._ptr = &component_storage._storage.items[entity_id].?,
                };

                if (component_list != null) {
                    try component_list.?.append(self._allocator, erased_component);
                } else {
                    var new_components_list: std.ArrayListUnmanaged(ErasedComponent) = .{};
                    try new_components_list.append(self._allocator, erased_component);
                    try query_components.put(self._allocator, entity_id, new_components_list);
                }
            }

            self._world_mutex.unlock();
        }

        return Query(QueryTypes){
            ._allocator = self._allocator,
            ._associated_component_map = query_components,
        };
    }
};
