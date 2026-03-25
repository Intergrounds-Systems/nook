const log = @import("log");
const std = @import("std");

/// Errors that can arise during tokenization
const TokenizerError = error{ NoSourceCode, SyntaxError };

/// An individual semantic unit in the source code
pub const Token = struct {
    value: []const u8,
    token_type: TokenType,
    line: usize,
    col: usize,

    /// Create a new Token
    fn init(value: []const u8, token_type: TokenType, line: u32, col: u32) Token {
        return .{
            .value = value,
            .token_type = token_type,
            .line = line,
            .col = col,
        };
    }

    /// Return a string representation of the token
    pub fn string(self: Token, allocator: std.mem.Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "[{s}] {s} ({d}, {d})", .{
            @tagName(self.token_type),
            self.value,
            self.line,
            self.col,
        }) catch self.value;
    }
};

/// The type of a token
pub const TokenType = enum {
    // Single-char operators
    op_hash, // #
    op_dollar, // $
    op_left_paren, // (
    op_right_paren, // )
    op_left_bracket, // [
    op_right_bracket, // ]
    op_left_brace, // {
    op_right_brace, // }
    op_comma, // ,
    op_question, // ?
    op_underscore, // _
    op_semicolon, // ;
    op_dot, // .

    // Single or double-char operators by initial char
    op_bang, // !
    op_bang_equals, // !=
    op_percent, // %
    op_percent_equals, // %=
    op_and, // &
    op_and_and, // &&
    op_and_equals, // &=
    op_star, // *
    op_star_equals, // *=
    op_plus, // +
    op_plus_equals, // +=
    op_minus, // -
    op_minus_equals, // -=
    op_right_arrow, // ->
    op_slash, // /
    op_slash_equals, // /=
    op_comment, // //
    op_colon, // :
    op_colon_colon, // ::
    op_equals, // =
    op_equals_equals, // ==
    op_caret, // ^
    op_caret_equals, // ^=
    op_pipe, // |
    op_pipe_equals, // |=
    op_pipe_pipe, // ||
    op_tilde, // ~
    op_tilde_equals, // ~=

    // Single, double, or triple-char operators by initial char
    op_left_angle, // <
    op_left_shift, // <<
    op_less_or_equals, // <=
    op_left_shift_equals, // <<=
    op_right_angle, // >
    op_greater_or_equals, // >=
    op_right_shift, // >>
    op_right_shift_equals, // >>=

    // Literals
    identifier, // begins with a-zA-Z
    lit_str, // begins with "
    lit_char, // begins with '
    lit_int, // sequence of only 0-9
    lit_float, // sequence of only 0-9 and exactly 1 non-initial, non-final .
    lit_true, // literal 'true'
    lit_false, // literal 'false'

    // Data types
    dt_str,
    dt_char,
    dt_u8,
    dt_u16,
    dt_u32,
    dt_u64,
    dt_uword,
    dt_i8,
    dt_i16,
    dt_i32,
    dt_i64,
    dt_iword,
    dt_f32,
    dt_f64,
    dt_bool,
    dt_void,

    // Control flow
    cf_if,
    cf_else,
    cf_eval,
    cf_loop,
    cf_return,
    cf_continue,
    cf_break,

    // Declarations
    decl_pkg,
    decl_struct,
    decl_var,
    decl_const,
    decl_static,
    decl_dyn,
    decl_mtd,
    decl_own,
    decl_ref,

    // Builtins
    builtin_new,
    builtin_drop,
    builtin_copy,
    builtin_clone,
    builtin_print,

    // Other
    eof, // end of file
};

