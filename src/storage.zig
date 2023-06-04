const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Context = @import("context.zig").Context;

pub const Entity = struct {
    const Self = @This();

    id: u64,

    // TODO: Add comptime checks to make sure components are structs?
    //
    /// Add the specified component to this Entity.
    pub fn addComponent(self: *Self, ctx: *Context, comptime component: anytype) !void {
        ctx._world_mutex.lock();
        try ctx._world.addComponentToEntity(self.*, component);
        ctx._world_mutex.unlock();
    }
};

pub fn ComponentStorage(comptime ComponentType: type) type {
    return struct {
        const Self = @This();

        _storage: std.ArrayListUnmanaged(?ComponentType),

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self._storage.deinit(allocator);
        }

        /// Kepps track of all entities associated with a type of component.
        pub const EntityMap = struct {
            idxs: std.ArrayListUnmanaged(u64),
            components: std.ArrayListUnmanaged(*ComponentType),
        };

        /// Get all non-null component values in the storage.
        pub fn getNonEmptyComponents(self: *Self, allocator: Allocator) ?EntityMap {
            var components: std.ArrayListUnmanaged(*ComponentType) = .{};
            var idxs: std.ArrayListUnmanaged(u64) = .{};
            var num_added: u64 = 0;
            for (self._storage.items, 0..) |*component, i| {
                if (component.* != null) {
                    num_added += 1;
                    idxs.append(allocator, i) catch @panic("Failure during appending index");
                    components.append(allocator, &component.*.?) catch @panic("Failure during appending component");
                }
            }

            if (num_added == 0) {
                return null;
            }

            return EntityMap{
                .idxs = idxs,
                .components = components,
            };
        }
    };
}

pub const ErasedComponentStorage = struct {
    const Self = @This();

    /// A pointer to the underlying ComponentStorage.
    _ptr: *anyopaque,

    /// Pointer to function that frees up all resources.
    _deinit: *const fn (erased: *Self, allocator: Allocator) void,

    /// Casts the type-erased storage to a typed storage (ComponentStorage).
    pub fn asComponentStorage(self: *Self, comptime ComponentType: type) *ComponentStorage(ComponentType) {
        var aligned = @alignCast(@alignOf(*ComponentStorage(ComponentType)), self._ptr);
        return @ptrCast(*ComponentStorage(ComponentType), aligned);
    }
};
