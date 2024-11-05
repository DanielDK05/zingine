const std = @import("std");
const mem = std.mem;

const vk = @import("vulkan");

const graphics_context = @import("graphics_context.zig");
const swapchain = @import("swapchain.zig");

const Window = @import("../window.zig").Window;
const GraphicsContext = graphics_context.GraphicsContext;
const Swapchain = swapchain.Swapchain;

const vert_spv align(@alignOf(u32)) = @embedFile("../shaders/triangle.vert").*;
const frag_spv align(@alignOf(u32)) = @embedFile("../shaders/triangle.frag").*;

pub const Vertex = struct {
    const binding_description = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .input_rate = .vertex,
    };

    const attribute_description = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .binding = 0,
            .location = 1,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Vertex, "color"),
        },
    };

    pos: [2]f32,
    color: [3]f32,
};

const VERTICES = [_]Vertex{
    .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0, 1, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
};

pub const Renderer = struct {
    allocator: mem.Allocator,
    graphics_context: GraphicsContext,
    swapchain: Swapchain,

    command_buffers: []vk.CommandBuffer = undefined,
    framebuffers: []vk.Framebuffer = undefined,
    pool: vk.CommandPool = undefined,
    buffer: vk.Buffer = undefined,
    pipeline: vk.Pipeline = undefined,
    render_pass: vk.RenderPass = undefined,
    memory: vk.DeviceMemory = undefined,
    pipeline_layout: vk.PipelineLayout = undefined,
    vertices: []Vertex = @constCast(&[_]Vertex{}),

    cmdbuf_active: bool = false,

    pub fn init(allocator: mem.Allocator, app_name: [*:0]const u8, window: Window) !Renderer {
        const gc = try GraphicsContext.init(allocator, app_name, window.glfw_window);
        const sc = try Swapchain.init(&gc, allocator, vk.Extent2D{ .width = window.size.x, .height = window.size.y });

        return Renderer{
            .graphics_context = gc,
            .swapchain = sc,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Renderer) void {
        self.swapchain.deinit(&self.graphics_context);
        self.graphics_context.deinit();
        self.graphics_context.device.destroyBuffer(self.buffer, null);
        self.graphics_context.device.destroyCommandPool(self.pool, null);
        self.graphics_context.device.destroyRenderPass(self.render_pass, null);
        self.graphics_context.device.destroyPipeline(self.pipeline, null);
        self.graphics_context.device.freeMemory(self.memory, null);
        self.graphics_context.device.destroyPipelineLayout(self.pipeline_layout, null);
        self.destroyCommandBuffers();
        self.destroyFramebuffers();
    }

    pub fn end(self: *Renderer) !void {
        try self.swapchain.waitForAllFences(&self.graphics_context);
        try self.graphics_context.device.deviceWaitIdle();
    }

    pub fn startup(self: *Renderer) !void {
        const pipeline_layout = try self.graphics_context.device.createPipelineLayout(&.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        }, null);

        const render_pass = try self.createRenderPass();
        self.render_pass = render_pass;

        const pipeline = try createPipeline(&self.graphics_context, pipeline_layout, render_pass);
        self.pipeline = pipeline;

        const framebuffers = try self.createFramebuffers(self.render_pass);
        self.framebuffers = framebuffers;

        const pool = try self.graphics_context.device.createCommandPool(&.{
            .queue_family_index = self.graphics_context.graphics_queue.family,
        }, null);
        self.pool = pool;

        try self.registerVertices(@constCast(&VERTICES));
    }

    pub fn registerVertices(self: *Renderer, vertices: []Vertex) !void {
        self.vertices = vertices;

        if (self.cmdbuf_active) self.destroyCommandBuffers();

        self.graphics_context.device.destroyBuffer(self.buffer, null);
        const buffer = try self.graphics_context.device.createBuffer(&.{
            .size = @as(u64, @truncate(self.vertices.len)) * @sizeOf(Vertex),
            .usage = .{ .transfer_dst_bit = true, .vertex_buffer_bit = true },
            .sharing_mode = .exclusive,
        }, null);
        self.buffer = buffer;

        const memory_requirements = self.graphics_context.device.getBufferMemoryRequirements(buffer);
        const memory = try self.graphics_context.allocate(memory_requirements, .{ .device_local_bit = true });
        try self.graphics_context.device.bindBufferMemory(buffer, memory, 0);
        self.graphics_context.free(self.memory);
        self.memory = memory;

        try self.uploadVertices();

        self.command_buffers = try self.createCommandBuffers();
        self.cmdbuf_active = true;
    }

    pub fn draw(self: *Renderer, window: *Window) !void {
        const command_buffer = self.command_buffers[self.swapchain.image_index];

        const state = self.swapchain.present(&self.graphics_context, command_buffer) catch |err| switch (err) {
            error.OutOfDateKHR => Swapchain.PresentState.Suboptimal,
            else => |narrow| return narrow,
        };

        const framebufferSize = window.getFrameBufferSize();

        if (state == .Suboptimal or !window.size.eq(framebufferSize)) {
            window.size = framebufferSize;
            const extent = vk.Extent2D{ .width = window.size.x, .height = window.size.y };

            try self.swapchain.recreate(&self.graphics_context, extent);

            self.destroyFramebuffers();
            self.framebuffers = try self.createFramebuffers(self.render_pass);

            self.destroyCommandBuffers();
            self.command_buffers = try self.createCommandBuffers();
        }
    }

    fn uploadVertices(self: *const Renderer) !void {
        const staging_buffer = try self.graphics_context.device.createBuffer(&.{
            .size = @as(u64, @truncate(self.vertices.len)) * @sizeOf(Vertex),
            .usage = .{ .transfer_src_bit = true },
            .sharing_mode = .exclusive,
        }, null);
        defer self.graphics_context.device.destroyBuffer(staging_buffer, null);
        const mem_reqs = self.graphics_context.device.getBufferMemoryRequirements(staging_buffer);
        const staging_memory = try self.graphics_context.allocate(mem_reqs, .{ .host_visible_bit = true, .host_coherent_bit = true });
        defer self.graphics_context.device.freeMemory(staging_memory, null);
        try self.graphics_context.device.bindBufferMemory(staging_buffer, staging_memory, 0);

        {
            const data = try self.graphics_context.device.mapMemory(staging_memory, 0, vk.WHOLE_SIZE, .{});
            defer self.graphics_context.device.unmapMemory(staging_memory);

            const gpu_vertices: [*]Vertex = @ptrCast(@alignCast(data));
            @memcpy(gpu_vertices, self.vertices);
        }

        try self.copyBuffer(staging_buffer, @as(u64, @truncate(self.vertices.len)) * @sizeOf(Vertex));
    }

    fn copyBuffer(self: *const Renderer, src: vk.Buffer, size: vk.DeviceSize) !void {
        var cmdbuf_handle: vk.CommandBuffer = undefined;
        try self.graphics_context.device.allocateCommandBuffers(
            &.{
                .command_pool = self.pool,
                .level = .primary,
                .command_buffer_count = 1,
            },
            @ptrCast(&cmdbuf_handle),
        );
        defer self.graphics_context.device.freeCommandBuffers(self.pool, 1, @ptrCast(&cmdbuf_handle));

        const cmdbuf = GraphicsContext.CommandBuffer.init(cmdbuf_handle, self.graphics_context.device.wrapper);

        try cmdbuf.beginCommandBuffer(&.{
            .flags = .{ .one_time_submit_bit = true },
        });

        const region = vk.BufferCopy{
            .src_offset = 0,
            .dst_offset = 0,
            .size = size,
        };
        cmdbuf.copyBuffer(src, self.buffer, 1, @ptrCast(&region));

        try cmdbuf.endCommandBuffer();

        const submit_info = vk.SubmitInfo{
            .command_buffer_count = 1,
            .p_command_buffers = (&cmdbuf.handle)[0..1],
            .p_wait_dst_stage_mask = undefined,
        };
        try self.graphics_context.device.queueSubmit(self.graphics_context.graphics_queue.handle, 1, @ptrCast(&submit_info), .null_handle);
        try self.graphics_context.device.queueWaitIdle(self.graphics_context.graphics_queue.handle);
    }

    fn createCommandBuffers(self: *Renderer) ![]vk.CommandBuffer {
        const cmdbufs = try self.allocator.alloc(vk.CommandBuffer, self.framebuffers.len);
        errdefer self.allocator.free(cmdbufs);

        try self.graphics_context.device.allocateCommandBuffers(&.{
            .command_pool = self.pool,
            .level = .primary,
            .command_buffer_count = @intCast(cmdbufs.len),
        }, cmdbufs.ptr);
        errdefer self.graphics_context.device.freeCommandBuffers(self.pool, @intCast(cmdbufs.len), cmdbufs.ptr);

        const clear = vk.ClearValue{
            .color = .{ .float_32 = .{ 0, 0, 0, 1 } },
        };

        const viewport = vk.Viewport{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(self.swapchain.extent.width),
            .height = @floatFromInt(self.swapchain.extent.height),
            .min_depth = 0,
            .max_depth = 1,
        };

        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapchain.extent,
        };

        for (cmdbufs, self.framebuffers) |cmdbuf, framebuffer| {
            try self.graphics_context.device.beginCommandBuffer(cmdbuf, &.{});

            self.graphics_context.device.cmdSetViewport(cmdbuf, 0, 1, @ptrCast(&viewport));
            self.graphics_context.device.cmdSetScissor(cmdbuf, 0, 1, @ptrCast(&scissor));

            const render_area = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swapchain.extent,
            };

            self.graphics_context.device.cmdBeginRenderPass(cmdbuf, &.{
                .render_pass = self.render_pass,
                .framebuffer = framebuffer,
                .render_area = render_area,
                .clear_value_count = 1,
                .p_clear_values = @ptrCast(&clear),
            }, .@"inline");

            self.graphics_context.device.cmdBindPipeline(cmdbuf, .graphics, self.pipeline);
            const offset = [_]vk.DeviceSize{0};
            self.graphics_context.device.cmdBindVertexBuffers(cmdbuf, 0, 1, @ptrCast(&self.buffer), &offset);
            self.graphics_context.device.cmdDraw(cmdbuf, @as(u32, @truncate(self.vertices.len)), 1, 0, 0);

            self.graphics_context.device.cmdEndRenderPass(cmdbuf);
            try self.graphics_context.device.endCommandBuffer(cmdbuf);
        }

        return cmdbufs;
    }

    fn destroyCommandBuffers(self: *const Renderer) void {
        self.graphics_context.device.freeCommandBuffers(self.pool, @truncate(self.command_buffers.len), self.command_buffers.ptr);
        self.allocator.free(self.command_buffers);
    }

    fn createFramebuffers(self: *Renderer, render_pass: vk.RenderPass) ![]vk.Framebuffer {
        const framebuffers = try self.allocator.alloc(vk.Framebuffer, self.swapchain.swap_images.len);
        errdefer self.allocator.free(self.framebuffers);

        var i: usize = 0;
        errdefer for (framebuffers[0..i]) |fb| self.graphics_context.device.destroyFramebuffer(fb, null);

        for (framebuffers) |*fb| {
            fb.* = try self.graphics_context.device.createFramebuffer(&.{
                .render_pass = render_pass,
                .attachment_count = 1,
                .p_attachments = @ptrCast(&self.swapchain.swap_images[i].view),
                .width = self.swapchain.extent.width,
                .height = self.swapchain.extent.height,
                .layers = 1,
            }, null);
            i += 1;
        }

        return framebuffers;
    }

    fn destroyFramebuffers(self: *const Renderer) void {
        for (self.framebuffers) |fb| self.graphics_context.device.destroyFramebuffer(fb, null);
        self.allocator.free(self.framebuffers);
    }

    fn createRenderPass(self: *Renderer) !vk.RenderPass {
        const color_attachment = vk.AttachmentDescription{
            .format = self.swapchain.surface_format.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .present_src_khr,
        };

        const color_attachment_ref = vk.AttachmentReference{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const subpass = vk.SubpassDescription{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast(&color_attachment_ref),
        };

        return try self.graphics_context.device.createRenderPass(&.{
            .attachment_count = 1,
            .p_attachments = @ptrCast(&color_attachment),
            .subpass_count = 1,
            .p_subpasses = @ptrCast(&subpass),
        }, null);
    }

    // fn createRenderPipeline(self: *Renderer, pipeline_layout: vk.PipelineLayout, render_pass: vk.RenderPass) !vk.Pipeline {
    //     const vertex_shader = try self.graphics_context.device.createShaderModule(&.{
    //         .code_size = vert_spv.len,
    //         .p_code = @ptrCast(&vert_spv),
    //     }, null);
    //     defer self.graphics_context.device.destroyShaderModule(vertex_shader, null);
    //
    //     const frag_shader = try self.graphics_context.device.createShaderModule(&.{
    //         .code_size = frag_spv.len,
    //         .p_code = @ptrCast(&frag_spv),
    //     }, null);
    //     defer self.graphics_context.device.destroyShaderModule(frag_shader, null);
    //
    //     const shader_stage_create_info = [_]vk.PipelineShaderStageCreateInfo{
    //         .{ .stage = .{ .vertex_bit = true }, .module = vertex_shader, .p_name = "main" },
    //         .{ .stage = .{ .fragment_bit = true }, .module = frag_shader, .p_name = "main" },
    //     };
    //
    //     const vertex_input_state_create_info = vk.PipelineVertexInputStateCreateInfo{
    //         .vertex_binding_description_count = 1,
    //         .p_vertex_binding_descriptions = @ptrCast(&Vertex.binding_description),
    //         .vertex_attribute_description_count = Vertex.attribute_description.len,
    //         .p_vertex_attribute_descriptions = &Vertex.attribute_description,
    //     };
    //
    //     const input_assembly_state_create_info = vk.PipelineInputAssemblyStateCreateInfo{
    //         .topology = .triangle_list,
    //         .primitive_restart_enable = vk.FALSE,
    //     };
    //
    //     const viewport_state_create_info = vk.PipelineViewportStateCreateInfo{
    //         .viewport_count = 1,
    //         .p_viewports = undefined,
    //         .scissor_count = 1,
    //         .p_scissors = undefined,
    //     };
    //
    //     const rasterization_state_create_info = vk.PipelineRasterizationStateCreateInfo{
    //         .depth_clamp_enable = vk.FALSE,
    //         .rasterizer_discard_enable = vk.FALSE,
    //         .polygon_mode = .fill,
    //         .cull_mode = .{ .back_bit = true },
    //         .front_face = .clockwise,
    //         .depth_bias_enable = vk.FALSE,
    //         .depth_bias_clamp = 0,
    //         .depth_bias_constant_factor = 0,
    //         .depth_bias_slope_factor = 0,
    //         .line_width = 1,
    //     };
    //
    //     const multisample_state_create_info = vk.PipelineMultisampleStateCreateInfo{
    //         .rasterization_samples = .{ .@"1_bit" = true },
    //         .sample_shading_enable = vk.FALSE,
    //         .min_sample_shading = 1,
    //         .alpha_to_coverage_enable = vk.FALSE,
    //         .alpha_to_one_enable = vk.FALSE,
    //     };
    //
    //     const color_blend_attachment_state = vk.PipelineColorBlendAttachmentState{
    //         .blend_enable = vk.FALSE,
    //         .src_color_blend_factor = .one,
    //         .dst_color_blend_factor = .zero,
    //         .color_blend_op = .add,
    //         .src_alpha_blend_factor = .one,
    //         .dst_alpha_blend_factor = .zero,
    //         .alpha_blend_op = .add,
    //         .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
    //     };
    //
    //     const color_blend_state_create_info = vk.PipelineColorBlendStateCreateInfo{
    //         .logic_op_enable = vk.FALSE,
    //         .logic_op = .copy,
    //         .attachment_count = 1,
    //         .p_attachments = @ptrCast(&color_blend_attachment_state),
    //         .blend_constants = [4]f32{ 0, 0, 0, 0 },
    //     };
    //
    //     const dyn_state = [_]vk.DynamicState{ .viewport, .scissor };
    //     const dynamic_state_create_info = vk.PipelineDynamicStateCreateInfo{
    //         .flags = .{},
    //         .dynamic_state_count = dyn_state.len,
    //         .p_dynamic_states = &dyn_state,
    //     };
    //
    //     const graphics_pipeline_create_info = vk.GraphicsPipelineCreateInfo{
    //         .flags = .{},
    //         .stage_count = 2,
    //         .p_stages = &shader_stage_create_info,
    //         .p_vertex_input_state = &vertex_input_state_create_info,
    //         .p_input_assembly_state = &input_assembly_state_create_info,
    //         .p_tessellation_state = null,
    //         .p_viewport_state = &viewport_state_create_info,
    //         .p_rasterization_state = &rasterization_state_create_info,
    //         .p_multisample_state = &multisample_state_create_info,
    //         .p_depth_stencil_state = null,
    //         .p_color_blend_state = &color_blend_state_create_info,
    //         .p_dynamic_state = &dynamic_state_create_info,
    //         .layout = pipeline_layout,
    //         .render_pass = render_pass,
    //         .subpass = 0,
    //         .base_pipeline_handle = .null_handle,
    //         .base_pipeline_index = -1,
    //     };
    //
    //     var pipeline: vk.Pipeline = undefined;
    //     _ = try self.graphics_context.device.createGraphicsPipelines{
    //         .null_handle,
    //         1,
    //         @ptrCast(&graphics_pipeline_create_info),
    //         null,
    //         @ptrCast(&pipeline),
    //     };
    //     return pipeline;
    // }
};

