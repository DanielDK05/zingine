const std = @import("std");
const assert = std.debug.assert;

const vk = @import("vulkan");
const c = @import("c.zig");

const ecs = @import("ecs.zig");

const GraphicsContext = @import("render/graphics_context.zig").GraphicsContext;
const Swapchain = @import("render/swapchain.zig").Swapchain;
const Allocator = std.mem.Allocator;

const Engine = @import("engine.zig").Engine;
const Vec2 = @import("math.zig").Vec2;

const APP_NAME = "Project Greasy Hands!";
const WINDOW_SIZE = Vec2(u32).init(800, 600);
const SPEED: f32 = 0.001;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer {
    //     const result = gpa.deinit();
    //
    //     if (result == .leak) {
    //         std.debug.print("Memory leakage detected!\n", .{});
    //     }
    // }
    // const allocator = gpa.allocator();
    //
    // var engine = try Engine.init(allocator, APP_NAME, WINDOW_SIZE);
    // defer engine.deinit();
    //
    // try engine.run();

    testing(
        &[_]type{
            std.ArrayList(u32),
            std.ArrayList(i32),
            std.ArrayList(u64),
            std.ArrayList(u31),
            std.ArrayList(i23),
        },
        std.heap.page_allocator,
    );

    var builder = comptime blk: {
        var builder = ecs.ApplicationBuilder.init();
        builder.registerSystem(testSystem);
        builder.registerSystem(otherSystem);
        break :blk builder;
    };

    const app = builder.build();
    _ = app;
}

pub fn testing(comptime T: []const type, allocator: std.mem.Allocator) void {
    inline for (T) |t| {
        _ = t.init(allocator);
    }
}

pub const Position = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
};

pub const Velocity = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
};

pub const Test = struct {
    a: u32,
};

fn testSystem(query: struct { position: Position, velocity: Velocity }) !void {
    _ = query;

    std.debug.print("testSystem\n", .{});
}

fn otherSystem(query: struct { tasldkj: Test }) !void {
    _ = query;
}
