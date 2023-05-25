const std = @import("std");
const testing = std.testing;
const context = @import("context.zig");

pub const App = @import("app.zig").App;
pub const Context = context.Context;
pub const EntityBuilder = context.EntityBuilder;

// NOTE: ECS was implemented using methods described here: https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/

// TODO: Move these (integration) tests to the tests/ directory, and import the lib as a module
