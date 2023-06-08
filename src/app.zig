const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const storage = @import("storage.zig");
const Entity = storage.Entity;
const World = @import("world.zig").World;
const Context = @import("context.zig").Context;

pub const System = *const fn (ctx: *Context) anyerror!void;

pub const StageID = union(enum) {
    Named: NamedInfo,
    Idx: u64,

    const NamedInfo = struct {
        name: []const u8,
        order: u64,
    };

    pub fn getOrder(self: StageID) u64 {
        switch (self) {
            .Named => |info| return info.order,
            .Idx => |id| return id,
        }
    }
};

pub const Stage = struct {
    const Self = @This();

    _allocator: Allocator,

    _id: StageID,
    _systems: std.ArrayListUnmanaged(System) = .{},

    pub fn init(allocator: Allocator, id: StageID) Self {
        return Self{ ._allocator = allocator, ._id = id };
    }

    pub fn deinit(self: *Self) void {
        self._systems.deinit(self._allocator);
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self._systems.append(self._allocator, system);
    }

    fn cmpOrder(context: void, a: Self, b: Self) bool {
        _ = context;

        if (a._id.getOrder() < b._id.getOrder()) {
            return true;
        }

        return false;
    }

    fn sort(stages: []Self) []Self {
        std.sort.insertion(Self, stages, {}, cmpOrder);
        return stages;
    }
};

/// The main interface for the ECS.
pub const App = struct {
    const Self = @This();

    _allocator: Allocator,

    /// The world that contains all the storages/tables.
    _world: World,

    /// Mutex for the world.
    _world_mutex: std.Thread.Mutex,

    /// The systems to be run by the app/ECS.
    _systems: std.ArrayListUnmanaged(System) = .{},

    // TODO: Make stages a Set instead of an array: No 2 stages with the same id!! (Do same for systems?)
    //
    /// The stages to run systems in.
    _stages: std.ArrayListUnmanaged(Stage) = .{},

    /// Create a new ECS app.
    pub fn init(allocator: Allocator) !Self {
        return Self{
            ._allocator = allocator,
            ._world = World{ ._allocator = allocator },
            ._world_mutex = std.Thread.Mutex{},
        };
    }

    /// Deallocate all memory allocated by the App.
    pub fn deinit(self: *Self) void {
        // Free up the stages
        for (self._stages.items) |*stage| {
            stage.deinit();
        }
        self._stages.deinit(self._allocator);

        // Free up the systems list
        self._systems.deinit(self._allocator);

        // Free up the World
        self._world.deinit();
    }

    pub fn addSystem(self: *Self, system: System) !void {
        try self._systems.append(self._allocator, system);
    }

    pub fn addStage(self: *Self, id: StageID, systems: []System) !void {
        var stage = Stage.init(self._allocator, id);
        for (systems) |system| {
            try stage.addSystem(system);
        }
        try self._stages.append(self._allocator, stage);
    }

    fn runSystem(ctx: *Context, system: System) !void {
        try system(ctx);
    }

    fn runStages(self: *Self) !void {
        var num_stages = self._stages.items.len;

        // Spawn threads for each system in a stage: Stages run sequentially, systems run in parallel
        var ordered_stages = Stage.sort(self._stages.items);
        for (ordered_stages) |stage| {
            var stage_threads = try std.ArrayList(Thread).initCapacity(self._allocator, num_stages);
            defer stage_threads.deinit();

            for (stage._systems.items) |system| {
                var ctx = Context{ ._allocator = self._allocator, ._world = &self._world, ._world_mutex = &self._world_mutex };
                var thread = try Thread.spawn(.{}, runSystem, .{ &ctx, system });
                try stage_threads.append(thread);
            }

            // Wait for systems to finish before running next stage
            for (stage_threads.items) |thread| {
                thread.join();
            }
        }
    }

    pub fn run(self: *Self) !void {
        var num_systems = self._systems.items.len;

        var threads = try std.ArrayList(Thread).initCapacity(self._allocator, num_systems + 1);
        defer threads.deinit();

        // Spawn thread to run stages in
        try threads.append(try Thread.spawn(.{}, runStages, .{self}));

        // Spawn threads for each free-standing system
        for (self._systems.items) |system| {
            var ctx = Context{ ._allocator = self._allocator, ._world = &self._world, ._world_mutex = &self._world_mutex };
            var thread = try Thread.spawn(.{}, runSystem, .{ &ctx, system });
            try threads.append(thread);
        }

        for (threads.items) |thread| {
            thread.join();
        }
    }
};
