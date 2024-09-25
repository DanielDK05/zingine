const std = @import("std");
const c = @import("c.zig");

pub const Keys = struct {
    pub fn keyPressed(window: c.GLFWwindow, key: KeyCode) bool {
        return c.glfwGetKey(window, glfwKey(key)) == c.GLFW_PRESS;
    }

    fn glfwKey(key: KeyCode) c.int {
        switch (key) {
            .W => c.GLFW_KEY_W,
            .A => c.GLFW_KEY_A,
            .S => c.GLFW_KEY_S,
            .D => c.GLFW_KEY_D,
        }
    }
};

pub const KeyCode = enum {
    W,
    A,
    S,
    D,
};
