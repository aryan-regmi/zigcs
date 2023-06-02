const std = @import("std");
const storage = @import("storage.zig");
const Allocator = std.mem.Allocator;
const Entity = storage.Entity;
const ErasedComponentStorage = storage.ErasedComponentStorage;
const ComponentStorage = storage.ComponentStorage;

/// The hash for a storage with no components.
const EMPTY_COMPONENT_HASH: u64 = std.math.maxInt(u64);

pub const World = struct {
    const Self = @This();

    _allocator: Allocator,

    /// The number of entities.
    _num_entites: u64 = 0,

    // TODO: Add archetypes instead of directly storing components?
    //
    /// Map of component types and storages.
    _component_storages: std.StringArrayHashMapUnmanaged(ErasedComponentStorage) = .{},

    /// Keeps track of the component types associated w/ an entity. (Alternative to a bitmap)
    /// Stores array of hashes where indices represent an entity and the hash represents the associated component types.
    _entity_map: std.ArrayListUnmanaged(u64) = .{},

    /// Spawns a new entity in the ECS.
    pub fn spawnEntity(self: *Self) !Entity {
        // Add entry to the entity map.
        try self._entity_map.append(self._allocator, EMPTY_COMPONENT_HASH);

        // Create and return new entity
        var entity = Entity{ .id = self._num_entites };
        self._num_entites += 1;
        return entity;
    }

    fn initErasedStorage(self: *Self, comptime ComponentType: type, component: ComponentType, entity: Entity) !void {
        const component_hash = std.hash_map.hashString(@typeName(ComponentType));

        var new_storage: std.ArrayListUnmanaged(ComponentType) = .{};
        try new_storage.append(self._allocator, component);

        // Add new storage to the component map
        var new_ptr = try self._allocator.create(ComponentStorage(ComponentType));
        new_ptr.* = ComponentStorage(ComponentType){ ._storage = new_storage };
        var erased_storage = ErasedComponentStorage{
            ._hash = component_hash,
            ._ptr = new_ptr,
            ._deinit = (struct {
                pub fn _deinit(erased: *ErasedComponentStorage, allocator: Allocator) void {
                    // Delete entites map
                    erased._entities.deinit(allocator);

                    // Convert to concrete pointer and delete
                    var concrete = erased.asComponentStorage(ComponentType);
                    concrete.deinit(allocator);
                    allocator.destroy(concrete);
                }
            })._deinit,
        };
        try erased_storage._entities.append(self._allocator, entity.id); // Add entity id to ErasedComponentStorage's entities list
        try self._component_storages.put(self._allocator, @typeName(ComponentType), erased_storage);
    }

    /// Adds a component to the specified Entity.
    pub fn addComponentToEntity(self: *Self, entity: Entity, comptime component: anytype) !void {
        const COMPONENT_TYPE = @TypeOf(component);
        const TYPE_NAME = @typeName(COMPONENT_TYPE);

        // Calculate the hash for the component
        const component_hash = std.hash_map.hashString(TYPE_NAME);
        var old_hash = self._entity_map.items[entity.id];

        // Add component hash to entity map
        if (old_hash == EMPTY_COMPONENT_HASH) {
            self._entity_map.items[entity.id] = component_hash;
        } else {
            self._entity_map.items[entity.id] = old_hash ^ component_hash;
        }

        // Add component to storage if storage already exists
        if (self._component_storages.contains(TYPE_NAME)) {
            var erased_component_storage: *ErasedComponentStorage = self._component_storages.getPtr(TYPE_NAME).?;

            // Add entity id to ErasedComponentStorage's entities list
            try erased_component_storage._entities.append(self._allocator, entity.id);

            var component_storage = erased_component_storage.asComponentStorage(COMPONENT_TYPE);
            try component_storage._storage.append(self._allocator, component);
            return;
        }

        //  TODO: Create new storage if one doesn't exist and add the component to it
        try self.initErasedStorage(COMPONENT_TYPE, component, entity);
    }

    /// Returns the ArrayList of ComponentType if it exists in the world.
    pub fn getComponentStorage(self: *Self, type_name: []const u8) ?*ErasedComponentStorage {
        return self._component_storages.getPtr(type_name) orelse null;
    }

    pub fn deinit(self: *Self) void {
        // Free entity map
        self._entity_map.deinit(self._allocator);

        // Free component storages
        for (self._component_storages.values()) |erased_storage| {
            erased_storage._deinit(@constCast(&erased_storage), self._allocator);
        }
        self._component_storages.deinit(self._allocator);
    }
};
