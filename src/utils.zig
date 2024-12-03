const std = @import("std");
const StructField = std.builtin.Type.StructField;
const testing = std.testing;

/// Unpacks a tuple of types into a new tuple with each field being the type
/// of the corresponding field in the input tuple.
pub fn UnpackTupleOfTypes(comptime tuple: anytype) type {
    comptime {
        const typeInfo = @typeInfo(@TypeOf(tuple));
        if (typeInfo != .@"struct" or !typeInfo.@"struct".is_tuple) {
            @compileError("UnpackTypeTuple only works with tuples of types.");
        }

        for (typeInfo.@"struct".fields) |field| {
            if (field.type != type) {
                @compileError("UnpackTypeTuple only works with tuples of types.");
            }
        }
    }

    var fields: []const StructField = &[_]StructField{};
    inline for (std.meta.fields(@TypeOf(tuple)), 0..) |field, i| {
        fields = fields ++ &[_]StructField{.{
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

pub fn TupleOfTypes(comptime tuple: anytype) type {
    var fields: []const StructField = &[_]StructField{};

    inline for (std.meta.fields(@TypeOf(tuple))) |field| {
        fields = fields ++ &[_]StructField{.{
            .alignment = @alignOf(type),
            .name = field.name,
            .default_value = @constCast(&field.type),
            .is_comptime = false,
            .type = type,
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

/// Generates a tuple from a list of types, where each field in the tuple is
/// the type of the corresponding element in the input list.
pub fn TupleOfTypes2(comptime types: []const type) type {
    var fields: []const StructField = &[_]StructField{};
    inline for (types, 0..) |type_, i| {
        fields = fields ++ &[_]StructField{.{
            .alignment = @alignOf(type),
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .default_value = @constCast(&type_),
            .is_comptime = true,
            .type = type,
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

test "TupleOfTypes2" {
    const typesA = [_]type{ u32, f32, bool };
    const typesB = [_]type{ u32, f32, bool, u64 };
    const typesC = [_]type{ f32, u32 };

    const TupleA = TupleOfTypes2(&typesA);
    try testing.expectEqual(@typeInfo(TupleA), @typeInfo(struct { u32, f32, bool }));

    const TupleB = TupleOfTypes2(&typesB);
    try testing.expectEqual(@typeInfo(TupleB), @typeInfo(struct { u32, f32, bool, u64 }));

    const TupleC = TupleOfTypes2(&typesC);
    try testing.expectEqual(@typeInfo(TupleC), @typeInfo(struct { f32, u32 }));
}
