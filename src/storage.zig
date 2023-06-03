const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Context = @import("context.zig").Context;

// TODO: Store type-erased storage instead of erasing (and allocating) each individual component

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

        _storage: std.ArrayListUnmanaged(ComponentType),

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self._storage.deinit(allocator);
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
