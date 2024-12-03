const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const utils = @import("../utils.zig");
const ecs = @import("../ecs.zig");

pub fn World(comptime builder: *const ecs.ApplicationBuilder) type {
    const fullComponentSet = utils.TupleOfTypes2(builder.components()){};
    const ArchetypeStore = ecs.archetype.ArchetypeStore(fullComponentSet);
    const ArchetypeFlags = ArchetypeStore.Flags();
    const ConnectionEntry = struct {
        entity: ecs.Entity,
        flags: ArchetypeFlags,
        index: usize,
    };

    return struct {
        const Self = @This();

        entities: std.ArrayList(ecs.Entity),
        archetypes: ArchetypeStore,
        connections: std.ArrayList(ConnectionEntry),

        pub fn init(allocator: mem.Allocator) Self {
            return .{
                .entities = std.ArrayList(ecs.Entity).init(allocator),
                .archetypes = ArchetypeStore.init(allocator),
                .connections = std.ArrayList(ConnectionEntry).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entities.deinit();
        }

        pub fn spawnEntity(self: *Self) mem.Allocator.Error!ecs.Entity {
            const entity = ecs.Entity{ .id = @truncate(self.entities.items.len) };
            try self.entities.append(entity);
            return entity;
        }

        pub fn attachComponents(self: *Self, entity: ecs.Entity, comptime components: anytype) mem.Allocator.Error!void {
            const flags = comptime ecs.archetype.getFlags(fullComponentSet, utils.TupleOfTypes(components){});
            const archetype = try self.archetypes.getOrPut(flags, utils.TupleOfTypes(components){});
            const index = archetype.entries.items.len;

            try self.connections.append(.{
                .entity = entity,
                .flags = flags,
                .index = index,
            });
        }
    };
}
