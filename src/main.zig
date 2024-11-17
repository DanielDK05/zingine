const std = @import("std");
// const assert = std.debug.assert;

// const ecs = @import("ecs.zig");

// const Allocator = std.mem.Allocator;

// const Engine = @import("engine.zig").Engine;
// const Vec2 = @import("math.zig").Vec2;

// const APP_NAME = "Project Greasy Hands!";
// const WINDOW_SIZE = Vec2(u32).init(800, 600);
// const SPEED: f32 = 0.001;

const query = @import("ecs/query.zig");

const SELECT = query.Keywords.SELECT;
const WITH = query.Keywords.WITH;

pub fn main() !void {
    // const systems = comptime blk: {
    //     var builder = ecs.ApplicationBuilder{};

    //     builder.addSystem(&testSystem1);
    //     builder.addSystem(&testSystem2);
    //     builder.addSystem(&testSystem3);

    //     const systems = builder.registry();

    //     break :blk systems;
    // };

    // systems[0].*();
    // systems[1].*(69);

    for (0..10) |_| {
        std.log.info("time: {}", .{std.time.microTimestamp()});
    }
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

fn testSystem1(test_query: query.Query(.{ SELECT, Player, Sword, WITH, Apple })) void {
    _ = test_query;
    std.debug.print("Hello, ECS!\n", .{});
}

test {
    std.testing.refAllDecls(@This());
}
