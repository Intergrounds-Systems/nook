const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const value = @import("value.zig");

/// Parse tokens into an list of statement trees
pub fn parse(allocator: std.mem.Allocator, tokens: []tokenizer.Token) !std.ArrayList(Stmt) {
    var parser: Parser = .{ .tokens = tokens };
    return parser.parse();
}

/// Represents any valid statement in the language
pub const Stmt = union(enum) {
    variable: Variable,
    expression: *Expr,

    const Variable = struct {
        identifier: tokenizer.Token,
        initializer: ?*Expr,
    };
};

/// Represents a sequence of tokens that can be evaluated into a result
pub const Expr = union(enum){
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
        name: tokenizer.Token,
        value: *Expr,
    };

    const Binary = struct {
        left: *Expr,
        operator: tokenizer.Token,
        right: *Expr,
    };

    const Call = struct {
        callee: *Expr,
        paren: tokenizer.Token,
        args: []*Expr,
    };

    const Get = struct {
        instance: *Expr,
        field: tokenizer.Token,
    };

    const Grouping = struct {
        expression: *Expr,
    };

    const Literal = struct {
        value: value.Value,
    };

    const Logical = struct {
        left: *Expr,
        operator: tokenizer.Token,
        right: *Expr,
    };

    const Set = struct {
        instance: *Expr,
        field: tokenizer.Token,
        value: *Expr,
    };

    const Unary = struct {
        operator: tokenizer.Token,
        operand: *Expr,
    };

    const Variable = struct {
        name: tokenizer.Token,
    };
};

/// The parser
const Parser = struct {
    tokens: []tokenizer.Token,
    pos: usize = 0,

    /// Parse the input token stream into a list of statements
    fn parse(self: *Parser) std.ArrayList(Stmt) {
        var stmts: std.ArrayList(Stmt) = .empty;

        return stmts;
    }
};

