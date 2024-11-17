const std = @import("std");
const assert = std.debug.assert;

const ParseResult = struct {
    result: []const type,
    whitelist: []const type,
    blacklist: []const type,
    limit: ?u32,
};

pub const ParseError = error{
    must_start_with_select,
    identifier_after_limit,
    identifier_after_and,
    identifier_after_or,
    multiple_limits,
    multiple_selects,
    with_after_select,
    without_after_select,
};

pub fn fmtError(err: ParseError) []const u8 {
    return switch (err) {
        ParseError.must_start_with_select => "Query must start with SELECT",
        ParseError.identifier_after_limit => "Identifier after LIMIT",
        ParseError.identifier_after_and => "Identifier after AND",
        ParseError.identifier_after_or => "Identifier after OR",
        ParseError.multiple_limits => "Multiple LIMIT's are not allowed",
        ParseError.multiple_selects => "Multiple SELECT's are not allowed",
        ParseError.with_after_select => "WITH after SELECT is not allowed",
        ParseError.without_after_select => "WITHOUT after SELECT is not allowed",
    };
}

// TODO: Implement AND OR
pub fn parse(tokens: []const Token) ParseError!ParseResult {
    if (tokens[0] != .select) {
        return ParseError.must_start_with_select;
    }

    var result: []const type = &[_]type{};
    var whitelist: []const type = &[_]type{};
    var blacklist: []const type = &[_]type{};
    var limit: ?u32 = null;

    var current_keyword: Token = .select;
    var last_token: Token = .select;

    for (tokens[1..]) |token| {
        defer last_token = token;

        assert(current_keyword != .identifier);

        if (token != .identifier) {
            current_keyword = token;
        }

        if (last_token == .select) {
            switch (token) {
                .with => return ParseError.with_after_select,
                .without => return ParseError.without_after_select,
                else => {},
            }
        }

        switch (token) {
            .identifier => |identifier| {
                switch (current_keyword) {
                    .limit => return ParseError.identifier_after_limit,
                    .@"and" => return ParseError.identifier_after_and,
                    .@"or" => return ParseError.identifier_after_or,

                    .select => result = result ++ &[_]type{identifier},
                    .with => whitelist = whitelist ++ &[_]type{identifier},
                    .without => blacklist = blacklist ++ &[_]type{identifier},
                    else => unreachable,
                }
            },
            .limit => |limit_| {
                if (limit != null) {
                    return ParseError.multiple_limits;
                }

                limit = limit_;
            },
            .select => {
                return ParseError.multiple_selects;
            },
            .with => current_keyword = .with,
            .without => current_keyword = .without,
            .@"and" => unreachable,
            .@"or" => unreachable,
        }
    }

    return ParseResult{
        .result = result,
        .whitelist = whitelist,
        .blacklist = blacklist,
        .limit = limit,
    };
}

pub const Token = union(enum) {
    identifier: type,
    limit: comptime_int,
    select,
    @"and",
    @"or",
    with,
    without,
};

const testing = std.testing;

const TestUtils = struct {
    const Health = struct {
        health: u32,
    };

    const Player = struct {
        id: u32,
    };

    const Sword = struct {
        damage: u32,
    };

    const Enemy = struct {
        id: u32,
    };
};

test "[parser.zig] simple parse" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .identifier = TestUtils.Player },
    };

    const result = try parse(tokens);

    try testing.expect(std.meta.eql(
        result,
        ParseResult{
            .result = &[_]type{TestUtils.Player},
            .whitelist = &[_]type{},
            .blacklist = &[_]type{},
            .limit = null,
        },
    ));
}

test "[parser.zig] with" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .identifier = TestUtils.Player },
        .{ .identifier = TestUtils.Sword },
        .{ .with = {} },
        .{ .identifier = TestUtils.Health },
    };

    const result = try parse(tokens);

    try testing.expect(std.meta.eql(
        result,
        ParseResult{
            .result = &[_]type{ TestUtils.Player, TestUtils.Sword },
            .whitelist = &[_]type{TestUtils.Health},
            .blacklist = &[_]type{},
            .limit = null,
        },
    ));
}

test "[parser.zig] without" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .identifier = TestUtils.Player },
        .{ .identifier = TestUtils.Sword },
        .{ .without = {} },
        .{ .identifier = TestUtils.Enemy },
    };

    const result = try parse(tokens);

    try testing.expect(std.meta.eql(
        result,
        ParseResult{
            .result = &[_]type{ TestUtils.Player, TestUtils.Sword },
            .whitelist = &[_]type{},
            .blacklist = &[_]type{TestUtils.Enemy},
            .limit = null,
        },
    ));
}

test "[parser.zig] with/without" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .identifier = TestUtils.Player },
        .{ .identifier = TestUtils.Sword },
        .{ .with = {} },
        .{ .identifier = TestUtils.Health },
        .{ .without = {} },
        .{ .identifier = TestUtils.Enemy },
    };

    const result = try parse(tokens);

    try testing.expect(std.meta.eql(
        result,
        ParseResult{
            .result = &[_]type{ TestUtils.Player, TestUtils.Sword },
            .whitelist = &[_]type{TestUtils.Health},
            .blacklist = &[_]type{TestUtils.Enemy},
            .limit = null,
        },
    ));
}

test "[parser.zig] fail multiple selects" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .identifier = TestUtils.Player },
        .{ .identifier = TestUtils.Sword },
        .{ .select = {} },
    };

    const result = parse(tokens);
    try testing.expectError(error.multiple_selects, result);
}

test "[parser.zig] fail multiple limits" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .identifier = TestUtils.Player },
        .{ .identifier = TestUtils.Sword },
        .{ .limit = 1 },
        .{ .limit = 2 },
    };

    const result = parse(tokens);
    try testing.expectError(error.multiple_limits, result);
}

test "[parser.zig] fail on with after select" {
    const tokens: []const Token = &[_]Token{
        .{ .select = {} },
        .{ .with = {} },
        .{ .identifier = TestUtils.Player },
        .{ .identifier = TestUtils.Sword },
    };

    const result = parse(tokens);
    try testing.expectError(error.with_after_select, result);
}
