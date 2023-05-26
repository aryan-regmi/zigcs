const std = @import("std");
const testing = std.testing;
const context = @import("context.zig");

const app = @import("app.zig");
pub const App = app.App;
pub const Stage = app.Stage;
pub const StageID = app.StageID;
pub const System = app.System;
pub const Context = context.Context;
pub const EntityBuilder = context.EntityBuilder;

// NOTE: ECS was implemented using methods described here: https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/

// TODO: Move these (integration) tests to the tests/ directory, and import the lib as a module
