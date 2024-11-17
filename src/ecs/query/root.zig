const std = @import("std");
const StructField = std.builtin.Type.StructField;

const parser = @import("parser.zig");

fn systemContainsQuery(comptime system: anytype) bool {
    const type_info = @typeInfo(@TypeOf(system));
    if (type_info != .pointer) {
        @compileError("System must be a function pointer");
    }

    const ptr_child_info = @typeInfo(type_info.pointer.child);
    if (ptr_child_info != .@"fn") {
        @compileError("System must be a function pointer");
    }

    // const fn_info = ptr_child_info.@"fn";
    // inline for (fn_info.params) |param| {}

    const fields = std.meta.fields(@TypeOf(system));

    var found = false;

    inline for (fields, 0..) |_, i| {
        const field = system[i];

        if (field == Query) {
            found = true;
        }
    }

    return found;
}

pub fn Query(comptime query: anytype) type {
    // Type check
    {
        const type_info = @typeInfo(@TypeOf(query));
        if (type_info != .@"struct") {
            @compileError("Kill yourself");
        }
        const struct_info = type_info.@"struct";

        if (!struct_info.is_tuple) {
            @compileError("I want you to thoroughly fuck yourself");
        }
    }

    const parse_result = blk: {
        const fields = std.meta.fields(@TypeOf(query));

        var tokens: []const parser.Token = &[_]parser.Token{};

        inline for (fields, 0..) |_, i| {
            const field = query[i];

            if (Keywords.isKeyword(field)) {
                tokens = tokens ++ &[_]parser.Token{
                    Keywords.parseTheParserTokenForParsingTokens(field),
                };

                continue;
            }

            tokens = tokens ++ &[_]parser.Token{.{ .identifier = field }};
        }

        break :blk parser.parse(tokens) catch |err| @compileError(parser.fmtError(err));
    };

    const Result = blk: {
        const struct_fields: []StructField = &[_]StructField{};

        inline for (parse_result.result, 0..) |field_type, i| {
            struct_fields = struct_fields ++ &[_]StructField{.{
                .alignment = @sizeOf(field_type),
                .name = std.fmt.comptimePrint("{d}", .{i}),
                .default_value = null,
                .is_comptime = false,
                .type = field_type,
            }};
        }

        break :blk @Type(.{
            .@"struct" = .{
                .decls = &[_]std.builtin.Type.Declaration{},
                .fields = struct_fields,
                .is_tuple = true,
                .layout = .auto,
            },
        });
    };

    return struct {
        result: Result,
    };
}

pub const Keywords = struct {
    pub const AND = struct {};
    pub const OR = struct {};
    pub const WITH = struct {};
    pub const WITHOUT = struct {};
    pub const SELECT = struct {};

    fn parseTheParserTokenForParsingTokens(keyword: type) parser.Token {
        if (!isKeyword(keyword)) {
            @compileError("Invalid type passed into Keywords.parserToken()");
        }

        return switch (keyword) {
            SELECT => .{ .select = {} },
            WITH => .{ .with = {} },
            WITHOUT => .{ .without = {} },
            AND => .{ .@"and" = {} },
            OR => .{ .@"or" = {} },
            else => unreachable,
        };
    }

    fn isKeyword(comptime input: type) bool {
        return switch (input) {
            Keywords.AND => true,
            Keywords.OR => true,
            Keywords.WITH => true,
            Keywords.WITHOUT => true,
            Keywords.SELECT => true,
            else => false,
        };
    }
};