/// The tokenizer
pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize = 0,
    next: usize = 0,
    cur: u8 = 0,
    line: u32 = 1,
    col: u32 = 0,
    error_count: u32 = 0,

    /// Create a new Tokenizer
    pub fn init(allocator: std.mem.Allocator, input: []const u8) Tokenizer {
        var tokenizer: Tokenizer = .{
            .allocator = allocator,
            .input = input,
        };

        tokenizer.readChar();
        return tokenizer;
    }

    /// Parse the source code into tokens
    pub fn tokenize(self: *Tokenizer) ![]Token {
        var tokens: std.ArrayList(Token) = .empty;
        var token: Token = undefined;

        // Scan tokens
        while (token.token_type != .eof) : (try tokens.append(self.allocator, token))
            token = self.nextToken();

        // Report errors
        if (tokens.items.len == 0) {
            log.err("No source code provided", .{});
            return TokenizerError.NoSourceCode;
        }

        if (self.error_count > 0) {
            const s = if (self.error_count > 1) "s" else "";
            log.err("{d} syntax error{s} encountered", .{
                self.error_count,
                s,
            });
            return TokenizerError.SyntaxError;
        }

        return tokens.items;
    }

    /// Get the next Token
    fn nextToken(self: *Tokenizer) Token {
        const empty_token = Token.init("", .eof, self.line, self.col);
        self.skipWhitespace();

        // Reached end of input, return the empty token
        if (self.cur == 0) return empty_token;

        // Scan tokens based on the type of initial char
        // ---------------------------------------------

        // Scanning an identifier
        if (isLetter(self.cur) or (self.cur == '_' and
            self.next < self.input.len and
            isAlnum(self.input[self.next]))) return self.readIdentifier();

        // Scanning a number
        if (isDigit(self.cur)) return self.readNumber();

        // Scanning a string or char literal
        if (isQuote(self.cur)) return self.readQuote();

        // Scanning an operator
        if (operator_token_types.get(&[_]u8{self.cur})) |op| return self.readOperator(op);

        // Scanned an unrecognized token
        log.err("Unrecognized character '{}' on line {} col {}", .{
            self.cur,
            self.line,
            self.col,
        });

        self.error_count += 1;
        self.readChar();
        return empty_token;
    }

    /// Create a token with the given parameters
    fn createToken(self: Tokenizer, token_type: TokenType, value: []const u8) Token {
        // If we're creating a token enclosed in quotes, subtract the quote positions from the token's location
        var col_offs: u32 = @intCast(value.len);
        if (token_type == .lit_str or token_type == .lit_char) col_offs += 2;

        return Token.init(value, token_type, self.line, self.col - col_offs);
    }

    /// Read over whitespace
    fn skipWhitespace(self: *Tokenizer) void {
        while (isWhitespace(self.cur)) : (self.readChar()) {
            if (self.cur != '\n') continue;
            self.line += 1;
            self.col = 0;
        }
    }

    /// Read the character at the next position, then advance the position
    fn readChar(self: *Tokenizer) void {
        if (self.next >= self.input.len) {
            // End of input
            self.cur = 0;
        } else {
            self.cur = self.input[self.next];
        }

        self.pos = self.next;
        self.next += 1;
        self.col += 1;
    }

    /// Read an identifier
    fn readIdentifier(self: *Tokenizer) Token {
        const start = self.pos;
        while (isAlnum(self.cur)) self.readChar();

        const buffer = self.input[start..self.pos];
        return self.createToken(keyword_token_types.get(buffer) orelse .identifier, buffer);
    }

    /// Read a number
    fn readNumber(self: *Tokenizer) Token {
        const start = self.pos;
        var token_type: TokenType = .lit_int;

        while (isDigit(self.cur)) {
            self.readChar();

            // If we encounter a dot, we should only keep reading if the follow char is a digit
            if (self.cur == '.' and self.next < self.input.len and isDigit(self.input[self.next])) {
                token_type = .lit_float;
                self.readChar();
            }
        }

        return self.createToken(token_type, self.input[start..self.pos]);
    }

    /// Read a quote; scans until the closing quote is found.
    /// If it scans until EOF without finding a close, we have an error
    fn readQuote(self: *Tokenizer) Token {
        const quote = self.cur;
        const line = self.line;
        const col = self.col;
        const token_type: TokenType = if (quote == '\'') .lit_char else .lit_str;

        self.readChar();
        const start = self.pos;
        var closed = true;
        var num_lines: u32 = 0;

        // Look back 2 chars to check if we're escaping the next char. Account for escaped backslash
        var last1: u8 = 0;
        var last2: u8 = 0;

        while (self.cur != quote or (last1 == '\\' and last2 != '\\')) {
            last2 = last1;
            last1 = self.cur;
            self.readChar();

            // Allow multiline strings
            if (self.cur == '\n') num_lines += 1;

            // If we get to the end of the file without closing the string, log an error
            if (self.cur == 0) {
                log.err("Unclosed {c} quote on line {d} col {d}", .{
                    quote,
                    line,
                    col,
                });

                self.error_count += 1;
                closed = false;
                break;
            }
        }

        const end = @min(self.pos, self.input.len);
        const buffer = self.input[start..end];

        // If we've read a char literal, check if it is valid
        if (closed and quote == '\'' and !isValidChar(buffer)) {
            log.err("Invalid char literal '{s}' on line {d} col {d}", .{
                buffer,
                line,
                col,
            });
            self.error_count += 1;
        }

        // Adjust line and col to account for the number of lines we read
        self.readChar();
        self.line += num_lines;
        if (num_lines > 0) self.col = 0;

        return self.createToken(token_type, buffer);
    }

    /// Read an operator; an operator can be 1, 2, or 3 chars long
    fn readOperator(self: *Tokenizer, base_type: TokenType) Token {
        var token_type = base_type;
        var buffer: []const u8 = &[_]u8{self.cur};
        var to_scan: usize = 0;

        // Check up to the 3 chars from the current position
        for (1..4) |i| {
            const offs = 4 - i;

            if (self.pos + offs <= self.input.len) {
                const op = self.input[self.pos .. self.pos + offs];

                if (operator_token_types.get(op)) |op_type| {
                    token_type = op_type;
                    buffer = op;
                    to_scan += offs;
                    break;
                }
            }
        }

        // Catch up the internal position pointer
        for (0..to_scan) |_| self.readChar();

        // If this operator was the comment opener, read the comment
        if (token_type == .op_comment) {
            const start = self.pos;
            while (self.cur != '\n' and self.cur != 0) self.readChar();
            buffer = self.input[start..self.pos];
        }

        return self.createToken(token_type, buffer);
    }
};

