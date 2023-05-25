const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const storage = @import("storage.zig");
const Entity = storage.Entity;
const ArchetypeStorage = storage.ArchetypeStorage;
const ComponentStorage = storage.ComponentStorage;
const ErasedComponentStorage = storage.ErasedComponentStorage;
const VOID_ARCHETYPE_HASH = storage.VOID_ARCHETYPE_HASH;
const World = @import("world.zig").World;
const Context = @import("context.zig").Context;

// TODO: Add queries
// TODO: Add comptime checks to make sure components are structs?
// TODO: Add getting component logic
// TODO: Add removing component logic
// TODO: Add stages for systems

const System = *const fn (ctx: *Context) anyerror!void;

pub const App = struct {
    const Self = @This();

    allocator: Allocator,

    /// The world that contains all the storages/tables.
    world: World,

    /// Mutex for the world.
    world_mutex: std.Thread.Mutex,

    /// The systems to be run by the app/ECS.
    systems: std.ArrayListUnmanaged(System) = .{},

    /// Create a new ECS app.
    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .world = try World.init(allocator),
            .world_mutex = std.Thread.Mutex{},
        };
    }

    /// Deallocate all memory allocated by the App.
    pub fn deinit(self: *Self) void {
        // Free up the systems list
        self.systems.deinit(self.allocator);

        // Free up the World
        self.world.deinit();
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self.systems.append(self.allocator, system);
    }

    fn runSystem(system: System, ctx: *Context) !void {
        try system(ctx);
    }

    // TODO: Add scheduler to avoid locks if possible!
    pub fn run(self: *Self) !void {
        var threads = try std.ArrayListUnmanaged(Thread).initCapacity(self.allocator, self.systems.items.len);

        for (self.systems.items) |system| {
            var ctx = Context{
                .allocator = self.allocator,
                .world = &self.world,
                .world_mutex = &self.world_mutex,
            };
            try threads.append(
                self.allocator,
                try Thread.spawn(.{}, runSystem, .{ system, &ctx }),
            );
        }

        // Wait for threads
        for (threads.items) |thread| {
            thread.join();
        }

        threads.deinit(self.allocator);
    }
};
