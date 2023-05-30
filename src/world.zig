const std = @import("std");
const storage = @import("storage.zig");
const StringArrayHashMapUnmanaged = std.StringArrayHashMapUnmanaged;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;
const NullableErasedComponent = storage.NullableErasedComponent;

pub const World = struct {
    const Self = @This();

    allocator: Allocator,

    /// The number of entities.
    num_entities: u64 = 0,

    // TODO: Add archetypes instead of directly storing components?
    //
    /// Map of component types and storages.
    component_storages: StringArrayHashMapUnmanaged(ArrayListUnmanaged(NullableErasedComponent)) = .{},

    pub fn spawnEntity(self: *Self) !Entity {
        // Add empty entry for all component storages
        for (self.component_storages.keys()) |key| {
            var component_storage = self.component_storages.get(key).?;
            try component_storage.append(self.allocator, NullableErasedComponent.None);
            try self.component_storages.put(self.allocator, key, component_storage);
        }

        var entity = Entity{ .id = self.num_entities };
        self.num_entities += 1;
        return entity;
    }

    pub fn addComponentToEntity(self: *Self, entity: Entity, component: anytype) !void {
        var type_name = @typeName(@TypeOf(component));

        // Create ErasedComponent from the component
        var new_ptr = try self.allocator.create(@TypeOf(component));
        new_ptr.* = component;
        var erased = ErasedComponent{
            .ptr = new_ptr,
            .deinit = (struct {
                pub fn deinit(erased: *ErasedComponent, allocator: Allocator) void {
                    var ptr = erased.asConcrete(@TypeOf(component));
                    allocator.destroy(ptr);
                }
            }).deinit,
        };

        // If component storage exists, just add the component to it
        if (self.component_storages.contains(type_name)) {
            var component_storage = self.component_storages.get(type_name).?;
            component_storage.items[entity.id] = NullableErasedComponent{ .Some = erased };
            return;
        }

        // Otherwise, create a new component storage and add the component to it
        var new_storage = try ArrayListUnmanaged(NullableErasedComponent).initCapacity(self.allocator, self.num_entities);
        for (0..self.num_entities) |i| {
            if (i == entity.id) {
                try new_storage.append(self.allocator, NullableErasedComponent{ .Some = erased });
            } else {
                try new_storage.append(self.allocator, NullableErasedComponent.None);
            }
        }

        // Add new component storage to the world
        try self.component_storages.put(self.allocator, type_name, new_storage);
    }

    pub fn deinit(self: *Self) void {
        for (self.component_storages.values()) |component_storage| {
            // Free all ErasedComponents
            for (component_storage.items) |entry| {
                switch (entry) {
                    .None => {},
                    .Some => |val| {
                        val.deinit(@constCast(&val), self.allocator);
                    },
                }
            }

            // Free list stored in map
            (@constCast(&component_storage)).deinit(self.allocator);
        }

        // Free map
        self.component_storages.deinit(self.allocator);
    }
};
