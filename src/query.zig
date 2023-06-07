const std = @import("std");
const storage = @import("storage.zig");
const Entity = storage.Entity;
const Allocator = std.mem.Allocator;
const ErasedComponent = storage.ErasedComponent;

/// Represents mutable components in queries.
pub fn Mut(comptime T: type) type {
    return struct {
        pub const TYPE = T;
        pub const TYPE_NAME = @typeName(T);

        _val: T,

        _zigcs_mutable_query_type: bool = true,
    };
}

/// Represents immutable components in queries.
pub fn Ref(comptime T: type) type {
    return struct {
        pub const TYPE = T;
        pub const TYPE_NAME = @typeName(T);

        _val: T,

        _zigcs_mutable_query_type: bool = false,
    };
}

pub fn QueryRes(comptime T: type) type {
    return union(enum) {
        Ref: Ref(T),
        Mut: Mut(T),

        // FIXME: REMOVE THIS
        TODO,
    };
}

pub const QueryIter = struct {
    pub fn next(self: *QueryIter) ?Entity {
        _ = self;
        return null;
    }
};

pub fn Query(comptime QueryTypes: anytype) type {
    // TODO: Use QueryTypes to check that type requested from getComponent is allowed in this query
    _ = QueryTypes;
    return struct {
        const Self = @This();

        _allocator: Allocator,

        _associated_component_map: std.AutoArrayHashMapUnmanaged(u64, std.ArrayListUnmanaged(ErasedComponent)),

        // FIXME: Implement this!
        pub fn getComponent(self: *Self, entity: Entity, comptime T: type) QueryRes(T) {
            _ = entity;
            _ = self;

            return QueryRes(T){ .TODO = {} };
        }

        // FIXME: Make Query an iterator!
        pub fn iterator(self: *Self) QueryIter {
            // NOTE: DEBUG
            var iter = self._associated_component_map.iterator();
            _ = iter;
            // while (iter.next()) |entry| {
            //     // std.debug.print("\t{}\n", .{entry.key_ptr.*});
            //     // for (entry.value_ptr.items) |value| {
            //     //     std.debug.print("\t\tType: {s}\n\t\tValue: {}\n", .{
            //     //         value._type_name,
            //     //         value._ptr,
            //     //     });
            //     // }
            // }

            return QueryIter{};
        }

        pub fn deinit(self: *Self) void {
            for (self._associated_component_map.values()) |*value| {
                value.deinit(self._allocator);
            }
            self._associated_component_map.deinit(self._allocator);
        }
    };
}
