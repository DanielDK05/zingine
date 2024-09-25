const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ProjectGreasyHands",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .link_libc = true,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    exe.addLibraryPath(b.path("deps/lib"));
    exe.addIncludePath(b.path("deps/include"));

    // === VULKAN ===
    const vkzig_dep = b.dependency("vulkan", .{
        .registry = @as([]const u8, b.pathFromRoot("vk.xml")),
    });
    const vkzig_bindings = vkzig_dep.module("vulkan-zig");
    exe.root_module.addImport("vulkan", vkzig_bindings);

    // === GLFW ===
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("gdi32");

    const vert_cmd = b.addSystemCommand(&.{
        "glslc",
        "--target-env=vulkan1.2",
        "-o",
    });
    const vert_spv = vert_cmd.addOutputFileArg("vert.spv");
    vert_cmd.addFileArg(b.path("src/shaders/triangle.vert"));
    exe.root_module.addAnonymousImport("vertex_shader", .{
        .root_source_file = vert_spv,
    });

    const frag_cmd = b.addSystemCommand(&.{
        "glslc",
        "--target-env=vulkan1.2",
        "-o",
    });
    const frag_spv = frag_cmd.addOutputFileArg("frag.spv");
    frag_cmd.addFileArg(b.path("src/shaders/triangle.frag"));
    exe.root_module.addAnonymousImport("fragment_shader", .{
        .root_source_file = frag_spv,
    });

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
