const log = @import("log");
const std = @import("std");
const tokenizer = @import("tokenizer.zig");

/// Errors that can arise during parsing
pub const ParserError = error{
    UnexpectedToken,
    ExpectedExpression,
    InvalidDataType,
    ParseFailed,
};

/// Represents any valid statement in the language
pub const Stmt = union(enum) {
    builtin_clone: *Expr,
    builtin_copy: *Expr,
    builtin_drop: *Expr,
    builtin_new: *Expr,
    builtin_print: *Expr,
    expression: *Expr,
    variable: Variable,

    const Variable = struct {
        identifier: tokenizer.Token,
        type_annotation: ?TypeAnnotation,
        initializer: ?*Expr,

        /// Return a string representation of the variable statement
        fn string(self: Variable, allocator: std.mem.Allocator) []const u8 {
            const annotation = if (self.type_annotation) |ta|
                std.fmt.allocPrint(allocator, "{s}", .{ta.string(allocator)}) catch ": ?"
            else
                "(inferred)";

            const suffix = if (self.initializer) |expr|
                std.fmt.allocPrint(allocator, " = {s}", .{expr.string(allocator)}) catch " = ?"
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
            .builtin_clone, .builtin_copy, .builtin_drop, .builtin_new, .builtin_print, .expression => |expr| expr.string(allocator),

            // Variable statement
            .variable => |variable| variable.string(allocator),
        };

        return std.fmt.allocPrint(allocator, "<{s}> {s}", .{
            tag,
            node,
        }) catch tag;
    }
};

/// Represents a type annotation
pub const TypeAnnotation = struct {
    type_id: tokenizer.Token,
    ptr_type: ?tokenizer.Token,

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
        name: tokenizer.Token,
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
        operator: tokenizer.Token,
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
        paren: tokenizer.Token,
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
        field: tokenizer.Token,

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
        value: Value,

        /// Return a string representation of the literal expression
        fn string(self: Literal, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[literal: {s}]", .{
                self.value.string(allocator),
            }) catch "[literal]";
        }
    };

    const Logical = struct {
        left: *Expr,
        operator: tokenizer.Token,
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
        field: tokenizer.Token,
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
        operator: tokenizer.Token,
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
        name: tokenizer.Token,

        /// Return a string representation of the variable expression
        fn string(self: Variable, allocator: std.mem.Allocator) []const u8 {
            return std.fmt.allocPrint(allocator, "[variable: {s}]", .{
                self.name.value,
            }) catch "[variable]";
        }
    };

    /// Return a string representation of the expression
    fn string(self: Expr, allocator: std.mem.Allocator) []const u8 {
        return switch (self) {
            inline else => |inner| inner.string(allocator),
        };
    }
};

pub const Value = union(enum) {
    val_bool: bool,
    val_int: i64,
    val_float: f64,
    val_char: u8,
    val_str: []const u8,
    val_void: void,

    /// Return a string representation of the value
    fn string(self: Value, allocator: std.mem.Allocator) []const u8 {
        const value: []const u8 = switch (self) {
            .val_bool => |b| std.fmt.allocPrint(allocator, "{any}", .{b}) catch "bool",
            .val_int => |i| std.fmt.allocPrint(allocator, "{d}", .{i}) catch "int",
            .val_float => |f| std.fmt.allocPrint(allocator, "{d}", .{f}) catch "float",
            .val_char => |c| std.fmt.allocPrint(allocator, "{c}", .{c}) catch "char",
            .val_str => |s| std.fmt.allocPrint(allocator, "{s}", .{s}) catch "string",
            .val_void => "void",
        };

        return std.fmt.allocPrint(allocator, "[{s}: {s}]", .{
            @tagName(self),
            value,
        }) catch @tagName(self);
    }
};

