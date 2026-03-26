const expr = @import("expr.zig");
const std = @import("std");
const token = @import("token.zig");

/// Represents any valid statement in the language
pub const Stmt = union(enum) {
    builtin_clone: *expr.Expr,
    builtin_copy: *expr.Expr,
    builtin_drop: *expr.Expr,
    builtin_new: *expr.Expr,
    builtin_print: *expr.Expr,

    expression: *expr.Expr,

    package: Package,
    variable: Variable,

    const Package = struct {
        identifier: token.Token,

        /// Return a string representation of the package statement
        fn string(self: Package) []const u8 {
            return self.identifier.value;
        }
    };

    const Variable = struct {
        identifier: token.Token,
        type_annotation: ?TypeAnnotation,
        initializer: ?*expr.Expr,

        /// Return a string representation of the variable statement
        fn string(self: Variable, allocator: std.mem.Allocator) []const u8 {
            const annotation = if (self.type_annotation) |ta|
                std.fmt.allocPrint(allocator, "{s}", .{ta.string(allocator)}) catch ": ?"
            else
                "(inferred)";

            const suffix = if (self.initializer) |e|
                std.fmt.allocPrint(allocator, " = {s}", .{e.string(allocator)}) catch " = ?"
            else
                "";

            return std.fmt.allocPrint(allocator, "{s}: {s}{s}", .{
                self.identifier.value,
                annotation,
                suffix,
            }) catch "[variable]";
        }
    };

    /// Return a string representation of the statement tree
    pub fn string(self: Stmt, allocator: std.mem.Allocator) []const u8 {
        const tag = @tagName(self);

        const node = switch (self) {
            // Statements that just contain an expression
            .builtin_clone,
            .builtin_copy,
            .builtin_drop,
            .builtin_new,
            .builtin_print,
            .expression,
            => |e| e.string(allocator),

            // Package statement
            .package => |p| p.string(),

            // Variable statement
            .variable => |v| v.string(allocator),
        };

        return std.fmt.allocPrint(allocator, "<{s}> {s}", .{
            tag,
            node,
        }) catch tag;
    }
};

/// Represents a type annotation
pub const TypeAnnotation = struct {
    type_id: token.Token,
    ptr_type: ?token.Token,

    fn string(self: TypeAnnotation, allocator: std.mem.Allocator) []const u8 {
        var prefix: []const u8 = "";
        var left_angle: []const u8 = "";
        var right_angle: []const u8 = "";

        if (self.ptr_type) |pt| {
            prefix = pt.value;
            left_angle = "<";
            right_angle = ">";
        }

        return std.fmt.allocPrint(allocator, "{s}{s}{s}{s}", .{
            prefix,
            left_angle,
            self.type_id.value,
            right_angle,
        }) catch "T";
    }
};
