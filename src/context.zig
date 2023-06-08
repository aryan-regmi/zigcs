const std = @import("std");
const storage = @import("storage.zig");
const query = @import("query.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const World = @import("world.zig").World;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;
const AccessType = storage.AccessType;
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

    pub fn query(self: *Self, comptime QueryTypes: anytype) ?Query(QueryTypes) {
        var query_components: std.AutoArrayHashMapUnmanaged(u64, std.ArrayListUnmanaged(ErasedComponent)) = .{};

        // Grab entity map from world
        self._world_mutex.lock(); // TODO: Make it so mutex is only accuired if there are `Mut` queries?
        const entity_map = self._world._entity_map;
        self._world_mutex.unlock();

        inline for (QueryTypes) |type_| {
            // Make sure QueryTypes are either `Ref` or `Mut`
            comptime {
                if (!(std.meta.trait.hasField("_zigcs_query_type_marker")(type_) and std.meta.trait.hasField("_val")(type_))) {
                    @compileError("Invalid query type: Must pass `Ref(T)` or `Mut(T)`");
                }
            }

            // Grab the storage from the world
            self._world_mutex.lock();
            var erased_storage = self._world.getComponentStorage(type_.TYPE_NAME) orelse return null;

            var component_storage = erased_storage.asComponentStorage(type_.TYPE);

            // Get non-null entries from the storage
            var associated_entities = entity_map.getPtr(type_.TYPE_NAME).?;
            for (associated_entities.items) |entity_id| {
                var component_list = query_components.getPtr(entity_id);
                var erased_component = ErasedComponent{
                    ._type_name = type_.TYPE_NAME,
                    ._access = type_.ACCESS_TYPE,
                    ._ptr = &component_storage._storage.items[entity_id].?,
                };

                if (component_list != null) {
                    component_list.?.append(self._allocator, erased_component) catch return null;
                } else {
                    var new_components_list: std.ArrayListUnmanaged(ErasedComponent) = .{};
                    new_components_list.append(self._allocator, erased_component) catch return null;
                    query_components.put(self._allocator, entity_id, new_components_list) catch return null;
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
