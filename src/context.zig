const std = @import("std");
const storage = @import("storage.zig");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const World = @import("world.zig").World;
const Entity = storage.Entity;
const ErasedComponent = storage.ErasedComponent;

pub const Context = struct {
    const Self = @This();

    allocator: Allocator,

    world: *World,
    world_mutex: *Mutex,

    pub fn spawn(self: *Self) !Entity {
        self.world_mutex.lock();
        var entity = self.world.spawnEntity();
        self.world_mutex.unlock();

        return entity;
    }

    pub fn buildQuery(self: *Self) QueryBuilder {
        return QueryBuilder{ .allocator = self.allocator };
    }
};

pub const QueryBuilder = struct {
    allocator: Allocator,

    query_types: std.ArrayListUnmanaged([]const u8) = .{},

    pub fn with(self: *QueryBuilder, comptime ComponentType: type) !void {
        try self.query_types.append(self.allocator, @typeName(ComponentType));
    }

    // TODO: Add actual logic to grab components that fit the queried types!
    pub fn build(self: *QueryBuilder) !Query {
        self.query_types.deinit(self.allocator);

        return Query{};
    }
};

pub const Query = struct {};
