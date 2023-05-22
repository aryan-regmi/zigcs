const Context = @import("context.zig").Context;

pub const Entity = usize;

pub const EntityBuilder = struct {
    const Self = @This();

    ctx: Context,

    pub fn init(ctx: Context) Self {
        return Self{ .ctx = ctx };
    }

    // TODO: Implement
    pub fn with(self: Self, component: anytype) Self {
        _ = component;
        return self;
    }

    // TODO: Implement
    pub fn build(self: Self) Entity {
        self.ctx.world_mutex.lock();
        var entity = self.ctx.world.*.spawnEntity();
        self.ctx.world_mutex.unlock();

        return entity;
    }
};
