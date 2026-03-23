const log = @import("log");
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const value = @import("value.zig");

/// Errors that can arise during parsing
pub const ParserError = error{UnexpectedToken, ExpectedExpression};

/// Parse tokens into an list of statement trees
/// TODO: Move to root.zig
pub fn parse(allocator: std.mem.Allocator, tokens: []tokenizer.Token) !std.ArrayList(Stmt) {
    var parser = Parser.init(allocator, tokens);
    return parser.parse();
}

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
    allocator: std.mem.Allocator,
    tokens: []tokenizer.Token,
    pos: usize = 0,

    /// Create a Parser with the given allocator and token stream
    pub fn init(allocator: std.mem.Allocator, tokens: []tokenizer.Token) Parser {
        return .{
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    /// Parse the input token stream into a list of statements
    pub fn parse(self: *Parser) !std.ArrayList(*Stmt) {
        var statements: std.ArrayList(*Stmt) = .empty;
        
        while (!self.done())
            if (self.declaration()) |stmt|
                try statements.append(self.allocator, stmt);

        return statements;
    }

    // Declaration parsing rules
    // -----------------------

    /// The declaration rule; lowest precedence, satisfied by any declaration, statement, or expression
    fn declaration(self: *Parser) ?*Stmt {
        const res = if(self.matches(&[_]tokenizer.TokenType{.decl_var})) {
            self.varDeclaration();
        } else {
            self.statement();
        } catch |err| {
            log.err("{any}", .{err});
            self.synchronize();
            return null;
        };

        return res;
    }

    /// The variable declaration rule; satisfied by `IDENTIFIER ( = EXPRESSION ) ;`
    /// TODO: implement type annotations
    fn varDeclaration(self: *Parser) !*Stmt {
        const identifier = try self.consume(.identifier, "Expected variable identifier");
        const initializer: ?*Expr = if (self.matches(&[_]tokenizer.TokenType{.op_equals})) {
            try self.expression();
        } else {
            null;
        };

        try self.consume(&[_]tokenizer.TokenType{.op_semicolon}, "Expected ';' after variable declaration");
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .variable = .{
            .identifier = identifier,
            .initializer = initializer,
        }};

        return stmt;
    }
    
    // Statement parsing rules
    // -----------------------

    /// The statement rule; lowest precedence, satisfied by any statement or expression
    fn statement(self: *Parser) !*Stmt {
        const expr = try self.innerExpression();
        const stmt = try self.allocator.create(Stmt); 
        
        // Builtins - TODO: do we need this?
        if (self.matches(&[_]tokenizer.TokenType{
            .builtin_clone,
            .builtin_copy,
            .builtin_drop,
            .builtin_new,
            .builtin_print,
        })) {
            stmt.* = switch (self.previous().token_type) {
                .builtin_clone => .{ .builtin_clone = expr },
                .builtin_copy => .{ .builtin_copy = expr },
                .builtin_drop => .{ .builtin_drop = expr },
                .builtin_new => .{ .builtin_new = expr },
                .builtin_print => .{ .builtin_print = expr },
                else => undefined,
            };
        } else stmt.* = .{ .expression = expr };

        return stmt;
    }

    /// The inner expression rule; connects expression-containing statements with expression parsing
    fn innerExpression(self: *Parser) !*Expr {
        const expr = try self.expression();
        try self.consume(.op_semicolon, "Expected ';' after expression");
    
        return expr;
    }

    // Expression parsing rules
    // ------------------------

    /// The expression rule; lowest precedence, satisfied by `equality`
    fn expression(self: *Parser) !*Expr {
        return self.equality();
    }

    /// The equality rule; satisfied by `comparison (( "!=" | "==" ) comparison )*`
    fn equality(self: *Parser) !*Expr {
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
            }};
            expr = node;
        }

        return expr;
    }

    /// The comparison rule; satisfied by `term (( ">" | ">=" | "<" | "<=" ) term )*`
    fn comparison(self: *Parser) !*Expr {
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
            }};
            expr = node;
        }

        return expr;
    }

    /// The term rule; satisfied by `factor (( "-" | "+" ) factor )*`
    fn term(self: *Parser) !*Expr {
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
            }};
            expr = node;
        }

        return expr;
    }

    /// The factor rule; satisfied by `unary (( "/" | "*" ) unary )*`
    fn factor(self: *Parser) !*Expr {
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
            }};
            expr = node;
        }

        return expr;
    }

    /// The unary rule; satisfied by `("!" | "-") unary | primary`
    fn unary(self: *Parser) !*Expr {
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
            }};

            return expr;
        }

        return self.primary();
    }

    /// The primary rule; satisfied by `NUMBER | STRING | "true" | "false" | "nil" | "(" expr ")" | IDENTIFIER`
    fn primary(self: *Parser) !*Expr {
        // Integer
        if (self.matches(&[_]tokenizer.TokenType{.lit_int})) {
            const int_val = try std.fmt.parseInt(i64, self.previous().value, 10);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_int = int_val }}};

            return expr;
        }

        // Float
        if (self.matches(&[_]tokenizer.TokenType{.lit_float})) {
            const float_val = try std.fmt.parseFloat(f64, self.previous().value);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_float = float_val }}};
            
            return expr;
        }

        // Char
        if (self.matches(&[_]tokenizer.TokenType{.lit_char})) {
            const char_val = self.previous().value[0];
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_char = char_val }}};

            return expr;
        }

        // String
        if (self.matches(&[_]tokenizer.TokenType{.lit_str})) {
            const str_val = self.previous();
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_str = str_val }}};
        
            return expr;
        }
      
        // Bool
        if (self.matches(&[_]tokenizer.TokenType{ .lit_true, .lit_false })) {
            const bool_val = std.mem.eql(u8, self.previous().value, "true");
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .literal = .{ .value = .{ .val_bool = bool_val }}};

            return expr;
        }
 
        // Identifier
        if (self.matches(&[_]tokenizer.TokenType{.identifier})) {
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .variable = .{ .name = self.previous().value }};

            return expr;
        }

        // Expression grouping
        if (self.matches(&[_]tokenizer.TokenType{.op_left_paren})) {
            const expr = try self.expression();
            try self.consume(.op_right_paren, "Expected ')' after expression");
            
            const grouping = try self.allocator.create(Expr);
            grouping.* = .{ .grouping = .{ .expression = expr }};
            
            return grouping;
        }

        log.err("Expected expression, found {s}", .{self.peek().value});
        return ParserError.ExpectedExpression;
    }

    // Parsing utils
    // -------------

    /// Synchronize on the next expression boundary when errors are found
    fn synchronize(self: *Parser) void {
        self.advance();

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
              .cf_return => return,

              else => self.advance(),
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
    fn matches(self: *Parser, token_types: []tokenizer.TokenType) bool {
        for (token_types) |token_type| {
            if (self.check(token_type)) {
                self.advance();
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