fn createPipeline(
    gc: *const GraphicsContext,
    layout: vk.PipelineLayout,
    render_pass: vk.RenderPass,
) !vk.Pipeline {
    const vert = try gc.device.createShaderModule(&.{
        .code_size = vert_spv.len,
        .p_code = @ptrCast(&vert_spv),
    }, null);
    defer gc.device.destroyShaderModule(vert, null);

    const frag = try gc.device.createShaderModule(&.{
        .code_size = frag_spv.len,
        .p_code = @ptrCast(&frag_spv),
    }, null);
    defer gc.device.destroyShaderModule(frag, null);

    const pssci = [_]vk.PipelineShaderStageCreateInfo{
        .{
            .stage = .{ .vertex_bit = true },
            .module = vert,
            .p_name = "main",
        },
        .{
            .stage = .{ .fragment_bit = true },
            .module = frag,
            .p_name = "main",
        },
    };

    const pvisci = vk.PipelineVertexInputStateCreateInfo{
        .vertex_binding_description_count = 1,
        .p_vertex_binding_descriptions = @ptrCast(&Vertex.binding_description),
        .vertex_attribute_description_count = Vertex.attribute_description.len,
        .p_vertex_attribute_descriptions = &Vertex.attribute_description,
    };

    const piasci = vk.PipelineInputAssemblyStateCreateInfo{
        .topology = .triangle_list,
        .primitive_restart_enable = vk.FALSE,
    };

    const pvsci = vk.PipelineViewportStateCreateInfo{
        .viewport_count = 1,
        .p_viewports = undefined, // set in createCommandBuffers with cmdSetViewport
        .scissor_count = 1,
        .p_scissors = undefined, // set in createCommandBuffers with cmdSetScissor
    };

    const prsci = vk.PipelineRasterizationStateCreateInfo{
        .depth_clamp_enable = vk.FALSE,
        .rasterizer_discard_enable = vk.FALSE,
        .polygon_mode = .fill,
        .cull_mode = .{ .back_bit = true },
        .front_face = .clockwise,
        .depth_bias_enable = vk.FALSE,
        .depth_bias_constant_factor = 0,
        .depth_bias_clamp = 0,
        .depth_bias_slope_factor = 0,
        .line_width = 1,
    };

    const pmsci = vk.PipelineMultisampleStateCreateInfo{
        .rasterization_samples = .{ .@"1_bit" = true },
        .sample_shading_enable = vk.FALSE,
        .min_sample_shading = 1,
        .alpha_to_coverage_enable = vk.FALSE,
        .alpha_to_one_enable = vk.FALSE,
    };

    const pcbas = vk.PipelineColorBlendAttachmentState{
        .blend_enable = vk.FALSE,
        .src_color_blend_factor = .one,
        .dst_color_blend_factor = .zero,
        .color_blend_op = .add,
        .src_alpha_blend_factor = .one,
        .dst_alpha_blend_factor = .zero,
        .alpha_blend_op = .add,
        .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
    };

    const pcbsci = vk.PipelineColorBlendStateCreateInfo{
        .logic_op_enable = vk.FALSE,
        .logic_op = .copy,
        .attachment_count = 1,
        .p_attachments = @ptrCast(&pcbas),
        .blend_constants = [_]f32{ 0, 0, 0, 0 },
    };

    const dynstate = [_]vk.DynamicState{ .viewport, .scissor };
    const pdsci = vk.PipelineDynamicStateCreateInfo{
        .flags = .{},
        .dynamic_state_count = dynstate.len,
        .p_dynamic_states = &dynstate,
    };

    const gpci = vk.GraphicsPipelineCreateInfo{
        .flags = .{},
        .stage_count = 2,
        .p_stages = &pssci,
        .p_vertex_input_state = &pvisci,
        .p_input_assembly_state = &piasci,
        .p_tessellation_state = null,
        .p_viewport_state = &pvsci,
        .p_rasterization_state = &prsci,
        .p_multisample_state = &pmsci,
        .p_depth_stencil_state = null,
        .p_color_blend_state = &pcbsci,
        .p_dynamic_state = &pdsci,
        .layout = layout,
        .render_pass = render_pass,
        .subpass = 0,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };

    var pipeline: vk.Pipeline = undefined;
    _ = try gc.device.createGraphicsPipelines(
        .null_handle,
        1,
        @ptrCast(&gpci),
        null,
        @ptrCast(&pipeline),
    );
    return pipeline;
}
