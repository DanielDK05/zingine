const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const utils = @import("../utils.zig");

/// Generates the flags for the given components. This can be used as an identitifer
/// for the archetype.
///
/// # Parameters
/// - `fullComponentSet`: The full set of components that can be used to generate the flags. Type passed in should be a tuple
/// - `components`: The set of components that the flags should be generated. Type passed in should be a tuple
pub fn getFlags(comptime fullComponentSet: anytype, comptime components: anytype) ComponentFlags(fullComponentSet) {
    comptime {
        var flags: ComponentFlags(fullComponentSet) = 0;

        for (std.meta.fields(@TypeOf(components)), 0..) |_, i| {
            flags |= getFlag(fullComponentSet, components[i]);
        }

        return flags;
    }
}

pub fn getFlag(comptime fullComponentSet: anytype, comptime component: anytype) ComponentFlags(fullComponentSet) {
    comptime {
        const fields = std.meta.fields(@TypeOf(fullComponentSet));

        for (0..fields.len) |i| {
            if (fullComponentSet[i] == component) {
                return std.math.pow(ComponentFlags(fullComponentSet), 2, fields.len - i - 1);
            }
        }

        // TODO: better compile error
        @compileError("Component not found in full component set");
    }
}

/// Returns an unsigned int type that can hold the flags for the given components.
pub fn ComponentFlags(comptime components: anytype) type {
    return std.meta.Int(.unsigned, std.meta.fields(@TypeOf(components)).len);
}

pub fn Archetype(comptime fullComponentSet: anytype, comptime componentSubset: anytype) type {
    const Composition = utils.UnpackTypeTuple(componentSubset);
    const id = getFlags(fullComponentSet, componentSubset);

    return struct {
        const Self = @This();

        comptime id: ComponentFlags(fullComponentSet) = id,
        entries: std.ArrayList(Composition),

        pub fn init(allocator: mem.Allocator) Self {
            return Self{
                .entries = std.ArrayList(Composition).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entries.deinit();
        }

        pub fn append(self: *Self, entry: Composition) !void {
            try self.entries.append(entry);
        }
    };
}

pub fn ArchetypeStore(comptime fullComponentSet: anytype) type {
    return struct {
        const Self = @This();

        comptime fullSet: @TypeOf(fullComponentSet) = fullComponentSet,
        allocator: mem.Allocator,
        archetypes: std.AutoHashMap(ComponentFlags(fullComponentSet), *anyopaque),

        pub fn init(allocator: mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .archetypes = std.AutoHashMap(ComponentFlags(fullComponentSet), *anyopaque).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.archetypes.deinit();
        }

        pub fn addArchetype(self: *Self, comptime componentSubset: anytype) !void {
            const archetype = Archetype(fullComponentSet, componentSubset).init(self.allocator);
            try self.archetypes.put(archetype.id, @as(*anyopaque, @constCast(&archetype)));
        }
    };
}

test "basic archetype test" {
    const A = struct {};
    const B = struct {};
    const C = struct {};
    const D = struct {};
    const E = struct {};

    const FullSet = .{ A, B, C, D, E };

    const ArchetypeACE = Archetype(FullSet, .{ A, C, E });
    const ArchetypeBD = Archetype(FullSet, .{ B, D });

    try testing.expect(ArchetypeACE != ArchetypeBD);

    var archetypeACE = ArchetypeACE.init(testing.allocator);
    defer archetypeACE.deinit();

    var archetypeBD = ArchetypeBD.init(testing.allocator);
    defer archetypeBD.deinit();

    try testing.expectEqual(0b00000, archetypeACE.id & archetypeBD.id);
    try testing.expectEqual(0b11111, archetypeACE.id | archetypeBD.id);
    try testing.expectEqual(0b10101, archetypeACE.id);
    try testing.expectEqual(0b01010, archetypeBD.id);

    try archetypeACE.append(.{ A{}, C{}, E{} });
    try archetypeACE.append(.{ A{}, C{}, E{} });
    try testing.expectEqual(2, archetypeACE.entries.items.len);

    try archetypeBD.append(.{ B{}, D{} });
    try testing.expectEqual(1, archetypeBD.entries.items.len);
}

test "ComponentFlags" {
    const A = struct {};
    const B = struct {};
    const C = struct {};
    const D = struct {};
    const E = struct {};

    try testing.expectEqual(u5, ComponentFlags(.{ A, B, C, D, E }));
    try testing.expectEqual(u3, ComponentFlags(.{ A, B, C }));
    try testing.expectEqual(u2, ComponentFlags(.{ A, B }));
    try testing.expectEqual(u2, ComponentFlags(.{ A, C }));
}

test "getFlag" {
    const A = struct {};
    const B = struct {};
    const C = struct {};
    const D = struct {};
    const E = struct {};

    try testing.expectEqual(0b10000, comptime getFlag(.{ A, B, C, D, E }, A));
    try testing.expectEqual(0b01000, comptime getFlag(.{ A, B, C, D, E }, B));
    try testing.expectEqual(0b00100, comptime getFlag(.{ A, B, C, D, E }, C));
    try testing.expectEqual(0b00010, comptime getFlag(.{ A, B, C, D, E }, D));
    try testing.expectEqual(0b00001, comptime getFlag(.{ A, B, C, D, E }, E));
    try testing.expectEqual(0b11000, comptime getFlags(.{ A, B, C, D, E }, .{ A, B }));
    try testing.expectEqual(0b10100, comptime getFlags(.{ A, B, C, D, E }, .{ A, C }));
    try testing.expectEqual(0b10010, comptime getFlags(.{ A, B, C, D, E }, .{ A, D }));
    try testing.expectEqual(0b10001, comptime getFlags(.{ A, B, C, D, E }, .{ A, E }));
    try testing.expectEqual(0b11100, comptime getFlags(.{ A, B, C, D, E }, .{ A, B, C }));
    try testing.expectEqual(0b11010, comptime getFlags(.{ A, B, C, D, E }, .{ A, B, D }));
    try testing.expectEqual(0b11001, comptime getFlags(.{ A, B, C, D, E }, .{ A, B, E }));
    try testing.expectEqual(0b11110, comptime getFlags(.{ A, B, C, D, E }, .{ A, B, C, D }));
    try testing.expectEqual(0b11101, comptime getFlags(.{ A, B, C, D, E }, .{ A, B, C, E }));
    try testing.expectEqual(0b11111, comptime getFlags(.{ A, B, C, D, E }, .{ A, B, C, D, E }));
}
