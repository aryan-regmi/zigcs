const std = @import("std");
const storage = @import("storage.zig");
const Allocator = std.mem.Allocator;
const Entity = storage.Entity;
const ErasedComponentStorage = storage.ErasedComponentStorage;
const ComponentStorage = storage.ComponentStorage;

pub const World = struct {
    const Self = @This();

    _allocator: Allocator,

    /// The number of entities.
    _num_entities: u64 = 0,

    // TODO: Add archetypes
    //
    /// Map of component types and storages.
    _component_storages: std.StringArrayHashMapUnmanaged(ErasedComponentStorage) = .{},

    /// Keeps track of entity-component associations.
    _entity_map: std.StringArrayHashMapUnmanaged(std.ArrayListUnmanaged(u64)) = .{},

    /// Spawns a new entity in the ECS.
    pub fn spawnEntity(self: *Self) !Entity {
        // Create new entity
        var entity = Entity{ .id = self._num_entities };
        self._num_entities += 1;

        return entity;
    }

    // FIXME: Add logic to remove entity
    pub fn removeEntity(self: *Self) !void {
        _ = self;

        // TODO: Just mark entity to be deleted, and check the marked_for_deletion list before adding or removing components?

        // TODO: Remove entity from _entity_map?
        //  -> No good way to keep track of component types in the world, so maybe anything that uses the entity map will just check the deleted entites too
    }

    /// Create a new erased storage/list for a component of `ComponentType`.
    fn initErasedStorage(self: *Self, comptime ComponentType: type, component: ComponentType, entity: Entity) !void {
        var new_storage = try std.ArrayListUnmanaged(?ComponentType).initCapacity(self._allocator, self._num_entities);
        try new_storage.appendNTimes(self._allocator, null, self._num_entities);

        new_storage.items[entity.id] = component;

        // Add new storage to the component map
        var new_ptr = try self._allocator.create(ComponentStorage(ComponentType));
        new_ptr.* = ComponentStorage(ComponentType){ ._storage = new_storage };

        var erased_storage = ErasedComponentStorage{
            ._ptr = new_ptr,
            ._deinit = (struct {
                pub fn _deinit(erased: *ErasedComponentStorage, allocator: Allocator) void {
                    // Convert to concrete pointer and delete
                    var concrete = erased.asComponentStorage(ComponentType);
                    concrete.deinit(allocator);
                    allocator.destroy(concrete);
                }
            })._deinit,
        };

        try self._component_storages.put(self._allocator, @typeName(ComponentType), erased_storage);
    }

    /// Adds a component to the specified Entity.
    pub fn addComponentToEntity(self: *Self, entity: Entity, comptime component: anytype) !void {
        const COMPONENT_TYPE = @TypeOf(component);
        const TYPE_NAME = @typeName(COMPONENT_TYPE);

        // Add component to storage if storage already exists
        if (self._component_storages.contains(TYPE_NAME)) {
            var erased_component_storage: *ErasedComponentStorage = self._component_storages.getPtr(TYPE_NAME).?;
            var component_storage = erased_component_storage.asComponentStorage(COMPONENT_TYPE);
            // For each erased storage, add a new,empty entry
            var num_entries = component_storage._storage.items.len;
            if (self._num_entities > num_entries) {
                var num_new_entities = self._num_entities - num_entries;
                try component_storage._storage.appendNTimes(self._allocator, null, num_new_entities);
            }
            component_storage._storage.items[entity.id] = component;

            // Add entry to entity map if it's not already there
            if (!self.entityIsInComponentMap(entity, TYPE_NAME)) {
                var associated_entities = self._entity_map.getPtr(TYPE_NAME);

                if (associated_entities != null) {
                    try associated_entities.?.append(self._allocator, entity.id);
                } else {
                    var new_associated_list: std.ArrayListUnmanaged(u64) = .{};
                    try new_associated_list.append(self._allocator, entity.id);
                    try self._entity_map.put(self._allocator, TYPE_NAME, new_associated_list);
                }
            }

            return;
        }

        // Create new storage if one doesn't exist and add the component to it
        try self.initErasedStorage(COMPONENT_TYPE, component, entity);

        // DEBUG: Check all values stored in the storage!

        // Add entry to entity map if it's not already there
        if (!self.entityIsInComponentMap(entity, TYPE_NAME)) {
            var associated_entities = self._entity_map.getPtr(TYPE_NAME);

            if (associated_entities != null) {
                try associated_entities.?.append(self._allocator, entity.id);
            } else {
                var new_associated_list: std.ArrayListUnmanaged(u64) = .{};
                try new_associated_list.append(self._allocator, entity.id);
                try self._entity_map.put(self._allocator, TYPE_NAME, new_associated_list);
            }
        }
    }

    // FIXME: Add logic to remove component
    pub fn removeComponentFromEntity(self: *Self, comptime ComponentType: type, entity: Entity) !void {
        _ = entity;
        _ = ComponentType;
        _ = self;

        // TODO: If `entityIsInComponentMap` is false, return an error: ComponentNotInEntity

        // TODO: Else, convert erased storage to concrete list and set entity.id entry to null

        // TODO: Update entity map (remove the component from entity's associated list!)
    }

    /// Checks if an entity is already associated with the given type.
    fn entityIsInComponentMap(self: *Self, entity: Entity, type_name: []const u8) bool {
        var associated_entities = self._entity_map.get(type_name) orelse return false;
        for (associated_entities.items) |entity_| {
            if (entity_ == entity.id) {
                return true;
            }
        }

        return false;
    }

    /// Returns the ArrayList of ComponentType if it exists in the world.
    pub fn getComponentStorage(self: *Self, type_name: []const u8) ?*ErasedComponentStorage {
        return self._component_storages.getPtr(type_name) orelse null;
    }

    pub fn deinit(self: *Self) void {
        // Free entity map
        for (self._entity_map.values()) |*value| {
            value.deinit(self._allocator);
        }
        self._entity_map.deinit(self._allocator);

        // Free component storages
        for (self._component_storages.values()) |*erased_storage| {
            erased_storage._deinit(erased_storage, self._allocator);
        }
        self._component_storages.deinit(self._allocator);
    }
};
