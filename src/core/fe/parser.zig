const log = @import("log");
const std = @import("std");
const types = @import("types");

/// Errors that can arise during parsing
pub const ParserError = error{
    UnexpectedToken,
    ExpectedExpression,
    InvalidDataType,
    InvalidAssignmentTarget,
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
    .dt_void,
    .identifier,
};

/// Token types representing the assignment operators
const assign_ops = [_]types.TokenType{
    .op_equals,
    .op_plus_equals,
    .op_minus_equals,
    .op_star_equals,
    .op_star_star_equals,
    .op_slash_equals,
    .op_percent_equals,
    .op_pipe_equals,
    .op_and_equals,
    .op_caret_equals,
    .op_left_shift_equals,
    .op_right_shift_equals,
};

/// The parser
pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []types.Token,
    pos: usize = 0,
    depth: usize = 0,
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

        const stmt = if (self.matches(&.{
            .decl_var,
            .decl_const,
            .decl_static,
        }))
            self.symbol()
        else if (self.matches(&.{.decl_pkg}))
            self.package()
        else if (self.matches(&.{.decl_struct}))
            self.structure()
        else
            self.statement();

        return stmt catch |err| {
            // If this is a ParserError, we already logged it
            switch (err) {
                ParserError.UnexpectedToken,
                ParserError.ExpectedExpression,
                ParserError.ParseFailed,
                ParserError.InvalidDataType,
                ParserError.InvalidAssignmentTarget,
                => {},
                else => log.err("{any}", .{err}),
            }

            self.synchronize();
            self.ok = false;
            return null;
        };
    }

    /// The package rule; satisfied by `IDENTIFIER ;`
    fn package(self: *Parser) anyerror!*types.Stmt {
        const identifier = try self.consume(.identifier, "Expected package identifier");
        _ = try self.consume(.op_semicolon, "Expected ';' after package declaration");

        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .package = .{
            .identifier = identifier,
        } };

        return stmt;
    }

    /// The symbol rule; satisfied by `IDENTIFIER ( : ( T | own<T> | ref<T> | func<(T, T, T...) -> T> ) ) ( = EXPRESSION ) ;`
    fn symbol(self: *Parser) anyerror!*types.Stmt {
        const kind = self.previous();
        const identifier = try self.consume(.identifier, "Expected symbol identifier");

        // Detect type annotation
        var type_annotation: ?*types.TypeAnnotation = null;
        if (self.matches(&.{.op_colon})) type_annotation = try self.typeAnnotation();

        // Detect initializer
        var initializer: ?*types.Expr = null;
        if (self.matches(&.{.op_equals})) {
            initializer = try self.expression();
        }

        // Check whether we're defining a struct
        const is_struct = if (initializer) |in| in.* == .function else false;
        if (!is_struct) _ = try self.consume(.op_semicolon, "Expected ';' after symbol declaration");

        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .symbol = .{
            .kind = kind,
            .identifier = identifier,
            .type_annotation = type_annotation,
            .initializer = initializer,
        } };

        return stmt;
    }

    /// The type annotation rule; satisfied by `own<T> | ref<T> | func<(T, T, T...) -> T> | T`
    fn typeAnnotation(self: *Parser) anyerror!*types.TypeAnnotation {
        const node = try self.allocator.create(types.TypeAnnotation);

        // Match the pointer shape
        if (self.matches(&.{ .ptr_own, .ptr_ref })) {
            const kind = self.previous();
            _ = try self.consume(.op_left_angle, "Expected '<' after 'own' or 'ref'");
            const inner = try self.typeAnnotation();
            _ = try self.consumeRightAngle("Expected '>' after pointer type");

            node.* = .{ .pointer = .{
                .kind = kind,
                .inner = inner,
            } };
            return node;
        }

        // Match the function shape
        if (self.matches(&.{.dt_func})) {
            _ = try self.consume(.op_left_angle, "Expected '<' after 'func'");
            _ = try self.consume(.op_left_paren, "Expected '(' after 'func<'");

            // Collect params
            var params: std.ArrayList(*types.TypeAnnotation) = .empty;
            while (!self.done() and !self.check(&.{.op_right_paren})) {
                try params.append(self.allocator, try self.typeAnnotation());
                if (!self.matches(&.{.op_comma})) break;
            }

            // Close params list and get return type
            _ = try self.consume(.op_right_paren, "Expected ')' after parameters list");
            _ = try self.consume(.op_right_arrow, "Expected '->' after parameters list");
            const returns = try self.typeAnnotation();
            _ = try self.consumeRightAngle("Expected '>' after function signature");

            node.* = .{ .function = .{
                .params = try params.toOwnedSlice(self.allocator),
                .returns = returns,
            } };
            return node;
        }

        // Match the data type shape
        if (!self.matches(&data_types)) {
            log.err("Invalid data type '{s}'", .{self.peek().value});
            return ParserError.InvalidDataType;
        }

        node.* = .{ .named = .{ .type_id = self.previous() } };
        return node;
    }

    // Statement parsing rules
    // -----------------------

    /// The statement rule; satisfied by any statement or expression
    fn statement(self: *Parser) anyerror!*types.Stmt {
        // Detect blocks
        if (self.check(&.{.op_left_brace})) return self.block();

        // Detect if and loop statements
        if (self.matches(&.{ .cf_if, .cf_loop })) return self.conditional();

        // Detect jumps
        if (self.matches(&.{
            .cf_return,
            .cf_break,
            .cf_continue,
        })) return self.jump();

        // Detect builtin statements
        var builtin_type: ?types.TokenType = null;
        if (self.matches(&.{
            .builtin_drop,
            .builtin_print,
        })) builtin_type = self.previous().token_type;

        // Parse everything else then check for assignments
        const stmt = try self.allocator.create(types.Stmt);
        const expr = try self.expression();
        if (builtin_type == null and self.matches(&assign_ops)) {
            const operator = self.previous();

            // Validate target of assignment
            switch (expr.*) {
                .variable, .get => {},
                else => {
                    log.err("Invalid assignment target of '{s}' on line {d} col {d}", .{
                        operator.value,
                        operator.line,
                        operator.col,
                    });
                    return ParserError.InvalidAssignmentTarget;
                },
            }

            // Get value of assignment
            const value = try self.expression();
            _ = try self.consume(.op_semicolon, "Expected ';' after assignment");
            stmt.* = .{ .assignment = .{
                .target = expr,
                .operator = operator,
                .value = value,
            } };

            return stmt;
        }

        // Fallthrough: not an assignment statement
        _ = try self.consume(.op_semicolon, "Expected ';' after expression");
        stmt.* = switch (builtin_type orelse .eof) {
            .builtin_drop => .{ .builtin_drop = expr },
            .builtin_print => .{ .builtin_print = expr },
            else => .{ .expression = expr },
        };

        return stmt;
    }

    /// The structure rule; satisfied by `struct IDENTIFER BLOCK`
    fn structure(self: *Parser) anyerror!*types.Stmt {
        const identifier = try self.consume(.identifier, "Expected struct name");
        const body = try self.block();

        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .structure = .{
            .identifier = identifier,
            .body = body,
        } };

        return stmt;
    }

    /// The block rule; satisfied by `"{" ( DECLARATIONS... ) "}"
    fn block(self: *Parser) anyerror!*types.Stmt {
        _ = try self.consume(.op_left_brace, "Expected '{' to open block body");
        self.depth += 1;

        // Collect inner statements, parses up because each block is a fresh scope that can contain declarations
        var statements: std.ArrayList(*types.Stmt) = .empty;
        while (!self.done() and !self.check(&.{.op_right_brace}))
            if (self.declaration()) |stmt|
                try statements.append(self.allocator, stmt);

        self.depth -= 1;
        _ = try self.consume(.op_right_brace, "Expected '}' after block body");
        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .block = .{
            .statements = try statements.toOwnedSlice(self.allocator),
        } };

        return stmt;
    }

    /// The conditional rule; satisfied by `if | loop | iter "(" EXPRESSION ")" BLOCK ( else ( CONDITIONAL | BLOCK ) )`
    fn conditional(self: *Parser) anyerror!*types.Stmt {
        const keyword = self.previous();
        _ = try self.consume(.op_left_paren, "Expected '(' before condition");
        const condition = try self.expression();
        _ = try self.consume(.op_right_paren, "Expected ')' after condition");

        // Parse the branch bodies
        const then_branch = try self.block();
        var else_branch: ?*types.Stmt = null;
        if (self.matches(&.{.cf_else})) {
            else_branch = if (self.matches(&.{
                .cf_if,
                .cf_loop,
            }))
                try self.conditional()
            else
                try self.block();
        }

        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .conditional = .{
            .keyword = keyword,
            .condition = condition,
            .then_branch = then_branch,
            .else_branch = else_branch,
        } };

        return stmt;
    }

    /// The jump rule; satisfied by `return ( EXPRESSION ) | break | continue`
    fn jump(self: *Parser) anyerror!*types.Stmt {
        const keyword = self.previous();
        var value: ?*types.Expr = null;
        if (keyword.token_type == .cf_return and !self.check(&.{.op_semicolon}))
            value = try self.expression();

        _ = try self.consume(.op_semicolon, "Expected ';' after jump");
        const stmt = try self.allocator.create(types.Stmt);
        stmt.* = .{ .jump = .{
            .keyword = keyword,
            .value = value,
        } };
        return stmt;
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

    /// The pointer rule; satisfied by `( "$" | "#" ) pointer | postfix`
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

        return self.postfix();
    }

    /// The postfix rule; satisfied by `primary ( "(" ARGS... ")" | "." IDENTIFIER )*`
    fn postfix(self: *Parser) anyerror!*types.Expr {
        var expr = try self.primary();

        while (true) {
            if (self.matches(&.{.op_left_paren})) {
                // Match on the parens-args shape
                const paren = self.previous();

                // Harvest the arguments
                var args: std.ArrayList(*types.Expr) = .empty;
                while (!self.done() and !self.check(&.{.op_right_paren})) {
                    try args.append(self.allocator, try self.expression());
                    if (!self.matches(&.{.op_comma})) break;
                }
                _ = try self.consume(.op_right_paren, "Expected ')' after arguments");

                // Create the node
                const node = try self.allocator.create(types.Expr);
                node.* = .{ .call = .{
                    .callee = expr,
                    .paren = paren,
                    .args = try args.toOwnedSlice(self.allocator),
                } };
                expr = node;
            } else if (self.matches(&.{.op_dot})) {
                // Match on the dot-identifier shape
                const field = try self.consume(.identifier, "Expected field name after '.'");
                const node = try self.allocator.create(types.Expr);
                node.* = .{ .get = .{
                    .instance = expr,
                    .field = field,
                } };
                expr = node;
            } else break;
        }

        return expr;
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
        if (self.checkAt(1, &.{.op_left_brace}) and self.matches(&data_types)) return self.construct();

        // Implicit self member access
        if (self.matches(&.{.op_dot})) {
            const field = try self.consume(.identifier, "Expected field name after '.'");
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .get = .{
                .instance = null,
                .field = field,
            } };

            return expr;
        }

        // Identifier
        if (self.matches(&.{.identifier})) {
            const expr = try self.allocator.create(types.Expr);
            expr.* = .{ .variable = .{ .name = self.previous() } };

            return expr;
        }

        // Function definition
        const left_paren = self.check(&.{.op_left_paren});
        const empty_signature = self.checkAt(1, &.{.op_right_paren});
        const args_signature = self.checkAt(1, &.{.identifier}) and self.checkAt(2, &.{.op_colon});
        if (left_paren and (empty_signature or args_signature)) return self.function();

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
            if (self.check(&.{.identifier}) and self.checkAt(1, &.{.op_colon})) {
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

    /// The function rule; satisfied by `"(" ( IDENTIFIER : T, ... ) ")" -> T BLOCK`
    fn function(self: *Parser) anyerror!*types.Expr {
        _ = try self.consume(.op_left_paren, "Expected '(' to open parameter list");

        // Collect params
        var params: std.ArrayList(types.Expr.Function.Param) = .empty;
        while (!self.done() and !self.check(&.{.op_right_paren})) {
            const name = try self.consume(.identifier, "Expected parameter name");
            _ = try self.consume(.op_colon, "Expected ':' after parameter name");

            try params.append(self.allocator, .{
                .name = name,
                .type_annotation = try self.typeAnnotation(),
            });

            if (!self.matches(&.{.op_comma})) break;
        }

        // Close the param list and get the return type
        _ = try self.consume(.op_right_paren, "Expected ')' after parameter list");
        _ = try self.consume(.op_right_arrow, "Expected '->' after parameter list");
        const returns = try self.typeAnnotation();
        const body = try self.block();

        const expr = try self.allocator.create(types.Expr);
        expr.* = .{ .function = .{
            .params = try params.toOwnedSlice(self.allocator),
            .returns = returns,
            .body = body,
        } };

        return expr;
    }

    // Parsing utils
    // -------------

    /// Synchronize on the next expression boundary when errors are found
    fn synchronize(self: *Parser) void {
        if (!self.doneBlock()) _ = self.advance();

        while (!self.done()) {
            if (self.doneBlock()) return;
            if (self.previous().token_type == .op_semicolon) return;

            switch (self.peek().token_type) {
                .decl_struct,
                .decl_static,
                .decl_const,
                .decl_var,
                .cf_loop,
                .cf_if,
                .cf_else,
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

    /// Consume a '>' that might be the first char in a '>>' token. If it is, it overwrites
    /// the '>>' in-stream with a single '>', consuming the first '>'
    fn consumeRightAngle(self: *Parser, err_msg: []const u8) ParserError!types.Token {
        if (self.check(&.{.op_right_shift})) {
            const shift_token = self.peek();
            self.tokens[self.pos] = .{
                .value = ">",
                .token_type = .op_right_angle,
                .line = shift_token.line,
                .col = shift_token.col + 1,
            };

            return .{
                .value = ">",
                .token_type = .op_right_angle,
                .line = shift_token.line,
                .col = shift_token.col,
            };
        }

        return self.consume(.op_right_angle, err_msg);
    }

    /// Check if the current token is of any of the given types
    fn check(self: *Parser, token_types: []const types.TokenType) bool {
        if (self.done()) return false;
        for (token_types) |token_type| if (self.peek().token_type == token_type) return true;
        return false;
    }

    /// Check if the token at a specific offset ahead of the current token matches the list
    fn checkAt(self: *Parser, offset: usize, token_types: []const types.TokenType) bool {
        if (self.pos + offset >= self.tokens.len) return false;
        for (token_types) |token_type| if (self.tokens[self.pos + offset].token_type == token_type) return true;
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

    /// Check if the parser is at the end of a block
    fn doneBlock(self: *Parser) bool {
        return self.depth > 0 and self.check(&.{.op_right_brace});
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
