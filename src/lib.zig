const std = @import("std");
const testing = std.testing;
const context = @import("context.zig");
const app = @import("app.zig");
const storage = @import("storage.zig").Entity;
const query = @import("query.zig");

pub const App = app.App;
pub const Stage = app.Stage;
pub const StageID = app.StageID;
pub const System = app.System;
pub const Entity = storage.Entity;
pub const Context = context.Context;
pub const Ref = query.Ref;
pub const Mut = query.Mut;

// NOTE: assigning lists/maps will create new ones, so try to take reference to already existing ones where possible
