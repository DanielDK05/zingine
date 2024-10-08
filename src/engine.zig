const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig");
const vk = @import("vulkan");

const Renderer = @import("render/renderer.zig").Renderer;
// const gc = @import("graphics_context.zig");
const input = @import("input.zig");
// // const sc = @import("swapchain.zig");

const w = @import("window.zig");
const Window = w.Window;

const math = @import("math.zig");
const Vec2 = math.Vec2;

pub const Engine = struct {
    renderer: Renderer,
    window: Window,
    allocator: Allocator,

    pub fn init(allocator: Allocator, appName: [*:0]const u8, windowSize: Vec2(u32)) !Engine {
        const window = try Window.init(windowSize, appName);
        const renderer = try Renderer.init(allocator, appName, window);

        return Engine{
            .window = window,
            .renderer = renderer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Engine) void {
        std.debug.print("Deinitializing engine\n", .{});
        self.window.deinit();
        self.renderer.deinit();
    }

    pub fn run(self: *Engine) !void {
        try self.startup();

        while (!self.window.shouldClose()) {
            try self.update();
        }
    }

    fn startup(self: *Engine) !void {
        try self.renderer.startup();
    }

    fn update(self: *Engine) !void {
        const windowSize = self.window.getFrameBufferSize();
        if (windowSize.eq(Vec2(u32).ZERO)) {
            self.window.pollEvents();
            return;
        }

        try self.renderer.draw(&self.window);
        self.window.pollEvents();
    }
};
