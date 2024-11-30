const std = @import("std");

pub const Param = enum {
    /// A query that selects entities with the specified components.
    query,

    pub fn from(comptime input: type) Param {
        if (!std.meta.hasFn(input, "systemParam")) {
            @compileError("SystemParam.from() requires the input type to have a systemParam() function.");
        }

        const param_type = input.systemParam();

        if (@TypeOf(param_type) != Param) {
            @compileError("SystemParam.from() requires the systemParam() function to return a SystemParam.");
        }

        if (!std.meta.hasFn(input, "Result")) {
            @compileError("SystemParam.from() requires the input type to have a Result() function.");
        }

        const result_type = input.Result();

        if (@TypeOf(result_type) != type) {
            @compileError("SystemParam.from() requires the Result() function to return a type.");
        }

        // TODO: More validation

        return param_type;
    }
};
