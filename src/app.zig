const std = @import("std");
const Allocator = std.mem.Allocator;
const storage = @import("storage.zig");
const Entity = storage.Entity;
const ArchetypeStorage = storage.ArchetypeStorage;
const ComponentStorage = storage.ComponentStorage;
const ErasedComponentStorage = storage.ErasedComponentStorage;
const VOID_ARCHETYPE_HASH = storage.VOID_ARCHETYPE_HASH;

pub const App = struct {
    const Self = @This();

    allocator: Allocator,

    /// Map of archetype hash to their storage.
    ///
    /// A table representing entities.
    archetypes: std.AutoArrayHashMapUnmanaged(u64, ArchetypeStorage) = .{},

    /// The number of entities.
    num_entities: Entity = 0,

    /// Map of entities to the location the entity is stored in.
    entities: std.AutoHashMapUnmanaged(Entity, Pointer) = .{},

    /// Points to an entity, specifying the archetype table and row in that table.
    pub const Pointer = struct {
        archtype_idx: u16,
        row_idx: u32,
    };

    /// Create a new ECS app.
    pub fn init(allocator: Allocator) !Self {
        var new_app = Self{ .allocator = allocator };

        // Crate new void (with no components) archetypes table
        try new_app.archetypes.put(
            allocator,
            VOID_ARCHETYPE_HASH,
            ArchetypeStorage{
                .allocator = allocator,
                .components = .{},
                .hash = VOID_ARCHETYPE_HASH,
            },
        );

        return new_app;
    }

    /// Deallocate all memory allocated by the App.
    pub fn deinit(self: *Self) void {
        // Free up the entity map.
        self.entities.deinit(self.allocator);

        // Free up all values in the hashmap & the hashmap itself
        var iter = self.archetypes.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.archetypes.deinit(self.allocator);
    }

    /// Creates a type-erased storage/table of Component values.
    pub fn initErasedStorage(self: *const Self, total_rows: usize, comptime Component: type) !ErasedComponentStorage {
        // Create a ComponentStorage to hold Components
        var new_ptr = try self.allocator.create(ComponentStorage(Component));
        new_ptr.* = ComponentStorage(Component){ .num_entities = total_rows };

        // Return an ErasedComponentStorage from the created ComponentStorage
        return ErasedComponentStorage{
            .ptr = new_ptr,
            .deinit = (struct {
                pub fn deinit(erased: *anyopaque, allocator: Allocator) void {
                    var ptr = ErasedComponentStorage.asComponentStorage(erased, Component);
                    ptr.deinit(allocator);
                    allocator.destroy(ptr);
                }
            }).deinit,
            .cloneType = (struct {
                pub fn cloneType(erased: ErasedComponentStorage, total_rows_: usize, allocator: Allocator, retval: *ErasedComponentStorage) error{OutOfMemory}!void {
                    var new_clone = try allocator.create(ComponentStorage(Component));
                    new_clone.* = ComponentStorage(Component){ .num_entities = total_rows_ };
                    var tmp = erased;
                    tmp.ptr = new_clone;
                    retval.* = tmp;
                }
            }).cloneType,
            .copy = (struct {
                pub fn copy(dst_erased: *anyopaque, allocator: Allocator, src_row: u32, dst_row: u32, src_erased: *anyopaque) error{OutOfMemory}!void {
                    var dst = ErasedComponentStorage.asComponentStorage(dst_erased, Component);
                    var src = ErasedComponentStorage.asComponentStorage(src_erased, Component);
                    return dst.copy(allocator, src_row, dst_row, src);
                }
            }).copy,
            .remove = (struct {
                pub fn remove(erased: *anyopaque, row: u32) void {
                    var ptr = ErasedComponentStorage.asComponentStorage(erased, Component);
                    ptr.remove(row);
                }
            }).remove,
        };
    }

    /// Spawns a new entity with no components.
    pub fn spawnEntity(self: *Self) !Entity {
        const new_entity = self.num_entities;
        self.num_entities += 1;

        // Add the new entity to the void_archetype table.
        var void_archetype = self.archetypes.getPtr(VOID_ARCHETYPE_HASH).?;
        const new_row = try void_archetype.new(new_entity);
        const void_pointer = Pointer{
            .archtype_idx = 0,
            .row_idx = new_row,
        };

        self.entities.put(self.allocator, new_entity, void_pointer) catch |e| {
            void_archetype.undoNew();
            return e;
        };

        return new_entity;
    }

    pub inline fn archetypeById(self: *Self, entity: Entity) *ArchetypeStorage {
        const ptr = self.entities.get(entity).?;
        return &self.archetypes.values()[ptr.archtype_idx];
    }

    /// Add a new component to the entity, or update the existing component.
    ///
    /// If adding a new component, the entity gets moved to a new archetype table.
    pub fn withComponent(self: *Self, entity: Entity, component: anytype) !void {
        var archetype = self.archetypeById(entity);

        // Check if a new archetype needs to be created.
        const old_hash = archetype.hash;
        const type_name = @typeName(@TypeOf(component));
        var componentTypeExists = archetype.components.contains(type_name);
        const new_hash = if (componentTypeExists) old_hash else old_hash ^ std.hash_map.hashString(type_name);

        // Get the archetype storage for this entity, or create a new one
        var archetype_entry = try self.archetypes.getOrPut(self.allocator, new_hash);
        if (!archetype_entry.found_existing) {
            archetype_entry.value_ptr.* = ArchetypeStorage{
                .allocator = self.allocator,
                .components = .{},
                .hash = 0,
            };

            var new_archetype = archetype_entry.value_ptr;

            // Create storage columns for the existing components on the entity
            var column_iter = archetype.components.iterator();
            while (column_iter.next()) |entry| {
                var erased: ErasedComponentStorage = undefined;
                entry.value_ptr.cloneType(entry.value_ptr.*, new_archetype.entities.items.len, self.allocator, &erased) catch |e| {
                    std.debug.assert(self.archetypes.swapRemove(new_hash));
                    return e;
                };
                new_archetype.components.put(self.allocator, entry.key_ptr.*, erased) catch |e| {
                    std.debug.assert(self.archetypes.swapRemove(new_hash));
                    return e;
                };
            }

            // Create column for the new component.
            const erased = self.initErasedStorage(new_archetype.entities.items.len, @TypeOf(component)) catch |e| {
                std.debug.assert(self.archetypes.swapRemove(new_hash));
                return e;
            };
            new_archetype.components.put(self.allocator, type_name, erased) catch |e| {
                std.debug.assert(self.archetypes.swapRemove(new_hash));
                return e;
            };
            new_archetype.calculateHash();
        }

        // Update the table by putting component value into it
        var current_archetype_storage = archetype_entry.value_ptr;
        if (new_hash == old_hash) {
            // Update the value of the existing component of the entity.
            const ptr = self.entities.get(entity).?;
            try current_archetype_storage.set(ptr.row_idx, type_name, component);
            return;
        }

        // Move entity to new table if necessary
        const new_row = try current_archetype_storage.new(entity);
        const old_ptr = self.entities.get(entity).?;
        var column_iter = archetype.components.iterator();
        while (column_iter.next()) |entry| {
            var old_component_storage = entry.value_ptr;
            var new_component_storage = current_archetype_storage.components.get(entry.key_ptr.*).?;
            new_component_storage.copy(new_component_storage.ptr, self.allocator, new_row, old_ptr.row_idx, old_component_storage.ptr) catch |e| {
                current_archetype_storage.undoNew();
                return e;
            };
        }

        // Update the new storage by putting compnent into it
        current_archetype_storage.entities.items[new_row] = entity;

        // Add new component to storage
        current_archetype_storage.set(new_row, type_name, component) catch |e| {
            current_archetype_storage.undoNew();
            return e;
        };

        // Remove old table row
        var swapped_entity = archetype.entities.items[archetype.entities.items.len - 1];
        archetype.remove(old_ptr.row_idx) catch |e| {
            current_archetype_storage.undoNew();
            return e;
        };
        try self.entities.put(self.allocator, swapped_entity, old_ptr);

        // Update the app's entity map
        try self.entities.put(self.allocator, entity, Pointer{
            .archtype_idx = @intCast(u16, archetype_entry.index),
            .row_idx = new_row,
        });
        return;
    }

    // TODO: Add queries
    // TODO: Add getting component logic
    // TODO: Add removing component logic
};
