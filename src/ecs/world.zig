const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const uuid = @import("uuid");

const Entity = @import("entity.zig").Entity;

pub const SystemEntry = struct {
    ptr: *anyopaque,
    params: []type,

    fn init(comptime system: anytype) SystemEntry {
        assert(@typeInfo(@TypeOf(system)) == .@"fn");

        switch (@typeInfo(@TypeOf(system))) {
            .@"fn" => |fn_info| {
                const ptr = @as(*anyopaque, @constCast(&system));

                var params: [fn_info.params.len]type = undefined;
                for (fn_info.params, 0..) |param, i| {
                    if (param.type == null) {
                        @compileError("Expected system to have type information for all parameters.");
                    }

                    params[i] = param.type.?;
                }

                return SystemEntry{ .ptr = ptr, .params = &params };
            },
            else => @compileError("Expected system to be a function."),
        }
    }
};

pub fn ApplicationBuilder() type {
    return struct {
        const Self = @This();

        systems: [1024]SystemEntry = undefined,
        systems_registered: usize = 0,

        pub fn init() Self {
            return Self{};
        }

        pub fn build(self: Self) Application {
            const registry = ComponentRegistry(self.systems[0..self.systems_registered]);

            for (std.meta.fields(registry)) |field| {
                @compileLog(field.name, field.type);
            }

            @compileError("Not implemented");
            // return Application.init(std.heap.page_allocator, self.systems[0..self.systems_registered]);
        }

        pub fn registerSystem(self: *Self, system: anytype) void {
            self.systems[self.systems_registered] = SystemEntry.init(system);
            self.systems_registered += 1;
        }
    };
}

fn ComponentRegistry(comptime systems: []const SystemEntry) type {
    var components: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{};

    var prng = std.Random.DefaultPrng.init(0);
    var i = 0;
    for (systems) |system_entry| {
        for (system_entry.params) |param| {
            switch (@typeInfo(param)) {
                .@"struct" => |struct_info| {
                    for (struct_info.fields) |component| {
                        var found = false;
                        for (components) |registered_component| {
                            if (std.meta.eql(component, registered_component)) {
                                found = true;
                                break;
                            }
                        }

                        if (!found) {
                            components = components ++ &[_]std.builtin.Type.StructField{.{
                                .name = @typeName(component.type) ++ std.fmt.comptimePrint("_{d}", .{prng.random().int(u32)}),
                                .type = std.ArrayList(component.type),
                                .default_value = null,
                                .is_comptime = false,
                                .alignment = 64,
                            }};

                            i += 1;
                        }
                    }
                },
                else => {},
            }
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = components,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

pub const Application = struct {
    world: World,
    systems: []SystemEntry,
    component_registry: ComponentRegistry,

    pub fn init(allocator: mem.Allocator, systems: []SystemEntry) Application {
        return Application{
            .world = World.init(allocator),
            .systems = systems,
            .component_registry = ComponentRegistry(systems),
        };
    }
};

pub const World = struct {
    entities: std.ArrayList(Entity),

    pub fn init(allocator: mem.Allocator) World {
        return World{
            .entities = std.ArrayList(Entity).init(allocator),
        };
    }
};
