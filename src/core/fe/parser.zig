const log = @import("log");
const std = @import("std");
const types = @import("types");

/// Errors that can arise during parsing
pub const ParserError = error{
    UnexpectedToken,
    ExpectedExpression,
    InvalidDataType,
    ParseFailed,
};

/// The parser
pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []types.Token,
    pos: usize = 0,
    ok: bool = true,

    /// Create a Parser with the given allocator and token stream
    pub fn init(allocator: std.mem.Allocator, tokens: []types.Token) Parser {
        return .{
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    /// Parse the input token stream into a list of statements
    pub fn parse(self: *Parser) anyerror!std.ArrayList(*types.Stmt) {
        var statements: std.ArrayList(*types.Stmt) = .empty;

        while (!self.done())
            if (self.declaration()) |stmt|
                try statements.append(self.allocator, stmt);

        return if (self.ok) statements else ParserError.ParseFailed;
    }

    // Declaration parsing rules
    // -----------------------

    /// The declaration rule; lowest precedence, satisfied by any declaration, statement, or expression
    fn declaration(self: *Parser) ?*types.Stmt {
        if (self.matches(&[_]types.TokenType{.comment})) return null;

        const stmt = if (self.matches(&[_]types.TokenType{.decl_var}))
            self.varDeclaration()
        else if (self.matches(&[_]types.TokenType{.decl_pkg}))
            self.pkgDeclaration()
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

    /// The package declaration rule; satisfied by `IDENTIFIER ;`
    fn pkgDeclaration(self: *Parser) anyerror!*types.Stmt {
        const identifier = try self.consume(.identifier, "Expected package identifier");
        _ = try self.consume(.op_semicolon, "Expected ';' after package declaration");

        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .package = .{
            .identifier = identifier,
        } };

        return stmt;
    }

    /// The variable declaration rule; satisfied by `IDENTIFIER ( : ( T | own<T> | ref<T> ) ) ( = EXPRESSION ) ;`
    fn varDeclaration(self: *Parser) anyerror!*types.Stmt {
        const identifier = try self.consume(.identifier, "Expected variable identifier");

        // Detect type annotation
        var type_annotation: ?types.TypeAnnotation = null;
        if (self.matches(&[_]types.TokenType{.op_colon})) {
            // Determine pointer type if present
            var ptr_type: ?types.Token = null;
            if (self.matches(&[_]types.TokenType{ .decl_own, .decl_ref })) {
                ptr_type = self.previous();
                _ = try self.consume(.op_left_angle, "Expected '<T>' after 'own' or 'ref'");
            }

            // Determine data type
            if (!self.matches(&[_]types.TokenType{
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
        var initializer: ?*types.Expr = null;
        if (self.matches(&[_]types.TokenType{.op_equals})) {
            initializer = try self.expression();
        }

        _ = try self.consume(.op_semicolon, "Expected ';' after variable declaration");
        const stmt = try self.allocator.create(types.Stmt);
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
    fn statement(self: *Parser) anyerror!*types.Stmt {
        const stmt = try self.allocator.create(types.Stmt);
        var stmt_type: ?types.TokenType = null;

        // Detect builtins
        if (self.matches(&[_]types.TokenType{
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
    fn innerExpression(self: *Parser) anyerror!*types.Expr {
        const expr = try self.expression();
        _ = try self.consume(.op_semicolon, "Expected ';' after expression");

        return expr;
    }

    // Expression parsing rules
    // ------------------------

    /// The expression rule; lowest precedence, satisfied by `equality`
    fn expression(self: *Parser) anyerror!*types.Expr {
        return self.equality();
    }

    /// The equality rule; satisfied by `comparison (( "!=" | "==" ) comparison )*`
    fn equality(self: *Parser) anyerror!*types.Expr {
        var expr = try self.comparison();

        while (self.matches(&[_]types.TokenType{
            .op_bang_equals,
            .op_equals_equals,
        })) {
            const operator = self.previous();
            const right = try self.comparison();
            const node = try self.allocator.create(types.Expr);
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
    fn comparison(self: *Parser) anyerror!*types.Expr {
        var expr = try self.term();

        while (self.matches(&[_]types.TokenType{
            .op_right_angle,
            .op_greater_or_equals,
            .op_left_angle,
            .op_less_or_equals,
        })) {
            const operator = self.previous();
            const right = try self.term();
            const node = try self.allocator.create(types.Expr);
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
    fn term(self: *Parser) anyerror!*types.Expr {
        var expr = try self.factor();

        while (self.matches(&[_]types.TokenType{
            .op_minus,
            .op_plus,
        })) {
            const operator = self.previous();
            const right = try self.factor();
            const node = try self.allocator.create(types.Expr);
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
    fn factor(self: *Parser) anyerror!*types.Expr {
        var expr = try self.unary();

        while (self.matches(&[_]types.TokenType{
            .op_slash,
            .op_star,
        })) {
            const operator = self.previous();
            const right = try self.unary();
            const node = try self.allocator.create(types.Expr);
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
    fn unary(self: *Parser) anyerror!*types.Expr {
        if (self.matches(&[_]types.TokenType{
            .op_bang,
            .op_minus,
        })) {
            const operator = self.previous();
            const operand = try self.unary();
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .unary = .{
                .operator = operator,
                .operand = operand,
            } };

            return expr;
        }

        return self.primary();
    }

    /// The primary rule; satisfied by `NUMBER | STRING | "true" | "false" | "nil" | "(" expr ")" | IDENTIFIER`
    fn primary(self: *Parser) anyerror!*types.Expr {
        // Integer
        if (self.matches(&[_]types.TokenType{.lit_int})) {
            const int_val = try std.fmt.parseInt(i64, self.previous().value, 10);
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_int = int_val } } };

            return expr;
        }

        // Float
        if (self.matches(&[_]types.TokenType{.lit_float})) {
            const float_val = try std.fmt.parseFloat(f64, self.previous().value);
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_float = float_val } } };

            return expr;
        }

        // Char
        if (self.matches(&[_]types.TokenType{.lit_char})) {
            const char_val = self.previous().value[0];
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_char = char_val } } };

            return expr;
        }

        // String
        if (self.matches(&[_]types.TokenType{.lit_str})) {
            const str_val = self.previous().value;
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_str = str_val } } };

            return expr;
        }

        // Bool
        if (self.matches(&[_]types.TokenType{ .lit_true, .lit_false })) {
            const bool_val = std.mem.eql(u8, self.previous().value, "true");
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_bool = bool_val } } };

            return expr;
        }

        // Identifier
        if (self.matches(&[_]types.TokenType{.identifier})) {
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .variable = .{ .name = self.previous() } };

            return expr;
        }

        // Expression grouping
        if (self.matches(&[_]types.TokenType{.op_left_paren})) {
            const expr = try self.expression();
            _ = try self.consume(.op_right_paren, "Expected ')' after expression");

            const grouping = try self.allocator.create(types.Expr);
            grouping.* = .{ .grouping = .{ .expression = expr } };

            return grouping;
        }

        log.err("Expected expression, found {s} on line {d} col {d}", .{
            self.peek().value,
            self.peek().line,
            self.peek().col,
        });
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
                .decl_struct,
                .decl_static,
                .decl_dyn,
                .decl_mtd,
                .decl_var,
                .cf_loop,
                .cf_if,
                .cf_else,
                .cf_eval,
                .cf_continue,
                .cf_break,
                .cf_return,
                => return,

                else => _ = self.advance(),
            }
        }
    }

    /// Check if the current token is of the given type and consume it if it is,
    /// but emit an error with the given message if it is not
    fn consume(self: *Parser, token_type: types.TokenType, error_msg: []const u8) ParserError!types.Token {
        if (self.check(token_type)) return self.advance();

        log.err("{s} on line {d} col {d}", .{
            error_msg,
            self.peek().line,
            self.peek().col,
        });
        return ParserError.UnexpectedToken;
    }

    /// Check if the current token is of any of the given types and consume it if it is
    fn matches(self: *Parser, token_types: []const types.TokenType) bool {
        for (token_types) |token_type| {
            if (self.check(token_type)) {
                _ = self.advance();
                return true;
            }
        }

        return false;
    }

    /// Check if the current token is of the given type
    fn check(self: *Parser, token_type: types.TokenType) bool {
        if (self.done()) return false;
        return self.peek().token_type == token_type;
    }

    /// Advance the parser to the next token and yield the current token
    fn advance(self: *Parser) types.Token {
        if (!self.done()) self.pos += 1;
        return self.previous();
    }

    /// Check if the parser has reached the end of the token stream
    fn done(self: *Parser) bool {
        return self.peek().token_type == .eof;
    }

    /// Yield the current token
    fn peek(self: *Parser) types.Token {
        return self.tokens[self.pos];
    }

    /// Yield the previous token
    fn previous(self: *Parser) types.Token {
        return self.tokens[self.pos - 1];
    }
};
