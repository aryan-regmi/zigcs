const std = @import("std");
const storage = @import("storage.zig");
const Entity = storage.Entity;
const Allocator = std.mem.Allocator;
const ErasedComponent = storage.ErasedComponent;
const AccessType = storage.AccessType;

/// Represents mutable components in queries.
pub fn Mut(comptime T: type) type {
    return struct {
        pub const TYPE = T;
        pub const TYPE_NAME = @typeName(T);
        pub const ACCESS_TYPE = AccessType.Mut;

        _zigcs_query_type_marker: bool = true,
    };
}

/// Represents immutable components in queries.
pub fn Ref(comptime T: type) type {
    return struct {
        pub const TYPE = T;
        pub const TYPE_NAME = @typeName(T);
        pub const ACCESS_TYPE = AccessType.Ref;

        _zigcs_query_type_marker: bool = true,
    };
}

pub fn Query(comptime QueryTypes: anytype) type {
    return struct {
        const Self = @This();

        _allocator: Allocator,

        /// Map of entities and their associated components.
        _associated_component_map: std.AutoArrayHashMapUnmanaged(u64, std.ArrayListUnmanaged(ErasedComponent)),

        /// List of entities with components of all queried types.
        _valid_entities: std.ArrayListUnmanaged(Entity) = .{},

        const GetComponentError = error{ NoEntityHasSpecifiedComponentType, RefTypeAccessedMutably };

        /// Get immutable pointer to the component of the specified entity.
        pub fn getComponent(self: *Self, entity: Entity, comptime T: type) GetComponentError!*const T {
            // Grab the list from the _associated_component_map for the given entity
            var components: *std.ArrayListUnmanaged(ErasedComponent) = self._associated_component_map.getPtr(entity.id) orelse {
                return GetComponentError.NoEntityHasSpecifiedComponentType;
            };

            // Convert the ErasedComponent to the specified type if the typename matches
            for (components.items) |*erased_component| {
                if (std.mem.eql(u8, @typeName(T), erased_component._type_name)) {
                    return erased_component.asComponentType(T);
                }
            }

            return GetComponentError.NoEntityHasSpecifiedComponentType;
        }

        // FIXME: Have to worry about data races if pointer get updated?
        //
        /// Get mutable pointer to the component of the specified entity.
        pub fn getComponentMut(self: *Self, entity: Entity, comptime T: type) GetComponentError!*T {
            // Grab the list from the _associated_component_map for the given entity
            var components: *std.ArrayListUnmanaged(ErasedComponent) = self._associated_component_map.getPtr(entity.id) orelse {
                return GetComponentError.NoEntityHasSpecifiedComponentType;
            };

            // Convert the ErasedComponent to the specified type if the typename matches
            for (components.items) |*erased_component| {
                if (std.mem.eql(u8, @typeName(T), erased_component._type_name)) {
                    if (erased_component._access != AccessType.Mut) {
                        return GetComponentError.RefTypeAccessedMutably;
                    }
                    return erased_component.asComponentType(T);
                }
            }

            return GetComponentError.NoEntityHasSpecifiedComponentType;
        }

        /// Returns an iterator over the entities that have the queried components.
        pub fn iterator(self: *Self) ?QueryIter {
            // Get hash of each QueryType's names and combine it
            var requested_types_hash: ?u64 = null;
            inline for (QueryTypes) |type_| {
                if (requested_types_hash == null) {
                    requested_types_hash = std.hash_map.hashString(type_.TYPE_NAME);
                } else {
                    requested_types_hash = requested_types_hash.? ^ std.hash_map.hashString(type_.TYPE_NAME);
                }
            }

            // Loop through typenames of associated components and check if their hash matches the requested types
            var iter = self._associated_component_map.iterator();
            while (iter.next()) |entry| {
                var entity_types_hash: ?u64 = null;
                for (entry.value_ptr.items) |value| {
                    if (entity_types_hash == null) {
                        entity_types_hash = std.hash_map.hashString(value._type_name);
                    } else {
                        entity_types_hash = entity_types_hash.? ^ std.hash_map.hashString(value._type_name);
                    }
                }

                if (entity_types_hash.? == requested_types_hash.?) {
                    self._valid_entities.append(self._allocator, Entity{ .id = entry.key_ptr.* }) catch @panic("Error appending entity to _valid_entities list");
                }
            }

            // Return null if there are no entities that have all the requested types
            var num_valid_entities = self._valid_entities.items.len;
            if (num_valid_entities == 0) {
                return null;
            }

            return QueryIter{
                ._allocator = self._allocator,
                ._num_entities = num_valid_entities,
                ._valid_entities = self._valid_entities,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self._associated_component_map.values()) |*value| {
                value.deinit(self._allocator);
            }
            self._associated_component_map.deinit(self._allocator);
        }
    };
}

pub const QueryIter = struct {
    const Self = @This();

    _allocator: Allocator,

    _num_entities: u64,
    _valid_entities: std.ArrayListUnmanaged(Entity),

    _current_idx: u64 = 0,

    pub fn next(self: *QueryIter) ?Entity {
        if (self._current_idx < self._num_entities) {
            var entity = self._valid_entities.items[self._current_idx];

            self._current_idx += 1;

            return entity;
        } else {
            return null;
        }
    }

    pub fn deinit(self: *Self) void {
        self._valid_entities.deinit(self._allocator);
    }
};
