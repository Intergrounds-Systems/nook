const expr = @import("expr.zig");
const std = @import("std");
const token = @import("token.zig");

/// Represents any valid statement in the language
pub const Stmt = union(enum) {
    builtin_drop: *expr.Expr,
    builtin_print: *expr.Expr,
    expression: *expr.Expr,

    assignment: Assignment,
    block: Block,
    conditional: Conditional,
    jump: Jump,
    package: Package,
    symbol: Symbol,

    const Assignment = struct {
        target: *expr.Expr,
        operator: token.Token,
        value: *expr.Expr,

        /// Return a string representation of the assignment statement
        fn string(self: Assignment, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "{s} {s} {s}", .{
                self.target.string(allocator),
                self.operator.value,
                self.value.string(allocator),
            }) catch "[assignment]";
        }
    };

    const Block = struct {
        statements: []*Stmt,

        /// Return a string representation of the block statement
        fn string(self: Block, allocator: std.mem.Allocator) []const u8 {
            var statements: []const u8 = "";
            for (self.statements, 0..) |statement, i| {
                // Indent nested statements
                const rendered = statement.string(allocator);
                const indented = std.mem.replaceOwned(u8, allocator, rendered, "\n", "\n\t") catch rendered;

                statements = std.fmt.allocPrint(allocator, "{s}\t{s}{s}", .{
                    statements,
                    indented,
                    if (i < self.statements.len - 1) "\n" else "",
                }) catch statements;
            }

            return std.fmt.allocPrint(allocator, "[block: {{\n{s}\n}}]", .{
                statements,
            }) catch "[block]";
        }
    };

    const Conditional = struct {
        keyword: token.Token,
        condition: *expr.Expr,
        then_branch: *Stmt,
        else_branch: ?*Stmt,

        /// Return a string representation of the conditional statement
        fn string(self: Conditional, allocator: std.mem.Allocator) []const u8 {
            const otherwise = if (self.else_branch) |branch|
                std.fmt.allocPrint(allocator, " else {s}", .{
                    branch.string(allocator),
                }) catch " [else]"
            else
                "";

            return std.fmt.allocPrint(allocator, "{s} ({s}) {s}{s}", .{
                self.keyword.value,
                self.condition.string(allocator),
                self.then_branch.string(allocator),
                otherwise,
            }) catch "[conditional]";
        }
    };

    const Jump = struct {
        keyword: token.Token,
        value: ?*expr.Expr,

        /// Return a string representation of the jump statement
        fn string(self: Jump, allocator: std.mem.Allocator) []const u8 {
            const value = if (self.value) |value|
                std.fmt.allocPrint(allocator, " ({s})", .{
                    value.string(allocator),
                }) catch "[value]"
            else
                "";

            return std.fmt.allocPrint(allocator, "{s}{s}", .{
                self.keyword.value,
                value,
            }) catch "[jump]";
        }
    };

    const Package = struct {
        identifier: token.Token,

        /// Return a string representation of the package statement
        fn string(self: Package, _: std.mem.Allocator) []const u8 {
            return self.identifier.value;
        }
    };

    const Symbol = struct {
        kind: token.Token,
        identifier: token.Token,
        type_annotation: ?*TypeAnnotation,
        initializer: ?*expr.Expr,

        /// Return a string representation of the symbol statement
        fn string(self: Symbol, allocator: std.mem.Allocator) []const u8 {
            const annotation = if (self.type_annotation) |ta|
                std.fmt.allocPrint(allocator, "{s}", .{ta.string(allocator)}) catch ": ?"
            else
                "(inferred)";

            const suffix = if (self.initializer) |e|
                std.fmt.allocPrint(allocator, " = {s}", .{e.string(allocator)}) catch " = ?"
            else
                "";

            return std.fmt.allocPrint(allocator, "{s} {s}: {s}{s}", .{
                self.kind.value,
                self.identifier.value,
                annotation,
                suffix,
            }) catch "[symbol]";
        }
    };

    /// Return a string representation of the statement tree
    pub fn string(self: Stmt, allocator: std.mem.Allocator) []const u8 {
        const tag = @tagName(self);

        const node = switch (self) {
            inline else => |n| n.string(allocator),
        };

        return std.fmt.allocPrint(allocator, "<{s}> {s}", .{
            tag,
            node,
        }) catch tag;
    }
};

/// Represents a type annotation
pub const TypeAnnotation = union(enum) {
    function: Function,
    named: Named,
    pointer: Pointer,

    const Function = struct {
        params: []*TypeAnnotation,
        returns: *TypeAnnotation,

        fn string(self: Function, allocator: std.mem.Allocator) []const u8 {
            var params: []const u8 = "";
            for (self.params, 0..) |param, i| {
                params = std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
                    params,
                    param.string(allocator),
                    if (i < self.params.len - 1) ", " else "",
                }) catch params;
            }

            return std.fmt.allocPrint(allocator, "func<({s}) -> {s}>", .{
                params,
                self.returns.string(allocator),
            }) catch "func";
        }
    };

    const Named = struct {
        type_id: token.Token,

        fn string(self: Named, _: std.mem.Allocator) []const u8 {
            return self.type_id.value;
        }
    };

    const Pointer = struct {
        kind: token.Token,
        inner: *TypeAnnotation,

        fn string(self: Pointer, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "{s}<{s}>", .{
                self.kind.value,
                self.inner.string(allocator),
            }) catch "T";
        }
    };

    pub fn string(self: TypeAnnotation, allocator: std.mem.Allocator) []const u8 {
        return switch (self) {
            inline else => |inner| inner.string(allocator),
        };
    }
};
