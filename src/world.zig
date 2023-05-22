const Entity = @import("entity.zig").Entity;

pub const World = struct {
    const Self = @This();

    num_entities: usize = 0,

    pub fn spawnEntity(self: *Self) Entity {
        const entity = self.num_entities;
        self.num_entities += 1;
        return entity;
    }
};
