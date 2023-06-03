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

    // TODO: Add archetypes
    //
    /// Map of component types and storages.
    _component_storages: std.StringArrayHashMapUnmanaged(ErasedComponentStorage) = .{},

    /// Keeps track of the component types associated w/ an entity. (Alternative to a bitmap)
    /// A map of entity ids to a list of StorageInfo.
    _entity_map: std.AutoArrayHashMapUnmanaged(u64, std.ArrayListUnmanaged(StorageInfo)) = .{},

    const StorageInfo = struct {
        type_name: []const u8,
        index: u64,
    };

    /// Spawns a new entity in the ECS.
    pub fn spawnEntity(self: *Self) !Entity {
        // Create new entity
        var entity = Entity{ .id = self._num_entites };
        self._num_entites += 1;

        // Add entry to the entity map.
        try self._entity_map.put(self._allocator, entity.id, .{});

        return entity;
    }

    fn initErasedStorage(self: *Self, comptime ComponentType: type, component: ComponentType, entity: Entity) !void {
        var new_storage: std.ArrayListUnmanaged(ComponentType) = .{};
        try new_storage.append(self._allocator, component);

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

        // Add storage info to entity map!
        var entity_map_entry: *std.ArrayListUnmanaged(StorageInfo) = self._entity_map.getPtr(entity.id).?;
        try entity_map_entry.append(self._allocator, StorageInfo{
            .type_name = @typeName(ComponentType),
            .index = 0, // If a new storage is being created, then the passed entity will be at the first index of the storage
        });

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
            try component_storage._storage.append(self._allocator, component);

            // Add storage info to entity map!
            var entity_map_entry: *std.ArrayListUnmanaged(StorageInfo) = self._entity_map.getPtr(entity.id).?;
            try entity_map_entry.append(self._allocator, StorageInfo{
                .type_name = TYPE_NAME,
                .index = component_storage._storage.items.len,
            });

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
        for (self._entity_map.values()) |entry| {
            @constCast(&entry).deinit(self._allocator);
        }
        self._entity_map.deinit(self._allocator);

        // Free component storages
        for (self._component_storages.values()) |erased_storage| {
            erased_storage._deinit(@constCast(&erased_storage), self._allocator);
        }
        self._component_storages.deinit(self._allocator);
    }
};
