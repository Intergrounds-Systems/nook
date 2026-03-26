const std = @import("std");
const token = @import("token.zig");
const value = @import("value.zig");

/// Represents a sequence of tokens that can be evaluated into a result
pub const Expr = union(enum) {
    assign: Assign,
    binary: Binary,
    call: Call,
    get: Get,
    grouping: Grouping,
    literal: Literal,
    logical: Logical,
    set: Set,
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

    const Get = struct {
        instance: *Expr,
        field: token.Token,

        /// Return a string representation of the get expression
        fn string(self: Get, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[get: {s}.{s}]", .{
                self.instance.string(allocator),
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
