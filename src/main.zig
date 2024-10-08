const std = @import("std");
const vk = @import("vulkan");
const c = @import("c.zig");
const GraphicsContext = @import("render/graphics_context.zig").GraphicsContext;
const Swapchain = @import("render/swapchain.zig").Swapchain;
const Allocator = std.mem.Allocator;

const Engine = @import("engine.zig").Engine;
const Vec2 = @import("math.zig").Vec2;

const APP_NAME = "Project Greasy Hands!";
const WINDOW_SIZE = Vec2(u32).init(800, 600);
const SPEED: f32 = 0.001;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const result = gpa.deinit();

        if (result == .leak) {
            std.debug.print("Memory leakage detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var engine = try Engine.init(allocator, APP_NAME, WINDOW_SIZE);
    defer engine.deinit();

    try engine.run();
}
