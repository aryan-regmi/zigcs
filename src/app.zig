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

    pub fn getOrder(self: *StageID) u64 {
        switch (self) {
            .Named => |info| return info.order,
            .Idx => |id| return id,
        }
    }

    // TODO: Write in-place sort function!
    pub fn sort(stages: []Stage) !void {
        _ = stages;
    }
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

// NOTE: ECS was implemented using methods described here: https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/
//
/// The main interface for the ECS.
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

    /// Runs a specified system with the given context.
    fn runSystem(system: System, ctx: *Context) !void {
        try system(ctx);
    }

    /// Runs each system in its own thread and waits for all of the systems to finish.
    fn scheduleSystems(allocator: Allocator, world: *World, mutex: *Thread.Mutex, systems: []System) !void {
        var threads = try std.ArrayListUnmanaged(Thread).initCapacity(allocator, systems.len);
        defer threads.deinit(allocator);

        for (systems) |system| {
            var ctx = Context{
                .allocator = allocator,
                .world = world,
                .world_mutex = mutex,
            };
            try threads.append(
                allocator,
                try Thread.spawn(.{}, runSystem, .{ system, &ctx }),
            );
        }

        // Wait for threads
        for (threads.items) |thread| {
            thread.join();
        }
    }

    // TODO: Add scheduler (premptive-workstealing?) to avoid locks if possible!
    //
    /// Runs the stages and the systems in the App.
    /// NOTE: Currently (due to scheduleSystems) the stages will have to finish running before freestanding systems run.
    /// In the future, this should be changed so that the freestanding systems are completely independent of the stages.
    /// (Maybe have 2 separate threads that run scheduleSystems for systems and stages)
    pub fn run(self: *Self) !void {
        const ALLOC = self.allocator;
        const WORLD = &self.world;
        const MUTEX = &self.world_mutex;

        // Run freestanding systems
        try App.scheduleSystems(ALLOC, WORLD, MUTEX, self.systems.items);

        // Sort stages by their StageID.order
        var ordered = Stage.order(self.stages.items);

        // All systems inside a stage run on separate threads, but all stages run sequentially
        for (ordered) |stage| {
            try App.scheduleSystems(ALLOC, WORLD, MUTEX, stage.systems.items);
        }
    }
};
