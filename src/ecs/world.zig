const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const ecs = @import("../ecs.zig");

pub fn World(comptime builder: *const ecs.ApplicationBuilder) type {
    const ComponentStorage = ecs.storage.ComponentStorage(builder);

    return struct {
        const Self = @This();

        entities: std.ArrayList(ecs.Entity),
        components: ComponentStorage,

        pub fn init(allocator: mem.Allocator) Self {
            return .{
                .entities = std.ArrayList(ecs.Entity).init(allocator),
                .components = initComponents(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entities.deinit();
        }

        pub fn spawnEntity(self: Self) mem.Allocator.Error!ecs.Entity {
            const entity = ecs.Entity{ .id = self.entities.len };
            try self.entities.append(entity);
            return entity;
        }

        // pub fn attachComponent(self: Self, entity: ecs.Entity, component: anytype) void {
        //     assert(entity.id < self.entities.len);
        //
        //
        // }

        fn initComponents(allocator: mem.Allocator) ComponentStorage {
            var components: ComponentStorage = undefined;

            inline for (std.meta.fields(ComponentStorage), 0..) |field, i| {
                components[i] = field.type.init(allocator);
            }

            return components;
        }
    };
}
