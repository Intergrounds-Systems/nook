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

/// Token types representing primitive or user-defined data types
const data_types = [_]types.TokenType{
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
    .identifier,
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
        if (self.matches(&.{.comment})) return null;

        const stmt = if (self.matches(&.{.decl_var}))
            self.varDeclaration()
        else if (self.matches(&.{.decl_pkg}))
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
        if (self.matches(&.{.op_colon})) {
            // Determine pointer type if present
            var ptr_type: ?types.Token = null;
            if (self.matches(&.{ .ptr_own, .ptr_ref })) {
                ptr_type = self.previous();
                _ = try self.consume(.op_left_angle, "Expected '<T>' after 'own' or 'ref'");
            }

            // Determine data type
            if (!self.matches(&data_types)) {
                log.err("Invalid data type '{s}'", .{self.peek().value});
                return ParserError.InvalidDataType;
            }

            // Commit data type and close pointer annotation
            const type_id = self.previous();
            if (ptr_type) |_| _ = try self.consume(.op_right_angle, "Missing '>' after type annotation");

            type_annotation = .{
                .type_id = type_id,
                .ptr_type = ptr_type,
            };
        }

        // Detect initializer
        var initializer: ?*types.Expr = null;
        if (self.matches(&.{.op_equals})) {
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
        if (self.matches(&.{
            .builtin_drop,
            .builtin_print,
        })) stmt_type = self.previous().token_type;

        const expr = try self.innerExpression();
        stmt.* = switch (stmt_type orelse .eof) {
            .builtin_drop => .{ .builtin_drop = expr },
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

    /// The expression rule; lowest precedence, satisfied by `logicalOr`
    fn expression(self: *Parser) anyerror!*types.Expr {
        return self.logicalOr();
    }

    /// The logical OR rule; satisfied by `logicalXor ( "||" logicalXor )*`
    fn logicalOr(self: *Parser) anyerror!*types.Expr {
        var expr = try self.logicalXor();

        while (self.matches(&.{.op_pipe_pipe})) {
            const operator = self.previous();
            const right = try self.logicalXor();
            const node = try self.allocator.create(types.Expr);
            node.* = .{ .logical = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The logical XOR rule; satisfied by `logicalAnd ( "^^" logicalAnd )*`
    fn logicalXor(self: *Parser) anyerror!*types.Expr {
        var expr = try self.logicalAnd();

        while (self.matches(&.{.op_caret_caret})) {
            const operator = self.previous();
            const right = try self.logicalAnd();
            const node = try self.allocator.create(types.Expr);
            node.* = .{ .logical = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The logical AND rule; satisfied by `equality ( "&&" equality )*`
    fn logicalAnd(self: *Parser) anyerror!*types.Expr {
        var expr = try self.equality();

        while (self.matches(&.{.op_and_and})) {
            const operator = self.previous();
            const right = try self.equality();
            const node = try self.allocator.create(types.Expr);
            node.* = .{ .logical = .{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = node;
        }

        return expr;
    }

    /// The equality rule; satisfied by `comparison (( "!=" | "==" ) comparison )*`
    fn equality(self: *Parser) anyerror!*types.Expr {
        var expr = try self.comparison();

        while (self.matches(&.{
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

    /// The comparison rule; satisfied by `bitwiseOr (( ">" | ">=" | "<" | "<=" ) bitwiseOr )*`
    fn comparison(self: *Parser) anyerror!*types.Expr {
        var expr = try self.bitwiseOr();

        while (self.matches(&.{
            .op_right_angle,
            .op_greater_or_equals,
            .op_left_angle,
            .op_less_or_equals,
        })) {
            const operator = self.previous();
            const right = try self.bitwiseOr();
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

    /// The bitwise OR rule; satisfied by `bitwiseXor ( "|" bitwiseXor )*`
    fn bitwiseOr(self: *Parser) anyerror!*types.Expr {
        var expr = try self.bitwiseXor();

        while (self.matches(&.{.op_pipe})) {
            const operator = self.previous();
            const right = try self.bitwiseXor();
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

    /// The bitwise XOR rule; satisfied by `bitwiseAnd ( "^" bitwiseAnd )*`
    fn bitwiseXor(self: *Parser) anyerror!*types.Expr {
        var expr = try self.bitwiseAnd();

        while (self.matches(&.{.op_caret})) {
            const operator = self.previous();
            const right = try self.bitwiseAnd();
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

    /// The bitwise AND rule; satisfied by `shift ( "&" shift )*`
    fn bitwiseAnd(self: *Parser) anyerror!*types.Expr {
        var expr = try self.shift();

        while (self.matches(&.{.op_and})) {
            const operator = self.previous();
            const right = try self.shift();
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

    /// The bit shift rule; satisfied by `term (( ">>" | "<<" ) term )*`
    fn shift(self: *Parser) anyerror!*types.Expr {
        var expr = try self.term();

        while (self.matches(&.{ .op_right_shift, .op_left_shift })) {
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

        while (self.matches(&.{
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

    /// The factor rule; satisfied by `unary (( "/" | "*" | "%" ) unary )*`
    fn factor(self: *Parser) anyerror!*types.Expr {
        var expr = try self.unary();

        while (self.matches(&.{
            .op_slash,
            .op_star,
            .op_percent,
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

    /// The unary rule; satisfied by `( "!" | "-" | "~" | "new" | "copy" | "clone" ) unary | exponent`
    fn unary(self: *Parser) anyerror!*types.Expr {
        if (self.matches(&.{
            .op_bang,
            .op_minus,
            .op_tilde,
            .builtin_new,
            .builtin_copy,
            .builtin_clone,
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

        return self.exponent();
    }

    /// The exponent rule; satisfied by `pointer ( "**" unary )`
    fn exponent(self: *Parser) anyerror!*types.Expr {
        var expr = try self.pointer();

        if (self.matches(&.{.op_star_star})) {
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

    /// The pointer rule; satisfied by `( "$" | "#" ) pointer | primary`
    fn pointer(self: *Parser) anyerror!*types.Expr {
        if (self.matches(&.{
            .op_dollar,
            .op_hash,
        })) {
            const operator = self.previous();
            const operand = try self.pointer();
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .unary = .{
                .operator = operator,
                .operand = operand,
            } };

            return expr;
        }

        return self.primary();
    }

    /// The primary rule; satisfied by `NUMBER | CHAR | STRING | "true" | "false" | construct | "(" expr ")" | IDENTIFIER`
    fn primary(self: *Parser) anyerror!*types.Expr {
        // Integer
        if (self.matches(&.{.lit_int})) {
            const int_val = try std.fmt.parseInt(i64, self.previous().value, 10);
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_int = int_val } } };

            return expr;
        }

        // Float
        if (self.matches(&.{.lit_float})) {
            const float_val = try std.fmt.parseFloat(f64, self.previous().value);
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_float = float_val } } };

            return expr;
        }

        // Char
        if (self.matches(&.{.lit_char})) {
            const char_val = self.previous().value[0];
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_char = char_val } } };

            return expr;
        }

        // String
        if (self.matches(&.{.lit_str})) {
            const str_val = self.previous().value;
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_str = str_val } } };

            return expr;
        }

        // Bool
        if (self.matches(&.{ .lit_true, .lit_false })) {
            const bool_val = std.mem.eql(u8, self.previous().value, "true");
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_bool = bool_val } } };

            return expr;
        }

        // Construct
        if (self.checkNext(&.{.op_left_brace}) and self.matches(&data_types)) return self.construct();

        // Identifier
        if (self.matches(&.{.identifier})) {
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .variable = .{ .name = self.previous() } };

            return expr;
        }

        // Expression grouping
        if (self.matches(&.{.op_left_paren})) {
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

    /// The construct rule; satisfied by `( T | IDENTIFIER ) "{" ( FIELDS... ) "}"`
    fn construct(self: *Parser) anyerror!*types.Expr {
        const type_id = self.previous();
        _ = try self.consume(.op_left_brace, "Expected '{' after type in construct");

        // Harvest the fields
        var fields: std.ArrayList(types.Expr.Construct.Field) = .empty;
        while (!self.done() and !self.check(&.{.op_right_brace})) {
            var name: ?types.Token = null;

            // Look for field names in the format of <name>:
            if (self.check(&.{.identifier}) and self.checkNext(&.{.op_colon})) {
                name = self.advance();
                _ = self.advance(); // consume the colon
            }

            try fields.append(self.allocator, .{ .name = name, .value = try self.expression() });
            if (!self.matches(&.{.op_comma})) break;
        }

        // Consume the closing brace and yield the construct
        _ = try self.consume(.op_right_brace, "Expected '}' after construct members");
        const expr = try self.allocator.create(types.Expr);
        expr.* = .{ .construct = .{
            .type_id = type_id,
            .fields = try fields.toOwnedSlice(self.allocator),
        } };

        return expr;
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
        if (self.check(&.{token_type})) return self.advance();

        log.err("{s} on line {d} col {d}", .{
            error_msg,
            self.peek().line,
            self.peek().col,
        });
        return ParserError.UnexpectedToken;
    }

    /// Check if the current token is of any of the given types
    fn check(self: *Parser, token_types: []const types.TokenType) bool {
        if (self.done()) return false;
        for (token_types) |token_type| if (self.peek().token_type == token_type) return true;
        return false;
    }

    /// Check if the token after the current one is of any of the given types
    fn checkNext(self: *Parser, token_types: []const types.TokenType) bool {
        if (self.done()) return false;
        for (token_types) |token_type| if (self.tokens[self.pos + 1].token_type == token_type) return true;
        return false;
    }

    /// Consume the current token if it is of any of the given types
    fn matches(self: *Parser, token_types: []const types.TokenType) bool {
        if (self.check(token_types)) {
            _ = self.advance();
            return true;
        }

        return false;
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
