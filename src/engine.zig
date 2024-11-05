const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig");
const vk = @import("vulkan");

const Renderer = @import("render/renderer.zig").Renderer;
const Vertex = @import("render/renderer.zig").Vertex;

const input = @import("input.zig");

const w = @import("window.zig");
const Window = w.Window;

const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec2u32 = Vec2(u32);
const Vec2f32 = Vec2(f32);

const VERTICES = [_]Vertex{
    .{ .pos = .{ -0.25, -0.125 }, .color = .{ 1, 0, 0 } }, // top left
    .{ .pos = .{ 0.25, -0.125 }, .color = .{ 0, 1, 0 } }, // top right
    .{ .pos = .{ -0.25, 0.125 }, .color = .{ 0, 0, 1 } }, // bottom left
    .{ .pos = .{ 0.25, -0.125 }, .color = .{ 1, 0, 0 } }, // bottom left
    .{ .pos = .{ 0.25, 0.125 }, .color = .{ 1, 0, 0 } }, // bottom right
    .{ .pos = .{ -0.25, 0.125 }, .color = .{ 1, 0, 0 } }, // top right
};

pub const Engine = struct {
    renderer: Renderer,
    window: Window,
    allocator: Allocator,
    vertices: []Vertex = @constCast(&VERTICES),
    position: Vec2f32 = Vec2f32.ZERO,
    direction: Vec2f32 = Vec2f32.ZERO,

    pub fn init(allocator: Allocator, appName: [*:0]const u8, windowSize: Vec2u32) !Engine {
        const window = try Window.init(windowSize, appName);
        const renderer = try Renderer.init(allocator, appName, window);

        return Engine{
            .window = window,
            .renderer = renderer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Engine) void {
        self.window.deinit();
        self.renderer.deinit();
    }

    pub fn run(self: *Engine) !void {
        try self.startup();

        while (!self.window.shouldClose()) {
            try self.update();
        }

        try self.end();
    }

    fn end(self: *Engine) !void {
        try self.renderer.end();
    }

    fn startup(self: *Engine) !void {
        self.direction = Vec2f32.init(1.0, 0.5).normalize();
        try self.renderer.startup();
    }

    fn update(self: *Engine) !void {
        const windowSize = self.window.getFrameBufferSize();

        if (windowSize.eq(Vec2u32.ZERO)) {
            self.window.pollEvents();
            return;
        }

        const speed = 0.0005;
        self.position = self.position.add(self.direction.scale(speed));

        const vertices = blk: {
            const vertices = try self.allocator.alloc(Vertex, self.vertices.len);

            for (self.vertices, 0..) |vertex, i| {
                const pos = [2]f32{ vertex.pos[0] + self.position.x, vertex.pos[1] + self.position.y };
                vertices[i] = Vertex{ .pos = pos, .color = vertex.color };
            }
            break :blk vertices;
        };
        defer self.allocator.free(vertices);

        if (self.position.x + 0.25 > 1.0 or self.position.x - 0.25 < -1.0) self.direction.x *= -1.0;
        if (self.position.y + 0.125 > 1.0 or self.position.y - 0.125 < -1.0) self.direction.y *= -1.0;
        self.direction = self.direction.normalize();

        try self.renderer.registerVertices(vertices);

        try self.renderer.draw(&self.window);
        self.window.pollEvents();
    }
};
