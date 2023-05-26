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

pub const System = *const fn (ctx: *Context) anyerror!void;

pub const StageID = union(enum) {
    const NamedInfo = struct {
        name: []const u8,
        order: u64,
    };

    Named: NamedInfo,
    Idx: u64,
};

pub const Stage = struct {
    const Self = @This();

    allocator: Allocator,

    id: StageID,
    systems: std.ArrayListUnmanaged(System) = .{},

    pub fn init(allocator: Allocator, id: StageID) Self {
        return Self{ .allocator = allocator, .id = id };
    }

    pub fn deinit(self: *Self) void {
        self.systems.deinit(self.allocator);
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self.systems.append(self.allocator, system);
    }
};

pub const App = struct {
    const Self = @This();

    allocator: Allocator,

    /// The world that contains all the storages/tables.
    world: World,

    /// Mutex for the world.
    world_mutex: std.Thread.Mutex,

    /// The systems to be run by the app/ECS.
    systems: std.ArrayListUnmanaged(System) = .{},

    // TODO: Make stages a Set instead of an array: No 2 stages with the same id!! (Do same for systems?)
    //
    /// The stages to run systems in.
    stages: std.ArrayListUnmanaged(Stage) = .{},

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
        // Free up the stages
        for (self.stages.items) |stage| {
            @constCast(&stage).deinit();
        }
        self.stages.deinit(self.allocator);

        // Free up the systems list
        self.systems.deinit(self.allocator);

        // Free up the World
        self.world.deinit();
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self.systems.append(self.allocator, system);
    }

    pub fn addStage(self: *Self, id: StageID, systems: []System) !void {
        var stage = Stage.init(self.allocator, id);
        for (systems) |system| {
            try stage.addSystem(system);
        }
        try self.stages.append(self.allocator, stage);
    }

    fn runSystem(system: System, ctx: *Context) !void {
        try system(ctx);
    }

    // TODO: Add scheduler to avoid locks if possible!
    pub fn run(self: *Self) !void {
        if (self.stages.items.len != 0) {
            std.debug.print("\nStages:\n", .{});
        }

        // TODO: Run stages: all systems inside a stage run on separate threads, but all stages run sequentially
        for (self.stages.items) |stage| {
            for (stage.systems.items) |system| {
                _ = system;
                switch (stage.id) {
                    .Idx => |id| std.debug.print("\n{},\n\t# of Systems: {}", .{ id, stage.systems.items.len }),
                    .Named => |info| std.debug.print("\n{}: \"{s}\",\n\t# of Systems: {}", .{
                        info.order,
                        info.name,
                        stage.systems.items.len,
                    }),
                }
            }
        }

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
