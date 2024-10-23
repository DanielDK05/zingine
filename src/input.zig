const std = @import("std");
const c = @import("c.zig");

pub const Keys = struct {
    pub fn keyPressed(window: *c.GLFWwindow, key: KeyCode) bool {
        return c.glfwGetKey(window, glfwKey(key)) == c.GLFW_PRESS;
    }

    fn glfwKey(key: KeyCode) c_int {
        return switch (key) {
            .KEY_W => c.GLFW_KEY_W,
            .KEY_A => c.GLFW_KEY_A,
            .KEY_S => c.GLFW_KEY_S,
            .KEY_D => c.GLFW_KEY_D,
            .ARROW_LEFT => c.GLFW_KEY_LEFT,
            .ARROW_RIGHT => c.GLFW_KEY_RIGHT,
            .ARROW_UP => c.GLFW_KEY_UP,
            .ARROW_DOWN => c.GLFW_KEY_DOWN,
        };
    }
};

pub const KeyCode = enum {
    KEY_W,
    KEY_A,
    KEY_S,
    KEY_D,
    ARROW_LEFT,
    ARROW_RIGHT,
    ARROW_UP,
    ARROW_DOWN,
};
