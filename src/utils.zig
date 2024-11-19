const std = @import("std");

/// Replaces any non-optional fields in the passed in tuple with optional fields.
pub fn TupleWithOptionalFields(comptime Tuple: type) type {
    const StructField = std.builtin.Type.StructField;

    if (@typeInfo(Tuple) != .@"struct" or !@typeInfo(Tuple).@"struct".is_tuple) {
        @compileError("TupleWithOptionalFields only works with tuples.");
    }

    var fields: []const StructField = &[_]StructField{};

    inline for (std.meta.fields(Tuple)) |component| {
        const NewType = if (@typeInfo(component.type) == .optional) component.type else ?component.type;

        fields = fields ++ &[_]StructField{.{
            .alignment = @alignOf(NewType),
            .name = std.fmt.comptimePrint("{s}", .{component.name}),
            .default_value = null,
            .is_comptime = false,
            .type = NewType,
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

/// Unpacks a tuple of types into a new tuple with each field being the type
/// of the corresponding field in the input tuple.
pub fn UnpackTypeTuple(comptime tuple: anytype) type {
    // TODO: validate tuple

    var fields: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{};
    inline for (std.meta.fields(@TypeOf(tuple)), 0..) |field, i| {
        fields = fields ++ &[_]std.builtin.Type.StructField{.{
            .alignment = @alignOf(tuple[i]),
            .name = field.name,
            .default_value = null,
            .is_comptime = false,
            .type = tuple[i],
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
