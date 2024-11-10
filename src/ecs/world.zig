const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const Entity = @import("entity.zig").Entity;

pub const SystemEntry = struct {
    ptr: *anyopaque,
    params: []type,

    pub fn init(comptime system: anytype) SystemEntry {
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

pub const ApplicationBuilder = struct {
    systems: [1024]SystemEntry = undefined,
    systems_registered: usize = 0,

    pub fn init() ApplicationBuilder {
        return .{};
    }

    pub fn build(self: ApplicationBuilder) Application {
        return Application.init(.{ .systems = self.systems[0..self.systems_registered] }, std.heap.page_allocator);
    }

    pub fn registerSystem(self: *ApplicationBuilder, system: anytype) void {
        self.systems[self.systems_registered] = SystemEntry.init(system);
        self.systems_registered += 1;
    }
};

pub fn ComponentRegistry(systems: []const SystemEntry) type {
    var components: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{};

    var prng = std.Random.DefaultPrng.init(69_420);

    for (systems) |system_entry| {
        inline for (system_entry.params) |param| {
            const param_info = @typeInfo(param);
            if (param_info != .@"struct") @compileError("Dickhead");

            const query = param_info.@"struct";

            inline for (query.fields) |component| {
                var found = false;

                for (components) |registered_component| {
                    if (std.meta.eql(component.type, registered_component.type)) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    // @compileLog("Adding component" ++ @typeName(component.type));
                    components = components ++ &[_]std.builtin.Type.StructField{.{
                        .name = @typeName(component.type) ++ std.fmt.comptimePrint("_{d}", .{prng.random().int(u32)}),
                        .type = std.ArrayList(component.type),
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = 64,
                    }};
                }
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

pub fn initComponentRegistry(comptime systems: []const SystemEntry, allocator: mem.Allocator) ComponentRegistry(systems) {
    const Registry = ComponentRegistry(systems);

    var result: Registry = undefined;

    inline for (std.meta.fields(Registry)) |field| {
        @field(result, field.name) = field.type.init(allocator);
    }

    return result;
}

pub const ApplicationConfig = struct {
    systems: []const SystemEntry,
};

pub const Application = struct {
    allocator: mem.Allocator,
    world: World,
    config: ApplicationConfig,
    registry: *anyopaque,

    pub fn init(comptime config: ApplicationConfig, allocator: mem.Allocator) !Application {
        const registry = initComponentRegistry(config.systems, allocator);
        const registry_ptr = try allocator.create(@TypeOf(registry));
        registry_ptr.* = registry;

        return Application{
            .allocator = allocator,
            .world = World.init(allocator),
            .registry = @as(*anyopaque, @constCast(registry_ptr)),
            .config = config,
        };
    }

    pub fn deinit(self: Application) void {
        self.allocator.destroy(self.registry);
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