// Scanning utils
// --------------

/// Utility function to tell us if a char is whitespace
fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n' or char == '\r' or char == '\t';
}

/// Utility function to tell us if a char is a letter
fn isLetter(char: u8) bool {
    return ('a' <= char and char <= 'z') or ('A' <= char and char <= 'Z');
}

/// Utility function to tell us if a char is a digit
fn isDigit(char: u8) bool {
    return '0' <= char and char <= '9';
}

/// Utility function to tell us if a char is alphanumeric (including underscores)
fn isAlnum(char: u8) bool {
    return char == '_' or isLetter(char) or isDigit(char);
}

/// Utility function to tell us if a char is a quotation mark
fn isQuote(char: u8) bool {
    return char == '"' or char == '`' or char == '\'';
}

/// Utility function to tell us if a string is a valid char literal
fn isValidChar(lit: []const u8) bool {
    if (lit.len == 1 and unescaped_chars.get(lit) == null) return true;
    return isValidUnicodePoint(lit) or valid_escaped_chars.get(lit) != null;
}

/// Utility function to tell us if a literal is a valid unicode point
fn isValidUnicodePoint(lit: []const u8) bool {
    if (!std.mem.startsWith(u8, lit, "\\u") or lit.len == 2 or lit.len > 10) return false;

    // Each digit past the first 2 must be a valid hexadecimal digit
    for (lit[2..]) |char| {
        if (!((char >= '0' and char <= '9') or
            (char >= 'A' and char <= 'F') or
            (char >= 'a' and char <= 'f'))) return false;
    }

    return true;
}

// Lookup Tables
// -------------------------------------------------

