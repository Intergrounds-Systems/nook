const std = @import("std");
const stmt = @import("stmt.zig");
const token = @import("token.zig");
const value = @import("value.zig");

/// Represents a sequence of tokens that can be evaluated into a result
pub const Expr = union(enum) {
    binary: Binary,
    call: Call,
    construct: Construct,
    function: Function,
    get: Get,
    grouping: Grouping,
    literal: Literal,
    logical: Logical,
    unary: Unary,
    variable: Variable,

    const Assign = struct {
        name: token.Token,
        value: *Expr,

        /// Return a string representation of the assignment expression
        fn string(self: Assign, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[assign: {s} = {s}]", .{
                self.name.value,
                self.value.string(allocator),
            }) catch "[assign]";
        }
    };

    const Binary = struct {
        left: *Expr,
        operator: token.Token,
        right: *Expr,

        /// Return a string representation of the binary expression
        fn string(self: Binary, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[binary: {s} {s} {s}]", .{
                self.left.string(allocator),
                self.operator.value,
                self.right.string(allocator),
            }) catch "[binary]";
        }
    };

    const Call = struct {
        callee: *Expr,
        paren: token.Token,
        args: []*Expr,

        /// Return a string representation of the call expression
        fn string(self: Call, allocator: std.mem.Allocator) []const u8 {
            var args: []const u8 = "";
            for (self.args, 0..) |arg, i| {
                args = std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
                    args,
                    arg.string(allocator),
                    if (i < self.args.len - 1) ", " else "",
                }) catch args;
            }

            const close: []const u8 = switch (self.paren.token_type) {
                .op_left_angle => ">",
                .op_left_brace => "}",
                .op_left_bracket => "]",
                else => ")",
            };

            return std.fmt.allocPrint(allocator, "[call: {s}{s}{s}{s}]", .{
                self.callee.string(allocator),
                self.paren.value,
                args,
                close,
            }) catch "[call]";
        }
    };

    pub const Construct = struct {
        type_id: token.Token,
        fields: []Field,

        pub const Field = struct {
            // no name means a positional field
            name: ?token.Token,
            value: *Expr,

            /// Return a string representation of the field
            fn string(self: Field, allocator: std.mem.Allocator) []const u8 {
                const prefix: []const u8 = if (self.name) |name|
                    std.fmt.allocPrint(allocator, "{s}: ", .{name.value}) catch ""
                else
                    "";

                return std.fmt.allocPrint(allocator, "{s}{s}", .{
                    prefix,
                    self.value.string(allocator),
                }) catch "[field]";
            }
        };

        /// Return a string representation of the construct expression
        fn string(self: Construct, allocator: std.mem.Allocator) []const u8 {
            var fields: []const u8 = "";
            for (self.fields, 0..) |field, i| {
                fields = std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
                    fields,
                    field.string(allocator),
                    if (i < self.fields.len - 1) ", " else "",
                }) catch fields;
            }

            return std.fmt.allocPrint(allocator, "[construct: {s}{{{s}}}]", .{
                self.type_id.value,
                fields,
            }) catch "[construct]";
        }
    };

    pub const Function = struct {
        params: []Param,
        returns: *stmt.TypeAnnotation,
        body: *stmt.Stmt,

        pub const Param = struct {
            name: token.Token,
            type_annotation: *stmt.TypeAnnotation,

            /// Return a string representation of the function parameter
            fn string(self: Param, allocator: std.mem.Allocator) []const u8 {
                return std.fmt.allocPrint(allocator, "{s}: {s}", .{
                    self.name.value,
                    self.type_annotation.string(allocator),
                }) catch "[param]";
            }
        };

        /// Return a string representation of the function expression
        fn string(self: Function, allocator: std.mem.Allocator) []const u8 {
            var params: []const u8 = "";
            for (self.params, 0..) |param, i| {
                params = std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
                    params,
                    param.string(allocator),
                    if (i < self.params.len - 1) ", " else "",
                }) catch params;
            }

            return std.fmt.allocPrint(allocator, "[func: ({s}) -> {s}: {s}]", .{
                params,
                self.returns.string(allocator),
                self.body.string(allocator),
            }) catch "[func]";
        }
    };

    const Get = struct {
        instance: ?*Expr,
        field: token.Token,

        /// Return a string representation of the get expression
        fn string(self: Get, allocator: std.mem.Allocator) []const u8 {
            const instance = if (self.instance) |inst|
                inst.string(allocator)
            else
                "";

            return std.fmt.allocPrint(allocator, "[get: {s}.{s}]", .{
                instance,
                self.field.value,
            }) catch "[get]";
        }
    };

    const Grouping = struct {
        expression: *Expr,

        /// Return a string representation of the grouping expression
        fn string(self: Grouping, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[grouping: ({s})]", .{
                self.expression.string(allocator),
            }) catch "[grouping]";
        }
    };

    const Literal = struct {
        value: value.Value,

        /// Return a string representation of the literal expression
        fn string(self: Literal, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[literal: {s}]", .{
                self.value.string(allocator),
            }) catch "[literal]";
        }
    };

    const Logical = struct {
        left: *Expr,
        operator: token.Token,
        right: *Expr,

        /// Return a string representation of the logical expression
        fn string(self: Logical, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[logical: {s} {s} {s}]", .{
                self.left.string(allocator),
                self.operator.value,
                self.right.string(allocator),
            }) catch "[logical]";
        }
    };

    const Set = struct {
        instance: *Expr,
        field: token.Token,
        value: *Expr,

        /// Return a string representation of the set expression
        fn string(self: Set, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[set: {s}.{s} -> {s}]", .{
                self.instance.string(allocator),
                self.field.value,
                self.value.string(allocator),
            }) catch "[set]";
        }
    };

    const Unary = struct {
        operator: token.Token,
        operand: *Expr,

        /// Return a string representation of the unary expression
        fn string(self: Unary, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[unary: {s}{s}]", .{
                self.operator.value,
                self.operand.string(allocator),
            }) catch "[unary]";
        }
    };

    const Variable = struct {
        name: token.Token,

        /// Return a string representation of the variable expression
        fn string(self: Variable, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[variable: {s}]", .{
                self.name.value,
            }) catch "[variable]";
        }
    };

    /// Return a string representation of the expression
    pub fn string(self: Expr, allocator: std.mem.Allocator) []const u8 {
        return switch (self) {
            inline else => |inner| inner.string(allocator),
        };
    }
};
