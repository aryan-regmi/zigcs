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
    pub fn addComponent(self: *Self, ctx: *Context, component: anytype) !void {
        ctx.world_mutex.lock();
        try ctx.world.addComponentToEntity(self.*, component);
        ctx.world_mutex.unlock();
    }
};

/// A type-erased component.
pub const ErasedComponent = struct {
    const Self = @This();

    ptr: *anyopaque,

    deinit: *const fn (erased: *Self, allocator: Allocator) void,

    pub fn asConcrete(self: *Self, comptime ComponentType: type) *ComponentType {
        var aligned = @alignCast(@alignOf(*ComponentType), self.ptr);
        return @ptrCast(*ComponentType, aligned);
    }
};

pub const NullableErasedComponent = union(enum) {
    Some: ErasedComponent,
    None: void,
};
