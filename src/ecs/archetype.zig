const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const StructField = std.builtin.Type.StructField;

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
    const input_type = @TypeOf(components);

    if (@typeInfo(input_type) != .@"struct" or !@typeInfo(input_type).@"struct".is_tuple) {
        @compileError("Must pass in a tuple");
    }

    return std.meta.Int(.unsigned, std.meta.fields(@TypeOf(components)).len);
}

pub fn ComponentsFromFlags(comptime fullComponentSet: anytype, comptime flags: ComponentFlags(fullComponentSet)) type {
    var result: []const StructField = &[_]StructField{};

    const fields = std.meta.fields(@TypeOf(fullComponentSet));
    for (fields, 0..) |field, i| {
        if (flags & std.math.pow(ComponentFlags(fullComponentSet), 2, fields.len - i - 1) != 0) {
            result = result ++ &[_]StructField{
                .{
                    .name = std.fmt.comptimePrint("{d}", .{result.len}),
                    .type = type,
                    .alignment = field.alignment,
                    .is_comptime = true,
                    .default_value = @constCast(&fullComponentSet[i]),
                },
            };
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = result,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = true,
        },
    });
}

pub fn Archetype(comptime fullComponentSet: anytype, comptime componentSubset: anytype) type {
    const Composition = utils.UnpackTupleOfTypes(componentSubset);
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
    const ArchetypeFlags = ComponentFlags(fullComponentSet);

    return struct {
        const Self = @This();

        comptime fullSet: @TypeOf(fullComponentSet) = fullComponentSet,
        allocator: mem.Allocator,
        archetypes: std.AutoHashMap(ArchetypeFlags, *const anyopaque),

        pub fn init(allocator: mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .archetypes = std.AutoHashMap(ArchetypeFlags, *const anyopaque).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            // PERF TODO: don't loop every permutation.
            inline for (0..std.math.maxInt(ArchetypeFlags)) |i| {
                const flags: ArchetypeFlags = comptime @intCast(i);
                const archetype_ptr = self.get(flags);
                if (archetype_ptr) |archetype| {
                    archetype.deinit();
                    self.allocator.destroy(archetype);
                }
            }

            self.archetypes.deinit();
        }

        pub fn put(self: *Self, comptime componentSubset: anytype) mem.Allocator.Error!void {
            const Entry = Archetype(fullComponentSet, componentSubset);
            const archetype = try self.allocator.create(Entry);
            archetype.* = Entry.init(self.allocator);

            const archetype_ptr: *const anyopaque = @constCast(archetype);

            try self.archetypes.put(archetype.id, archetype_ptr);
            return self.archetypes.put(archetype.id, archetype_ptr).?;
        }

        pub fn get(self: *Self, comptime flags: ArchetypeFlags) ?*Archetype(fullComponentSet, ComponentsFromFlags(fullComponentSet, flags){}) {
            const archetype_ptr = self.archetypes.get(flags) orelse return null;

            const Entry = Archetype(fullComponentSet, ComponentsFromFlags(fullComponentSet, flags){});
            return @as(*Entry, @alignCast(@ptrCast(@constCast(archetype_ptr))));
        }

        pub fn getOrPut(self: *Self, comptime flags: ArchetypeFlags, comptime componentSubset: anytype) mem.Allocator.Error!*Archetype(fullComponentSet, componentSubset) {
            if (self.get(flags)) |archetype| {
                return archetype;
            }

            return try self.put(componentSubset);
        }

        pub fn Flags() type {
            return ArchetypeFlags;
        }
    };
}

test "ArchetypeStore" {
    const A = struct { a: u32 };
    const B = struct { b: u32 };
    const C = struct { c: u32 };
    const D = struct { d: u32 };
    const E = struct { e: u32 };

    const FullSet = .{ A, B, C, D, E };

    var store = ArchetypeStore(FullSet).init(testing.allocator);
    defer store.deinit();

    try store.put(.{ A, B, C });
    try store.put(.{ A, C, E });
    try store.put(.{ B, D });

    const archetype1 = store.get(0b11100).?;
    const archetype2 = store.get(0b10101).?;
    const archetype3 = store.get(0b01010).?;

    try testing.expectEqual(0b11100, archetype1.id);
    try testing.expectEqual(0b10101, archetype2.id);
    try testing.expectEqual(0b01010, archetype3.id);

    try archetype1.append(.{ A{ .a = 0 }, B{ .b = 1 }, C{ .c = 2 } });
    try archetype1.append(.{ A{ .a = 1 }, B{ .b = 2 }, C{ .c = 3 } });
    try testing.expectEqual(2, archetype1.entries.items.len);
    try testing.expectEqual(.{ A{ .a = 0 }, B{ .b = 1 }, C{ .c = 2 } }, archetype1.entries.items[0]);
    try testing.expectEqual(.{ A{ .a = 1 }, B{ .b = 2 }, C{ .c = 3 } }, archetype1.entries.items[1]);

    try archetype2.append(.{ A{ .a = 2 }, C{ .c = 3 }, E{ .e = 4 } });
    try testing.expectEqual(1, archetype2.entries.items.len);
    try testing.expectEqual(.{ A{ .a = 2 }, C{ .c = 3 }, E{ .e = 4 } }, archetype2.entries.items[0]);

    try archetype3.append(.{ B{ .b = 3 }, D{ .d = 4 } });
    try archetype3.append(.{ B{ .b = 4 }, D{ .d = 5 } });
    try archetype3.append(.{ B{ .b = 5 }, D{ .d = 6 } });
    try testing.expectEqual(3, archetype3.entries.items.len);
    try testing.expectEqual(.{ B{ .b = 3 }, D{ .d = 4 } }, archetype3.entries.items[0]);
    try testing.expectEqual(.{ B{ .b = 4 }, D{ .d = 5 } }, archetype3.entries.items[1]);
    try testing.expectEqual(.{ B{ .b = 5 }, D{ .d = 6 } }, archetype3.entries.items[2]);
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

test "Inverse ComponentFlags" {
    const A = struct {};
    const B = struct {};
    const C = struct {};
    const D = struct {};
    const E = struct {};
    const FullSet = .{ A, B, C, D, E };

    try testing.expectEqual(.{ A, B, C, D, E }, ComponentsFromFlags(FullSet, 0b11111){});
    try testing.expectEqual(.{ A, B, C, D }, ComponentsFromFlags(FullSet, 0b11110){});
    try testing.expectEqual(.{ A, B, C }, ComponentsFromFlags(FullSet, 0b11100){});
    try testing.expectEqual(.{ A, B }, ComponentsFromFlags(FullSet, 0b11000){});
    try testing.expectEqual(.{A}, ComponentsFromFlags(FullSet, 0b10000){});
    try testing.expectEqual(.{}, ComponentsFromFlags(FullSet, 0b00000){});

    try testing.expectEqual(.{ A, C, D }, ComponentsFromFlags(FullSet, 0b10110){});
    try testing.expectEqual(.{ B, D, E }, ComponentsFromFlags(FullSet, 0b01011){});
    try testing.expectEqual(.{ C, E }, ComponentsFromFlags(FullSet, 0b00101){});
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
