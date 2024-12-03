const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const StructField = std.builtin.Type.StructField;

const ecs = @import("../ecs.zig");

/// Should not be used directly, use `ApplicationBuilder` instead.
pub fn Application(comptime builder: *const ApplicationBuilder) type {
    const World = ecs.World(builder);
    const registry = ecs.storage.Registry(builder).init();

    return struct {
        const Self = @This();

        comptime registry: @TypeOf(registry) = registry,

        allocator: mem.Allocator,
        world: World,
        // command_bus: ecs.CommandBus,

        pub fn init(allocator: mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .world = World.init(allocator),
                // .command_bus = ecs.CommandBus.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit();
            // self.command_bus.deinit();
        }

        pub fn run(self: *Self) !void {
            try self.runSystems();
        }

        fn runSystems(self: *Self) !void {
            inline for (0..std.meta.fields(@TypeOf(self.registry.systems)).len) |i| {
                const system = self.registry.systems[i];

                const args = std.meta.ArgsTuple(@TypeOf(system));
                const paramsToPass: GetSystemParams(system) = undefined;

                inline for (std.meta.fields(args), 0..) |arg, cur_param_index| {
                    if (ecs.system.Param.from(arg.type) != .query) {
                        continue;
                    }
                    _ = cur_param_index;

                    // const queryResult = arg.type.Result();
                    // inline for (std.meta.fields(queryResult)) |component| {
                    //     _ = component;
                    //     paramsToPass[cur_param_index][j] = undefined;
                    //     j += 1;
                    // }
                }

                try @call(.auto, system, paramsToPass);

                // const requests = self.command_bus.flush();
                // defer self.allocator.free(requests);
                //
                // for (requests) |request| {
                //     switch (request) {
                //         .spawn => {},
                //         .attach => |entity, C| {
                //             self.world.spawnEntity();
                //         },
                //     }
                // }
            }
        }

        fn GetSystemParams(comptime system: anytype) type {
            var fields: []const StructField = &[_]StructField{};

            const args = std.meta.ArgsTuple(@TypeOf(system));

            inline for (std.meta.fields(args)) |field| {
                if (ecs.system.Param.from(field.type) != .query) {
                    continue;
                }

                fields = fields ++ &[_]StructField{.{
                    .alignment = @alignOf(field.type),
                    .name = std.fmt.comptimePrint("{d}", .{fields.len}),
                    .default_value = null,
                    .is_comptime = false,
                    .type = field.type,
                }};
            }

            return @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = fields,
                    .decls = &[_]std.builtin.Type.Declaration{},
                    .is_tuple = true,
                },
            });
        }
    };
}

pub const ApplicationBuilder = struct {
    system_ptrs: []const *const anyopaque = &[_]*const anyopaque{},
    system_types: []const type = &[_]type{},

    pub fn init() ApplicationBuilder {
        return .{};
    }

    pub fn addSystem(comptime self: *ApplicationBuilder, comptime system: anytype) void {
        self.system_types = self.system_types ++ &[_]type{@TypeOf(system)};
        self.system_ptrs = self.system_ptrs ++ &[_]*const anyopaque{@constCast(system)};
    }

    pub fn build(comptime self: *const ApplicationBuilder) Application(self) {
        return Application(self).init(std.heap.page_allocator);
    }

    pub fn components(comptime self: *const ApplicationBuilder) []const type {
        var types: []const type = &[_]type{};

        for (self.system_types) |system_type| {
            assert(@typeInfo(system_type) == .pointer);
            const pointer_child = @typeInfo(system_type).pointer.child;
            assert(@typeInfo(pointer_child) == .@"fn");

            const args = std.meta.fields(std.meta.ArgsTuple(pointer_child));

            for (args) |arg| {
                if (ecs.system.Param.from(arg.type) == .query) {
                    const result = arg.type.Result(){};
                    for (std.meta.fields(@TypeOf(result)), 0..) |_, i| {
                        types = types ++ &[_]type{result[i]};
                    }
                }
            }
        }

        return types;
    }
};
