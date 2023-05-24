const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const App = struct {
    const Self = @This();

    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }
};
