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
            self.runSystems();
        }

        fn runSystems(self: *Self) void {
            inline for (0..std.meta.fields(@TypeOf(self.registry.systems)).len) |i| {
                const system = self.registry.systems[i];

                const args = std.meta.ArgsTuple(@TypeOf(system));
                // var paramsToPass: args = undefined;
                comptime var j: usize = 0;
                inline for (std.meta.fields(args), 0..) |arg, k| {
                    // TODO: if not query
                    if (false) {
                        continue;
                    }

                    const queryResult = std.meta.fields(arg.type)[0]; // assumes only one field
                    inline for (std.meta.fields(queryResult.type)) |component| {
                        // paramsToPass[j] = self.world.components[self.registry.getComponentIdx(component.type)];
                        _ = component;
                        _ = k;
                        // paramsToPass[k].result = self.world.components[0].items[0];
                        j += 1;
                    }
                }

                // try @call(.auto, system, .{});

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

    pub fn components(comptime self: *ApplicationBuilder) []type {
        var fields = [_]StructField{};

        for (self.system_types) |system_type| {
            assert(@typeInfo(system_type) != .@"fn");

            const args = std.meta.fields(std.meta.ArgsTuple(system_type));
            const Flags = std.meta.Int(.unsigned, args.len);

            for (args) |arg| {
                // IF QUERY
                if (true) {
                    for (std.meta.fields(@TypeOf(arg)), 0..) |_, i| {
                        fields = fields ++ &[_]StructField{.{
                            .alignment = @sizeOf(Flags),
                            .name = std.fmt.comptimePrint("{d}", .{i}),
                            .default_value = std.math.pow(Flags, 2, i),
                            .is_comptime = true,
                            .type = Flags,
                        }};
                    }
                }
            }
        }
    }
};
