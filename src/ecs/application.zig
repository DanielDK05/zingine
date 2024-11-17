const std = @import("std");
const assert = std.debug.assert;
const StructField = std.builtin.Type.StructField;

const storage = @import("storage.zig");

pub const ApplicationBuilder = struct {
    system_ptrs: []const *anyopaque = &[_]*anyopaque{},
    system_types: []type = &[_]type{},

    pub fn addSystem(comptime self: *ApplicationBuilder, comptime system: anytype) void {
        self.system_types = self.system_types ++ &[_]type{*const @TypeOf(system)};
        self.system_ptrs = self.system_ptrs ++ &[_]*anyopaque{@as(*anyopaque, @constCast(@ptrCast(system)))};
    }

    pub fn build(comptime self: ApplicationBuilder) Application(storage.Registry(self)) {
        var Registry = storage.Registry(self.system_fields);

        return Application(Registry).init(
            Registry.init(self),
        );
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

pub fn Application(comptime Registry: type) type {
    return struct {
        registry: Registry,

        pub fn init(registry: Registry) Application {
            return Application{
                .registry = registry,
            };
        }
    };
}
