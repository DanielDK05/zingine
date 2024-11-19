const std = @import("std");
const mem = std.mem;

const ecs = @import("../ecs.zig");

pub const CommandBus = struct {
    allocator: mem.Allocator,
    requests: std.ArrayList(Request),

    pub fn init(allocator: mem.Allocator) CommandBus {
        return CommandBus{
            .allocator = allocator,
            .requests = std.ArrayList(Request).init(allocator),
        };
    }

    pub fn deinit(self: *CommandBus) void {
        self.requests.deinit();
    }

    // pub fn spawnEntity(self: *CommandBus, components: anytype) mem.Allocator.Error!ecs.Entity {
    //     // TODO: compile time check components
    //
    //     const entity = try self.world.spawnEntity();
    //
    //     for (components) |component| {
    //         self.world.attachComponent(self.world, entity, component);
    //     }
    //
    //     return entity;
    // }

    pub fn spawnEntity(self: *CommandBus) void {
        self.requests.append(.{ .spawn = {} });
    }

    pub fn registerComponent(self: *CommandBus, entity: ecs.Entity, comptime C: type) void {
        self.requests.append(.{
            .attach = .{
                .entity = entity,
                .component_type = C,
            },
        });
    }

    pub fn flush(self: *CommandBus) ![]Request {
        const items = try self.allocator.alloc(Request, self.requests.items.len);
        for (self.requests.items, 0..) |request, i| {
            items[i] = request;
        }
        self.requests.clear();
        return items;
    }
};

pub const Request = union(enum) {
    spawn,
    attach: struct { entity: ecs.Entity, component_type: type },
};
