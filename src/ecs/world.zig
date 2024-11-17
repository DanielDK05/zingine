const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const Entity = @import("entity.zig").Entity;

pub const World = struct {
    entities: std.ArrayList(Entity),

    pub fn init(allocator: mem.Allocator) World {
        return World{
            .entities = std.ArrayList(Entity).init(allocator),
        };
    }
};
