pub const world = @import("ecs/world.zig");
pub const entity = @import("ecs/entity.zig");

pub const World = world.World;
pub const SystemEntry = world.SystemEntry;
pub const ApplicationBuilder = world.ApplicationBuilder;
pub const Application = world.Application;
pub const Entity = entity.Entity;

// ==== Query ====
pub const query = @import("ecs/query.zig");
pub const Query = query.Query;
pub const SELECT = query.SELECT;
pub const WITH = query.WITH;
pub const AND = query.AND;
pub const OR = query.OR;
pub const WITHOUT = query.WITHOUT;