/// The parser
pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []tokenizer.Token,
    pos: usize = 0,
    ok: bool = true,

    /// Create a Parser with the given allocator and token stream
    pub fn init(allocator: std.mem.Allocator, tokens: []tokenizer.Token) Parser {
        return .{
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    /// Parse the input token stream into a list of statements
    pub fn parse(self: *Parser) anyerror!std.ArrayList(*Stmt) {
        var statements: std.ArrayList(*Stmt) = .empty;

        while (!self.done())
            if (self.declaration()) |stmt|
                try statements.append(self.allocator, stmt);

        return if (self.ok) statements else ParserError.ParseFailed;
    }

    // Declaration parsing rules
    // -----------------------

    /// The declaration rule; lowest precedence, satisfied by any declaration, statement, or expression
    fn declaration(self: *Parser) ?*Stmt {
        const stmt = if (self.matches(&[_]tokenizer.TokenType{.decl_var}))
            self.varDeclaration()
        else
            self.statement();

        return stmt catch |err| {
            // If this is a ParserError, we already logged it
            switch (err) {
                ParserError.UnexpectedToken, ParserError.ExpectedExpression, ParserError.ParseFailed => {},
                else => log.err("{any}", .{err}),
            }

            self.synchronize();
            self.ok = false;
            return null;
        };
    }

    /// The variable declaration rule; satisfied by `IDENTIFIER ( = EXPRESSION ) ;`
    fn varDeclaration(self: *Parser) anyerror!*Stmt {
        const identifier = try self.consume(.identifier, "Expected variable identifier");

        // Detect type annotation
        var type_annotation: ?TypeAnnotation = null;
        if (self.matches(&[_]tokenizer.TokenType{.op_colon})) {
            // Determine pointer type if present
            var ptr_type: ?tokenizer.Token = null;
            if (self.matches(&[_]tokenizer.TokenType{ .decl_own, .decl_ref })) {
                ptr_type = self.previous();
                _ = try self.consume(.op_left_angle, "Expected '<T>' after 'own' or 'ref'");
            }

            // Determine data type
            if (!self.matches(&[_]tokenizer.TokenType{
                .dt_str,
                .dt_char,
                .dt_u8,
                .dt_u16,
                .dt_u32,
                .dt_u64,
                .dt_uword,
                .dt_i8,
                .dt_i16,
                .dt_i32,
                .dt_i64,
                .dt_iword,
                .dt_f32,
                .dt_f64,
                .dt_bool,
                .dt_void,
                .identifier,
            })) {
                log.err("Invalid data type '{s}'", .{self.peek().value});
                return ParserError.InvalidDataType;
            }

            const type_id = self.previous();
            if (ptr_type) |_| _ = try self.consume(.op_right_angle, "Missing '>' after type annotation");

            type_annotation = .{
                .type_id = type_id,
                .ptr_type = ptr_type,
            };
        }

        // Detect initializer
        var initializer: ?*Expr = null;
        if (self.matches(&[_]tokenizer.TokenType{.op_equals})) {
            initializer = try self.expression();
        }

        _ = try self.consume(.op_semicolon, "Expected ';' after variable declaration");
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .variable = .{
            .identifier = identifier,
            .type_annotation = type_annotation,
            .initializer = initializer,
        } };

        return stmt;
    }

    // Statement parsing rules
    // -----------------------

    /// The statement rule; lowest precedence, satisfied by any statement or expression
    fn statement(self: *Parser) anyerror!*Stmt {
        const stmt = try self.allocator.create(Stmt);
        var stmt_type: ?tokenizer.TokenType = null;

        // Detect builtins
        if (self.matches(&[_]tokenizer.TokenType{
            .builtin_clone,
            .builtin_copy,
            .builtin_drop,
            .builtin_new,
            .builtin_print,
        })) stmt_type = self.previous().token_type;

        const expr = try self.innerExpression();
        stmt.* = switch (stmt_type orelse .eof) {
            .builtin_clone => .{ .builtin_clone = expr },
            .builtin_copy => .{ .builtin_copy = expr },
            .builtin_drop => .{ .builtin_drop = expr },
            .builtin_new => .{ .builtin_new = expr },
            .builtin_print => .{ .builtin_print = expr },
            else => .{ .expression = expr },
        };

        return stmt;
    }

    /// The inner expression rule; connects expression-containing statements with expression parsing
    fn innerExpression(self: *Parser) anyerror!*Expr {
        const expr = try self.expression();
        _ = try self.consume(.op_semicolon, "Expected ';' after expression");

        return expr;
    }

    // Expression parsing rules
    // ------------------------

    /// The expression rule; lowest precedence, satisfied by `equality`
    fn expression(self: *Parser) anyerror!*Expr {
        return self.equality();
    }

    /// The equality rule; satisfied by `comparison (( "!=" | "==" ) comparison )*`
    fn equality(self: *Parser) anyerror!*Expr {
        var expr = try self.comparison();

        while (self.matches(&[_]tokenizer.TokenType{
            .op_bang_equals,
            .op_equals_equals,
        })) {
            const operator = self.previous();
            const right = try self.comparison();
            const node = try self.allocator.create(Expr);
            node.* = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The comparison rule; satisfied by `term (( ">" | ">=" | "<" | "<=" ) term )*`
    fn comparison(self: *Parser) anyerror!*Expr {
        var expr = try self.term();

        while (self.matches(&[_]tokenizer.TokenType{
            .op_right_angle,
            .op_greater_or_equals,
            .op_left_angle,
            .op_less_or_equals,
        })) {
            const operator = self.previous();
            const right = try self.term();
            const node = try self.allocator.create(Expr);
            node.* = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The term rule; satisfied by `factor (( "-" | "+" ) factor )*`
    fn term(self: *Parser) anyerror!*Expr {
        var expr = try self.factor();

        while (self.matches(&[_]tokenizer.TokenType{
            .op_minus,
            .op_plus,
        })) {
            const operator = self.previous();
            const right = try self.factor();
            const node = try self.allocator.create(Expr);
            node.* = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The factor rule; satisfied by `unary (( "/" | "*" ) unary )*`
    fn factor(self: *Parser) anyerror!*Expr {
        var expr = try self.unary();

        while (self.matches(&[_]tokenizer.TokenType{
            .op_slash,
            .op_star,
        })) {
            const operator = self.previous();
            const right = try self.unary();
            const node = try self.allocator.create(Expr);
            node.* = .{ .binary = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The unary rule; satisfied by `("!" | "-") unary | primary`
    fn unary(self: *Parser) anyerror!*Expr {
        if (self.matches(&[_]tokenizer.TokenType{
            .op_bang,
            .op_minus,
        })) {
            const operator = self.previous();
            const operand = try self.unary();
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .unary = .{
                .operator = operator,
                .operand = operand,
            } };

            return expr;
        }

        return self.primary();
    }

    /// The primary rule; satisfied by `NUMBER | STRING | "true" | "false" | "nil" | "(" expr ")" | IDENTIFIER`
    fn primary(self: *Parser) anyerror!*Expr {
        // Integer
        if (self.matches(&[_]tokenizer.TokenType{.lit_int})) {
            const int_val = try std.fmt.parseInt(i64, self.previous().value, 10);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_int = int_val } } };

            return expr;
        }

        // Float
        if (self.matches(&[_]tokenizer.TokenType{.lit_float})) {
            const float_val = try std.fmt.parseFloat(f64, self.previous().value);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_float = float_val } } };

            return expr;
        }

        // Char
        if (self.matches(&[_]tokenizer.TokenType{.lit_char})) {
            const char_val = self.previous().value[0];
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_char = char_val } } };

            return expr;
        }

        // String
        if (self.matches(&[_]tokenizer.TokenType{.lit_str})) {
            const str_val = self.previous().value;
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_str = str_val } } };

            return expr;
        }

        // Bool
        if (self.matches(&[_]tokenizer.TokenType{ .lit_true, .lit_false })) {
            const bool_val = std.mem.eql(u8, self.previous().value, "true");
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_bool = bool_val } } };

            return expr;
        }

        // Identifier
        if (self.matches(&[_]tokenizer.TokenType{.identifier})) {
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .variable = .{ .name = self.previous() } };

            return expr;
        }

        // Expression grouping
        if (self.matches(&[_]tokenizer.TokenType{.op_left_paren})) {
            const expr = try self.expression();
            _ = try self.consume(.op_right_paren, "Expected ')' after expression");

            const grouping = try self.allocator.create(Expr);
            grouping.* = .{ .grouping = .{ .expression = expr } };

            return grouping;
        }

        log.err("Expected expression, found {s}", .{self.peek().value});
        return ParserError.ExpectedExpression;
    }

    // Parsing utils
    // -------------

    /// Synchronize on the next expression boundary when errors are found
    fn synchronize(self: *Parser) void {
        _ = self.advance();

        while (!self.done()) {
            if (self.previous().token_type == .op_semicolon) return;

            switch (self.peek().token_type) {
                .decl_struct, .decl_static, .decl_dyn, .decl_mtd, .decl_var, .cf_loop, .cf_if, .cf_else, .cf_eval, .cf_continue, .cf_break, .cf_return => return,

                else => _ = self.advance(),
            }
        }
    }

    /// Check if the current token is of the given type and consume it if it is,
    /// but emit an error with the given message if it is not
    fn consume(self: *Parser, token_type: tokenizer.TokenType, error_msg: []const u8) ParserError!tokenizer.Token {
        if (self.check(token_type)) return self.advance();

        log.err("Parse Error - {s}", .{error_msg});
        return ParserError.UnexpectedToken;
    }

    /// Check if the current token is of any of the given types and consume it if it is
    fn matches(self: *Parser, token_types: []const tokenizer.TokenType) bool {
        for (token_types) |token_type| {
            if (self.check(token_type)) {
                _ = self.advance();
                return true;
            }
        }

        return false;
    }

    /// Check if the current token is of the given type
    fn check(self: *Parser, token_type: tokenizer.TokenType) bool {
        if (self.done()) return false;
        return self.peek().token_type == token_type;
    }

    /// Advance the parser to the next token and yield the current token
    fn advance(self: *Parser) tokenizer.Token {
        if (!self.done()) self.pos += 1;
        return self.previous();
    }

    /// Check if the parser has reached the end of the token stream
    fn done(self: *Parser) bool {
        return self.peek().token_type == .eof;
    }

    /// Yield the current token
    fn peek(self: *Parser) tokenizer.Token {
        return self.tokens[self.pos];
    }

    /// Yield the previous token
    fn previous(self: *Parser) tokenizer.Token {
        return self.tokens[self.pos - 1];
    }
};
