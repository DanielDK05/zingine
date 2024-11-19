const std = @import("std");
// const assert = std.debug.assert;

// const ecs = @import("ecs.zig");

// const Allocator = std.mem.Allocator;

// const Engine = @import("engine.zig").Engine;
// const Vec2 = @import("math.zig").Vec2;

// const APP_NAME = "Project Greasy Hands!";
// const WINDOW_SIZE = Vec2(u32).init(800, 600);
// const SPEED: f32 = 0.001;

const ecs = @import("ecs.zig");
const query = @import("ecs/query.zig");

const SELECT = query.Keywords.SELECT;
const WITH = query.Keywords.WITH;

pub fn main() !void {
    var application = comptime blk: {
        var builder = ecs.ApplicationBuilder{};

        builder.addSystem(&testSystem1);

        break :blk builder.build();
    };
    defer application.deinit();

    try application.run();
}

fn Test(comptime T: type) type {
    return struct {
        value: T,
    };
}

const Player = struct {
    id: u32,
};

const Sword = struct {
    damage: u32,
};

const Apple = struct {
    color: u32,
};

fn testSystem1(test_query: ecs.Query(.{ SELECT, Player, Sword, WITH, Apple })) !void {
    const player, const sword = test_query.result;

    std.debug.print("Hello, ECS! id: {d} dmg: {d}\n", .{ player.id, sword.damage });
}

test {
    std.testing.refAllDecls(@This());
}
