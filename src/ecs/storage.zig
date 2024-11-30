const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const StructField = std.builtin.Type.StructField;

const ApplicationBuilder = @import("application.zig").ApplicationBuilder;
const utils = @import("../utils.zig");

pub fn Registry(comptime builder: *const ApplicationBuilder) type {
    const Components = ComponentMap(builder);
    const Systems = SystemRegistry(builder);

    return struct {
        const Self = @This();

        comptime components: Components = Components{},
        comptime systems: Systems = Systems{},

        pub fn init() Self {
            return Self{};
        }
    };
}

pub fn SystemRegistry(comptime builder: *const ApplicationBuilder) type {
    var fields: []const StructField = &[_]StructField{};

    inline for (builder.system_types, 0..) |system, i| {
        const System = ValidateAndExtractSystemPtr(system);
        fields = fields ++ &[_]StructField{.{
            .alignment = @alignOf(System),
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .default_value = builder.system_ptrs[i],
            .is_comptime = true,
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

pub fn ComponentMap(comptime builder: *const ApplicationBuilder) type {
    var fields: []const StructField = &[_]StructField{};

    for (builder.system_types, 0..) |system, i| {
        const System = ValidateAndExtractSystemPtr(system);
        const args = std.meta.fields(std.meta.ArgsTuple(System));

        const Flags = std.meta.Int(.unsigned, 3);
        const Entry = struct {
            key: Flags,
            component: type,
        };

        for (args) |arg| {
            // TODO: if query
            if (true) {
                for (std.meta.fields(@TypeOf(arg))) |field| {
                    fields = fields ++ &[_]StructField{.{
                        .alignment = @sizeOf(Entry),
                        .name = std.fmt.comptimePrint("{d}", .{fields.len}),
                        .default_value = @constCast(&Entry{
                            .key = std.math.pow(Flags, 2, i),
                            .component = field.type,
                        }),
                        .is_comptime = true,
                        .type = Entry,
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

pub fn ComponentStorage(comptime builder: *const ApplicationBuilder) type {
    var fields: []const StructField = &[_]StructField{};

    for (builder.system_types) |system_type| {
        const System = ValidateAndExtractSystemPtr(system_type);

        const args = std.meta.ArgsTuple(System);
        for (std.meta.fields(args)) |arg| {
            // TODO: if query
            if (true) {
                for (std.meta.fields(arg.type)) |component| {
                    const ComponentList = std.ArrayList(component.type);

                    fields = fields ++ &[_]StructField{.{
                        .alignment = @alignOf(ComponentList),
                        .name = std.fmt.comptimePrint("{d}", .{fields.len}),
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

fn ValidateAndExtractSystemPtr(system: type) type {
    const type_info = @typeInfo(system);
    comptime assert(type_info == .pointer);

    const system_info = @typeInfo(type_info.pointer.child);
    comptime assert(system_info == .@"fn");

    return @Type(system_info);
}
