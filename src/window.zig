const c = @import("c.zig");
const math = @import("math.zig");
const input = @import("input.zig");
const Vec2 = math.Vec2;
const Vec2f32 = Vec2(f32);

pub const WindowInitError = error{
    GLFWInitFailed,
    VulkanNotSupported,
    GlfwWindowCreationFailed,
};

pub const WindowUpdateResult = enum {
    ok,
    skip,
    close,
};

pub const Window = struct {
    glfw_window: *c.GLFWwindow,
    size: Vec2(u32),

    pub fn init(size: Vec2(u32), name: [*:0]const u8) WindowInitError!Window {
        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.GLFWInitFailed;
        }

        if (c.glfwVulkanSupported() != c.GLFW_TRUE) {
            return error.VulkanNotSupported;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

        const window = c.glfwCreateWindow(
            @intCast(size.x),
            @intCast(size.y),
            name,
            null,
            null,
        ) orelse return error.GlfwWindowCreationFailed;

        return Window{ .glfw_window = @constCast(window), .size = size };
    }

    pub fn keyPressed(self: *const Window, key: input.KeyCode) bool {
        return input.Keys.keyPressed(self.glfw_window, key);
    }

    pub fn mousePos(self: *const Window) Vec2f32 {
        var x: f64 = 0.0;
        var y: f64 = 0.0;
        c.glfwGetCursorPos(self.glfw_window, &x, &y);

        return Vec2f32.init(@as(f32, @floatCast(x)) / @as(f32, @floatFromInt(self.size.x)), @as(f32, @floatCast(y)) / @as(f32, @floatFromInt(self.size.y)));
    }

    pub fn deinit(self: Window) void {
        c.glfwTerminate();
        c.glfwDestroyWindow(self.glfw_window);
    }

    pub fn pollEvents(self: Window) void {
        _ = self;
        c.glfwPollEvents();
    }

    pub fn shouldClose(self: Window) bool {
        return c.glfwWindowShouldClose(self.glfw_window) == c.GLFW_TRUE;
    }

    pub fn getFrameBufferSize(self: Window) Vec2(u32) {
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(self.glfw_window, &width, &height);

        return Vec2(u32).init(@intCast(width), @intCast(height));
    }
};
