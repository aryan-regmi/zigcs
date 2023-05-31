const std = @import("std");
const storage = @import("storage.zig");
const StringArrayHashMapUnmanaged = std.StringArrayHashMapUnmanaged;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;
const NullableErasedComponent = storage.NullableErasedComponent;

// TODO: Add entity map to keep track of the component types of an entity (hash the component type and store that instead of type_name?).
pub const World = struct {
    const Self = @This();

    _allocator: Allocator,

    /// The number of entities.
    _num_entites: u64 = 0,

    // TODO: Add archetypes instead of directly storing components?
    //
    /// Map of component types and storages.
    _component_storages: StringArrayHashMapUnmanaged(ArrayListUnmanaged(NullableErasedComponent)) = .{},

    /// Spawns a new entity in the ECS.
    pub fn spawnEntity(self: *Self) !Entity {
        // Add empty entry for all component storages
        for (self._component_storages.keys()) |key| {
            var component_storage = self._component_storages.get(key).?;
            try component_storage.append(self._allocator, NullableErasedComponent.None);
            try self._component_storages.put(self._allocator, key, component_storage);
        }

        var entity = Entity{ .id = self._num_entites };
        self._num_entites += 1;
        return entity;
    }

    /// Adds a component to the specified Entity.
    pub fn addComponentToEntity(self: *Self, entity: Entity, component: anytype) !void {
        var type_name = @typeName(@TypeOf(component));

        // Create ErasedComponent from the component
        var new_ptr = try self._allocator.create(@TypeOf(component));
        new_ptr.* = component;
        var erased = ErasedComponent{
            ._ptr = new_ptr,
            ._deinit = (struct {
                pub fn deinit(erased: *ErasedComponent, allocator: Allocator) void {
                    var ptr = erased.asConcrete(@TypeOf(component));
                    allocator.destroy(ptr);
                }
            }).deinit,
        };

        // If component storage exists, just add the component to it
        if (self._component_storages.contains(type_name)) {
            var component_storage = self._component_storages.get(type_name).?;
            component_storage.items[entity.id] = NullableErasedComponent{ .Some = erased };
            return;
        }

        // Otherwise, create a new component storage and add the component to it
        var new_storage = try ArrayListUnmanaged(NullableErasedComponent).initCapacity(self._allocator, self._num_entites);
        for (0..self._num_entites) |i| {
            if (i == entity.id) {
                try new_storage.append(self._allocator, NullableErasedComponent{ .Some = erased });
            } else {
                try new_storage.append(self._allocator, NullableErasedComponent.None);
            }
        }

        // Add new component storage to the world
        try self._component_storages.put(self._allocator, type_name, new_storage);
    }

    /// Returns the ArrayList of ComponentType if it exists in the world.
    pub fn getComponentStorage(self: *Self, type_name: []const u8) ?ArrayListUnmanaged(NullableErasedComponent) {
        return self._component_storages.get(type_name) orelse null;
    }

    pub fn deinit(self: *Self) void {
        for (self._component_storages.values()) |component_storage| {
            // Free all ErasedComponents
            for (component_storage.items) |entry| {
                switch (entry) {
                    .None => {},
                    .Some => |val| {
                        val._deinit(@constCast(&val), self._allocator);
                    },
                }
            }

            // Free list stored in map
            (@constCast(&component_storage)).deinit(self._allocator);
        }

        // Free map
        self._component_storages.deinit(self._allocator);
    }
};
