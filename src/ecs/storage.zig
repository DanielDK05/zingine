const std = @import("std");
const assert = std.debug.assert;
const StructField = std.builtin.Type.StructField;

const ApplicationBuilder = @import("application.zig").ApplicationBuilder;

fn Registry(comptime builder: *const ApplicationBuilder) type {
    return struct {
        comptime component_map: ComponentMap(builder) = ComponentMap(builder){},
        systems: SystemRegistry(builder),
        // components: ComponentRegistry(builder),

        fn init(comptime builder_: *const ApplicationBuilder) void {
            const Systems = SystemRegistry(builder_);

            var systems: Systems = undefined;
            inline for (std.meta.fields(Systems), 0..) |field, i| {
                systems[i] = @as(field.type, @constCast(@ptrCast(@alignCast(&builder.systems[i]))));
            }

            // const Components = ComponentRegistry(builder_);

            // var components: Components = undefined;
            // inline for (std.meta.fields(Components), 0..) |field, i| {
            //     components[i] = std.ArrayList(field.type).init(allocator);
            // }

            return .{
                .systems = systems,
                // .components = components,
            };
        }

        fn getComponentIdx(self: *const Registry, comptime Component: type) u32 {
            comptime for (0..std.meta.fields(self.component_map).len) |i| {
                const entry = self.component_map[i];
                if (entry.component == Component) {
                    return entry.key;
                }
            };

            @compileError("Tried to get component index for a component that doesn't exist in the component map.");
        }
    };
}

fn SystemRegistry(comptime builder: *const ApplicationBuilder) type {
    var fields = [_]StructField{};

    for (builder.system_types, 0..) |System, i| {
        fields = fields ++ &[_]StructField{.{
            .alignment = @sizeOf(*anyopaque),
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .default_value = null,
            .is_comptime = false,
            .type = System,
        }};
    }

    return @Type(.{
        .@"struct" = .{
            .decls = &[_]std.builtin.Type.Declaration{},
            .fields = fields,
            .is_tuple = true,
            .layout = .auto,
        },
    });
}

fn ComponentRegistry(comptime builder: *const ApplicationBuilder) type {
    var fields = [_]StructField{};

    for (builder.system_types, 0..) |system_type, i| {
        assert(@typeInfo(system_type) != .@"fn");

        for (std.meta.ArgsTuple(system_type)) |arg| {
            // IF QUERY
            if (true) {
                for (std.meta.fields(@TypeOf(arg))) |component_type| {
                    const ComponentList = std.ArrayList(component_type);

                    fields = fields ++ &[_]StructField{.{
                        .alignment = @sizeOf(ComponentList),
                        .name = std.fmt.comptimePrint("{d}", .{i}),
                        .default_value = null,
                        .is_comptime = false,
                        .type = ComponentList,
                    }};
                }
            }
        }
    }

    return @Type(.{
        .@"struct" = .{
            .decls = &[_]std.builtin.Type.Declaration{},
            .fields = fields,
            .is_tuple = true,
            .layout = .auto,
        },
    });
}

fn ComponentMap(comptime builder: *const ApplicationBuilder) type {
    var fields = [_]StructField{};

    for (builder.system_types, 0..) |System, i| {
        assert(@typeInfo(System) != .@"fn");

        const args = std.meta.fields(std.meta.ArgsTuple(System));

        const Flags = std.meta.Int(.unsigned, args.len);
        const Map = struct {
            key: Flags,
            component: type,
        };

        for (args) |arg| {
            // IF QUERY
            if (true) {
                for (std.meta.fields(@TypeOf(arg))) |Component| {
                    fields = fields ++ &[_]StructField{.{
                        .alignment = @sizeOf(Map),
                        .name = std.fmt.comptimePrint("{d}", .{i}),
                        .default_value = .{
                            .key = std.math.pow(Flags.key, 2, i),
                            .component = Component,
                        },
                        .is_comptime = true,
                        .type = Map,
                    }};
                }
            }
        }
    }

    return @Type(.{
        .@"struct" = .{
            .decls = &[_]std.builtin.Type.Declaration{},
            .fields = fields,
            .is_tuple = true,
            .layout = .auto,
        },
    });
}
