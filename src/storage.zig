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
    pub fn addComponent(self: *Self, ctx: *Context, component: anytype) !void {
        ctx._world_mutex.lock();
        try ctx._world.addComponentToEntity(self.*, component);
        ctx._world_mutex.unlock();
    }
};

/// A type-erased component.
pub const ErasedComponent = struct {
    const Self = @This();

    _ptr: *anyopaque,

    _deinit: *const fn (erased: *Self, allocator: Allocator) void,

    pub fn asConcrete(self: *Self, comptime ComponentType: type) *ComponentType {
        var aligned = @alignCast(@alignOf(*ComponentType), self._ptr);
        return @ptrCast(*ComponentType, aligned);
    }
};

pub const NullableErasedComponent = union(enum) {
    None,
    Some: ErasedComponent,
};
