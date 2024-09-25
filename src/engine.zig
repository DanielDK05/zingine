const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig");
const vk = @import("vulkan");

const gc = @import("graphics_context.zig");
const input = @import("input.zig");
const sc = @import("swapchain.zig");

const w = @import("window.zig");
const Window = w.Window;

const math = @import("math.zig");
const Vec2 = math.Vec2;

pub const Engine = struct {
    graphics_context: gc.GraphicsContext,
    swapchain: sc.Swapchain,
    window: Window,
    allocator: Allocator,

    pub fn init(allocator: Allocator, appName: [*:0]const u8, windowSize: Vec2(u32)) !Engine {
        const window = try Window.init(Vec2(u32).init(windowSize.x, windowSize.y), appName);
        const graphics_context = try gc.GraphicsContext.init(allocator, appName, window.glfw_window);
        const swapchain = try sc.Swapchain.init(&graphics_context, allocator, vk.Extent2D{ .width = windowSize.x, .height = windowSize.y });

        return Engine{
            .window = window,
            .graphics_context = graphics_context,
            .swapchain = swapchain,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Engine) void {
        std.debug.print("Deinitializing engine\n", .{});
        self.window.deinit();
        // self.graphics_context.deinit();
    }

    pub fn run(self: Engine) void {
        while (!self.window.shouldClose()) {
            std.time.sleep(100000000);
            std.debug.print("Running engine\n", .{});
        }
    }
};
