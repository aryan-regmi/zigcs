const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Entity = u64;

/// The hash for an empty table (with no components/archetypes).
pub const VOID_ARCHETYPE_HASH = std.math.maxInt(u64);

pub const ArchetypeStorage = struct {
    const Self = @This();

    allocator: Allocator,

    /// A string hashmap of component name
    components: std.StringArrayHashMapUnmanaged(ErasedComponentStorage),

    /// The hash of all component types in this archetype
    hash: u64,

    /// A map of rows in the table to the entity.
    entities: std.ArrayListUnmanaged(Entity) = .{},

    pub fn calculateHash(self: *Self) void {
        self.hash = 0;
        var iter = self.components.iterator();
        while (iter.next()) |entry| {
            const component_name = entry.key_ptr.*;
            self.hash ^= std.hash_map.hashString(component_name);
        }
    }

    pub fn deinit(self: *Self) void {
        for (self.components.values()) |erased| {
            erased.deinit(erased.ptr, self.allocator);
        }
        self.entities.deinit(self.allocator);
        self.components.deinit(self.allocator);
    }

    /// Returns a new row index (adds an entity to the current table).
    pub fn new(self: *Self, entity: Entity) !u32 {
        const new_row_idx = self.entities.items.len;
        try self.entities.append(self.allocator, entity);
        return @intCast(u32, new_row_idx);
    }

    /// Cancels the `new` operation if an error occured.
    pub fn undoNew(self: *Self) void {
        _ = self.entities.pop();
    }

    /// Removes an entire row from the table.
    pub fn remove(self: *Self, row_idx: u32) !void {
        _ = self.entities.swapRemove(row_idx);
        for (self.components.values()) |component_storage| {
            component_storage.remove(component_storage.ptr, row_idx);
        }
    }

    pub fn set(self: *Self, row_idx: u32, name: []const u8, component: anytype) !void {
        var component_storage_erased = self.components.get(name).?;
        var component_storage = ErasedComponentStorage.asComponentStorage(component_storage_erased.ptr, @TypeOf(component));
        try component_storage.set(self.allocator, row_idx, component);
    }
};

/// Represents the storage for a single type of component.
pub fn ComponentStorage(comptime Component: type) type {
    return struct {
        const Self = @This();

        /// The total number of entites with the same type
        num_entities: usize,

        /// The stored component data.
        data: std.ArrayListUnmanaged(Component) = .{},

        /// Set the component at the specified row.
        pub fn set(self: *Self, allocator: Allocator, row_idx: u32, component: Component) !void {
            if (self.data.items.len <= row_idx) try self.data.appendNTimes(allocator, undefined, self.data.items.len + 1 - row_idx);
            self.data.items[row_idx] = component;
        }

        /// Remove a value from a column of this table.
        pub fn remove(self: *Self, row_idx: u32) void {
            if (self.data.items.len > row_idx) {
                _ = self.data.swapRemove(row_idx);
            }
        }

        /// Copies a row's value from src to dst.
        pub inline fn copy(dst: *Self, allocator: Allocator, src_row: u32, dst_row: u32, src: *Self) !void {
            try dst.set(allocator, dst_row, src.get(src_row));
        }

        /// Gets a component value from a column.
        pub inline fn get(self: Self, row_idx: u32) Component {
            return self.data.items[row_idx];
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.data.deinit(allocator);
        }
    };
}

/// Type-erased version of ComponentStorage(T).
pub const ErasedComponentStorage = struct {
    const Self = @This();

    /// Type-erased pointer to ComponentStorage.
    ptr: *anyopaque,

    /// Frees up all memory used by the storage.
    deinit: *const fn (erased: *anyopaque, allocator: Allocator) void,

    /// Clones ComponentStorage type.
    ///
    /// Creates a new value of type ComponentStorage(T), where T is not known.
    /// Only clones the type; it doesn't copy the actual values in the storage.
    cloneType: *const fn (erased: Self, total_entites: usize, allocator: Allocator, retval: *Self) anyerror!void,

    /// Copies a component value from one ComponentStorage(T) to another, where T is not known.
    copy: *const fn (dst_erased: *anyopaque, allocator: Allocator, src_row: u32, dst_row: u32, src_erased: *anyopaque) anyerror!void,

    /// Removes a single component value from a component storage/table.
    remove: *const fn (erased: *anyopaque, row: u32) void,

    /// Casts `self` to `*ComponentStorage(Component)`.
    pub fn asComponentStorage(ptr: *anyopaque, comptime Component: type) *ComponentStorage(Component) {
        var aligned = @alignCast(@alignOf(*ComponentStorage(Component)), ptr);
        return @ptrCast(*ComponentStorage(Component), aligned);
    }
};
