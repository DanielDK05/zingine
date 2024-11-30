const std = @import("std");
// const assert = std.debug.assert;

// const ecs = @import("ecs.zig");

// const Allocator = std.mem.Allocator;

// const Engine = @import("engine.zig").Engine;
// const Vec2 = @import("math.zig").Vec2;

// const APP_NAME = "Project Greasy Hands!";
// const WINDOW_SIZE = Vec2(u32).init(800, 600);
// const SPEED: f32 = 0.001;

pub const ecs = @import("ecs.zig");
pub const query = @import("ecs/query.zig");

const SELECT = query.Keywords.SELECT;
const WITH = query.Keywords.WITH;

pub fn main() !void {
    var application = comptime blk: {
        var builder = ecs.ApplicationBuilder{};

        builder.addSystem(&testSystem2);

        break :blk builder.build();
    };
    defer application.deinit();

    const entity = try application.world.spawnEntity2();
    try application.world.attachComponents2(entity, .{
        Player{ .id = 0 },
        Sword{ .damage = 10 },
        Apple{ .color = .red },
    });

    try application.run();
}

const Player = struct {
    id: u32,
};

const Sword = struct {
    damage: u32,
};

const Apple = struct {
    color: enum { red, green },
};

fn testSystem3(world: ecs.IWorld) !void {
    _ = world;
}

// fn testSystem1(world: ecs.IWorld) !void {
//     const entity = try world.spawnEntity();
//     std.log.debug("Hello, ECS! entity: {d}\n", .{entity.id});
//     // try world.attachComponents(entity, .{ Player{ .id = 1 }, Sword{ .damage = 10 }, Apple{ .color = .red } });
// }

fn testSystem2(test_query: ecs.Query(.{ SELECT, Player, Sword, WITH, Apple })) !void {
    // const player, const sword = test_query.result;

    // std.debug.print("Hello, ECS! id: {d} dmg: {d}\n", .{ player.id, sword.damage });
    _ = test_query;
    std.debug.print("Hello, ECS! testSystem2\n", .{});
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
