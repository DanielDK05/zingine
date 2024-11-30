const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const utils = @import("../utils.zig");
const ecs = @import("../ecs.zig");

pub const IWorld = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        spawnEntity: *const fn (ctx: *anyopaque) mem.Allocator.Error!ecs.Entity,
        attachComponents: *const fn (ctx: *anyopaque, entity: ecs.Entity, comptime components: anytype) mem.Allocator.Error!void,
    };

    pub fn spawnEntity(self: IWorld) mem.Allocator.Error!ecs.Entity {
        // return @call(.always_inline, self.vtable.spawnEntity, .{self.ptr});
        return self.vtable.spawnEntity(self.ptr);
    }

    pub fn attachComponents(self: *IWorld, entity: ecs.Entity, comptime components: anytype) mem.Allocator.Error!void {
        return self.vtable.attachComponents(self.ptr, entity, components);
    }
};

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

        pub fn iworld(self: *Self) IWorld {
            return .{
                .ptr = self,
                .vtable = &.{
                    .spawnEntity = spawnEntity,
                    .attachComponents = &attachComponents,
                },
            };
        }

        pub fn spawnEntity(ctx: *anyopaque) mem.Allocator.Error!ecs.Entity {
            const self: *Self = @ptrCast(@alignCast(ctx));
            const entity = ecs.Entity{ .id = @truncate(self.entities.items.len) };
            try self.entities.append(entity);
            return entity;
        }

        pub fn spawnEntity2(self: *Self) mem.Allocator.Error!ecs.Entity {
            const entity = ecs.Entity{ .id = @truncate(self.entities.items.len) };
            try self.entities.append(entity);
            return entity;
        }

        pub fn attachComponents(ctx: *anyopaque, entity: ecs.Entity, comptime components: anytype) mem.Allocator.Error!void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            const flags = ecs.archetype.getFlag(ArchetypeFlags, components);
            const archetype = try self.archetypes.getOrPut(flags);
            const index = archetype.entries.len;

            try self.connections.append(.{
                .entity = entity,
                .flags = flags,
                .index = index,
            });
        }

        pub fn attachComponents2(self: *Self, entity: ecs.Entity, comptime components: anytype) mem.Allocator.Error!void {
            const flags = ecs.archetype.getFlags(fullComponentSet, utils.UnpackTupleOfTypes(components));
            const archetype = try self.archetypes.getOrPut(flags);
            const index = archetype.entries.len;

            try self.connections.append(.{
                .entity = entity,
                .flags = flags,
                .index = index,
            });
        }
    };
}