/// Valid string literal representations of escaped characters
const valid_escaped_chars = std.StaticStringMap(void).initComptime(.{
    .{ "\\\\", {} }, // Backslash
    .{ "\\a", {} }, // Alert
    .{ "\\b", {} }, // Backspace
    .{ "\\f", {} }, // Page break (form feed)
    .{ "\\n", {} }, // Newline (line feed)
    .{ "\\r", {} }, // Carriage return
    .{ "\\t", {} }, // Horizontal tab
    .{ "\\v", {} }, // Vertical tab
    .{ "\\'", {} }, // Single quote
    .{ "\\0", {} }, // Null char
});

/// Literal escaped characters
const unescaped_chars = std.StaticStringMap(void).initComptime(.{
    .{ "\\", {} }, // Backslash
    .{ "\n", {} }, // Newline (line feed)
    .{ "\r", {} }, // Carriage return
    .{ "\t", {} }, // Horizontal tab
    .{ "\'", {} }, // Single quote
});

/// Operator token types
const operator_token_types = std.StaticStringMap(TokenType).initComptime(.{
    // Single char
    .{ "#", .op_hash },
    .{ "$", .op_dollar },
    .{ "(", .op_left_paren },
    .{ ")", .op_right_paren },
    .{ "[", .op_left_bracket },
    .{ "]", .op_right_bracket },
    .{ "{", .op_left_brace },
    .{ "}", .op_right_brace },
    .{ ",", .op_comma },
    .{ "?", .op_question },
    .{ "_", .op_underscore },
    .{ ";", .op_semicolon },
    .{ ".", .op_dot },

    // Single and double-char
    .{ "~=", .op_tilde_equals },
    .{ "~", .op_tilde },
    .{ "|=", .op_pipe_equals },
    .{ "||", .op_pipe_pipe },
    .{ "|", .op_pipe },
    .{ "^=", .op_caret_equals },
    .{ "^", .op_caret },
    .{ "==", .op_equals_equals },
    .{ "=", .op_equals },
    .{ "::", .op_colon_colon },
    .{ ":", .op_colon },
    .{ "/=", .op_slash_equals },
    .{ "/", .op_slash },
    .{ "//", .op_comment },
    .{ "->", .op_right_arrow },
    .{ "-=", .op_minus_equals },
    .{ "-", .op_minus },
    .{ "+=", .op_plus_equals },
    .{ "+", .op_plus },
    .{ "*=", .op_star_equals },
    .{ "*", .op_star },
    .{ "&=", .op_and_equals },
    .{ "&&", .op_and_and },
    .{ "&", .op_and },
    .{ "%=", .op_percent_equals },
    .{ "%", .op_percent },
    .{ "!=", .op_bang_equals },
    .{ "!", .op_bang },

    // Single, double and triple-char
    .{ "<<=", .op_left_shift_equals },
    .{ "<<", .op_left_shift },
    .{ "<=", .op_less_or_equals },
    .{ "<", .op_left_angle },
    .{ ">>=", .op_right_shift_equals },
    .{ ">>", .op_right_shift },
    .{ ">=", .op_greater_or_equals },
    .{ ">", .op_right_angle },
});

/// Keyword token types
const keyword_token_types = std.StaticStringMap(TokenType).initComptime(.{
    // Control flow
    .{ "if", .cf_if },
    .{ "else", .cf_else },
    .{ "eval", .cf_eval },
    .{ "loop", .cf_loop },
    .{ "return", .cf_return },
    .{ "continue", .cf_continue },
    .{ "break", .cf_break },

    // Declaration
    .{ "pkg", .decl_pkg },
    .{ "struct", .decl_struct },
    .{ "var", .decl_var },
    .{ "const", .decl_const },
    .{ "static", .decl_static },
    .{ "dyn", .decl_dyn },
    .{ "mtd", .decl_mtd },
    .{ "own", .decl_own },
    .{ "ref", .decl_ref },

    // Builtin
    .{ "new", .builtin_new },
    .{ "drop", .builtin_drop },
    .{ "copy", .builtin_copy },
    .{ "clone", .builtin_clone },
    .{ "print", .builtin_print },
});
