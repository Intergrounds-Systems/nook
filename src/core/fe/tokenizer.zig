const log = @import("log");
const std = @import("std");

/// Tokenizer errors
const TokenizerError = error{ NoSourceCode, SyntaxError };

/// Tokenize the input source code
pub fn tokenize(allocator: std.mem.Allocator, source_code: []const u8) ![]Token {
    var tokenizer = Tokenizer.init(allocator, source_code);
    var tokens: std.ArrayList(Token) = .empty;
    var token: Token = undefined;

    // Scan tokens
    while (token.token_type != .EOF) : (try tokens.append(allocator, token))
        token = tokenizer.nextToken();

    // Report errors
    if (tokens.items.len == 0) {
        log.err("No source code provided", .{});
        return TokenizerError.NoSourceCode;
    }

    if (tokenizer.error_count > 0) {
        const s = if (tokenizer.error_count > 1) "s" else "";
        log.err("{d} syntax error{s} encountered", .{
            tokenizer.error_count,
            s,
        });
        return TokenizerError.SyntaxError;
    }
    
    return tokens.items;
}

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
    // Single-char tokens
    Hash,         // #
    Dollar,       // $
    LeftParen,    // (
    RightParen,   // )
    LeftBracket,  // [
    RightBracket, // ]
    LeftBrace,    // {
    RightBrace,   // }
    Comma,        // ,
    Question,     // ?
    Underscore,   // _
    Semicolon,    // ;
    Dot,          // .
    
    // Single or double-char tokens by initial char
    Bang,          // !
    BangEquals,    // !=
    Percent,       // %
    PercentEquals, // %=
    And,           // &
    AndAnd,        // &&
    AndEquals,     // &=
    Star,          // *
    StarEquals,    // *=
    Plus,          // +
    PlusEquals,    // +=
    Minus,         // -
    MinusEquals,   // -=
    RightArrow,    // ->
    Slash,         // /
    SlashEquals,   // /=
    Comment,       // //
    Colon,         // :
    ColonColon,    // ::
    Equals,        // =
    EqualsEquals,  // ==
    Caret,         // ^
    CaretEquals,   // ^=
    Pipe,          // |
    PipeEquals,    // |=
    PipePipe,      // ||
    Tilde,         // ~
    TildeEquals,   // ~=

    // Single, double, or triple-char tokens by initial char
    LeftAngle,        // <
    LeftShift,        // <<
    LessOrEquals,     // <=
    LeftShiftEquals,  // <<=
    RightAngle,       // >
    GreaterOrEquals,  // >=
    RightShift,       // >>
    RightShiftEquals, // >>=

    // Literals
    Identifier, // begins with a-zA-Z
    String,     // begins with "
    Char,       // begins with '
    Int,        // sequence of only 0-9
    Float,      // sequence of only 0-9 and exactly 1 non-initial, non-final .
    True,       // literal 'true'
    False,      // literal 'false'
    Void,       // literal 'void'

    // Keywords
    // Flow control
    If,
    Else,
    Eval,
    Loop,
    Return,
    Continue,
    Break,

    // Declarations
    Pkg,
    Struct,
    Var,
    Const,
    Static,
    Dyn,
    Mtd,
    Own,
    Ref,

    // Builtins
    New,
    Drop,
    Copy,
    Clone,
    Print,

    // Other
    EOF, // end of file
};

/// The tokenizer
const Tokenizer = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize = 0,
    next: usize = 0,
    cur: u8 = 0,
    line: u32 = 1,
    col: u32 = 0,
    error_count: u32 = 0,

    /// Create a new Tokenizer
    fn init(allocator: std.mem.Allocator, input: []const u8) Tokenizer {
        var tokenizer: Tokenizer = .{
            .allocator = allocator,
            .input = input,
        };

        tokenizer.readChar();
        return tokenizer;
    }

    /// Get the next Token
    fn nextToken(self: *Tokenizer) Token {
        const empty_token = Token.init("", .EOF, self.line, self.col);
        self.skipWhitespace();

        // Reached end of input, return the empty token
        if (self.cur == 0) return empty_token;

        // Scan tokens based on the type of initial char
        // ---------------------------------------------

        // Scanning an identifier
        if (
            isLetter(self.cur) or (
                self.cur == '_' and
                self.next < self.input.len and
                isAlnum(self.input[self.next])
            )
        ) return self.readIdentifier();

        // Scanning a number
        if (isDigit(self.cur)) return self.readNumber();

        // Scanning a string or char literal
        if (isQuote(self.cur)) return self.readQuote();

        // Scanning an operator
        if (parseOp(&[_]u8{self.cur})) |op| return self.readOperator(op);

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
        if (token_type == .String or token_type == .Char) col_offs += 2;

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
        return self.createToken(parseKeyword(buffer), buffer);
    }

    /// Read a number
    fn readNumber(self: *Tokenizer) Token {
        const start = self.pos;
        var token_type: TokenType = .Int;

        while (isDigit(self.cur)) {
            self.readChar();

            // If we encounter a dot, we should only keep reading if the follow char is a digit
            if (self.cur == '.' and self.next < self.input.len and isDigit(self.input[self.next])) {
                token_type = .Float;
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
        const token_type: TokenType = if (quote == '\'') .Char else .String;

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
        if(num_lines > 0) self.col = 0;

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
                const op = self.input[self.pos..self.pos + offs];

                if (parseOp(op)) |op_type| {
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
        if (token_type == .Comment) {
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
fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\r' or c == '\t';
}

/// Utility function to tell us if a char is a letter
fn isLetter(c: u8) bool {
    return ('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z');
}

/// Utility function to tell us if a char is a digit
fn isDigit(c: u8) bool {
    return '0' <= c and c <= '9';
}

/// Utility function to tell us if a char is alphanumeric (including underscores)
fn isAlnum(c: u8) bool {
    return c == '_' or isLetter(c) or isDigit(c);
}

/// Utility function to tell us if a char is a quotation mark
fn isQuote(c: u8) bool {
    return c == '"' or c == '`' or c == '\'';
}

/// Utility function to tell us if a string is a valid char literal
fn isValidChar(c: []const u8) bool {
    if (c.len == 1 and !isUnescapedChar(c)) return true;
    return isValidUnicodePoint(c) or isValidEscapedChar(c);
}

/// Utility function to tell us if a literal is a valid unicode point
fn isValidUnicodePoint(u: []const u8) bool {
    if (!std.mem.startsWith(u8, u, "\\u") or u.len == 2 or u.len > 10) return false;

    // Each digit past the first 2 must be a valid hexadecimal digit
    for (u[2..]) |char| {
        if (!(
                (char >= '0' and char <= '9') or
                (char >= 'A' and char <= 'F') or
                (char >= 'a' and char <= 'f')
            )
        ) return false;
    }

    return true;
}

/// Utility function to tell us if a literal is a valid escape sequence
fn isValidEscapedChar(e: []const u8) bool {
    return std.mem.eql(u8, e, "\\\\") or // Backslash
        std.mem.eql(u8, e, "\\a") or     // Alert
        std.mem.eql(u8, e, "\\b") or     // Backspace
        std.mem.eql(u8, e, "\\f") or     // Page break (form feed)
        std.mem.eql(u8, e, "\\n") or     // Newline (line feed)
        std.mem.eql(u8, e, "\\r") or     // Carriage return
        std.mem.eql(u8, e, "\\t") or     // Horizontal tab
        std.mem.eql(u8, e, "\\v") or     // Vertical tab
        std.mem.eql(u8, e, "\\'") or     // Single quote
        std.mem.eql(u8, e, "\\0");       // Null char
}

/// Utility function to tell us if a literal is an unescaped char
fn isUnescapedChar(c: []const u8) bool {
    return std.mem.eql(u8, c, "\\") or // Backslash
        std.mem.eql(u8, c, "\n") or    // Newline (line feed)
        std.mem.eql(u8, c, "\r") or    // Carriage return
        std.mem.eql(u8, c, "\t") or    // Horizontal tab
        std.mem.eql(u8, c, "\'");      // Single quote
}

/// Parse the string representation of an operator into its TokenType, if applicable
fn parseOp(op: []const u8) ?TokenType {
    // Single char
    if (std.mem.eql(u8, op, "#")) return .Hash;
    if (std.mem.eql(u8, op, "$")) return .Dollar;
    if (std.mem.eql(u8, op, "(")) return .LeftParen;
    if (std.mem.eql(u8, op, ")")) return .RightParen;
    if (std.mem.eql(u8, op, "[")) return .LeftBracket;
    if (std.mem.eql(u8, op, "]")) return .RightBracket;
    if (std.mem.eql(u8, op, "{")) return .LeftBrace;
    if (std.mem.eql(u8, op, "}")) return .RightBrace;
    if (std.mem.eql(u8, op, ",")) return .Comma;
    if (std.mem.eql(u8, op, "?")) return .Question;
    if (std.mem.eql(u8, op, "_")) return .Underscore;
    if (std.mem.eql(u8, op, ";")) return .Semicolon;
    if (std.mem.eql(u8, op, ".")) return .Dot;

    // Single and double-char
    if (std.mem.eql(u8, op, "~=")) return .TildeEquals;
    if (std.mem.eql(u8, op, "~")) return .Tilde;
    if (std.mem.eql(u8, op, "|=")) return .PipeEquals;
    if (std.mem.eql(u8, op, "||")) return .PipePipe;
    if (std.mem.eql(u8, op, "|")) return .Pipe;
    if (std.mem.eql(u8, op, "^=")) return .CaretEquals;
    if (std.mem.eql(u8, op, "^")) return .Caret;
    if (std.mem.eql(u8, op, "==")) return .EqualsEquals;
    if (std.mem.eql(u8, op, "=")) return .Equals;
    if (std.mem.eql(u8, op, "::")) return .ColonColon;
    if (std.mem.eql(u8, op, ":")) return .Colon;
    if (std.mem.eql(u8, op, "/=")) return .SlashEquals;
    if (std.mem.eql(u8, op, "/")) return .Slash;
    if (std.mem.eql(u8, op, "//")) return .Comment;
    if (std.mem.eql(u8, op, "->")) return .RightArrow;
    if (std.mem.eql(u8, op, "-=")) return .MinusEquals;
    if (std.mem.eql(u8, op, "-")) return .Minus;
    if (std.mem.eql(u8, op, "+=")) return .PlusEquals;
    if (std.mem.eql(u8, op, "+")) return .Plus;
    if (std.mem.eql(u8, op, "*=")) return .StarEquals;
    if (std.mem.eql(u8, op, "*")) return .Star;
    if (std.mem.eql(u8, op, "&=")) return .AndEquals;
    if (std.mem.eql(u8, op, "&&")) return .AndAnd;
    if (std.mem.eql(u8, op, "&")) return .And;
    if (std.mem.eql(u8, op, "%=")) return .PercentEquals;
    if (std.mem.eql(u8, op, "%")) return .Percent;
    if (std.mem.eql(u8, op, "!=")) return .BangEquals;
    if (std.mem.eql(u8, op, "!")) return .Bang;

    // Single, double and triple-char
    if (std.mem.eql(u8, op, "<<=")) return .LeftShiftEquals;
    if (std.mem.eql(u8, op, "<<")) return .LeftShift;
    if (std.mem.eql(u8, op, "<=")) return .LessOrEquals;
    if (std.mem.eql(u8, op, "<")) return .LeftAngle;
    if (std.mem.eql(u8, op, ">>=")) return .RightShiftEquals;
    if (std.mem.eql(u8, op, ">>")) return .RightShift;
    if (std.mem.eql(u8, op, ">=")) return .GreaterOrEquals;
    if (std.mem.eql(u8, op, ">")) return .RightAngle;

    return null;
}

/// Parse the string representation of a keywork into its TokenType, if applicable
fn parseKeyword(kw: []const u8) TokenType {
    // Control flow
    if (std.mem.eql(u8, kw, "if")) return .If;
    if (std.mem.eql(u8, kw, "else")) return .Else;
    if (std.mem.eql(u8, kw, "eval")) return .Eval;
    if (std.mem.eql(u8, kw, "loop")) return .Loop;
    if (std.mem.eql(u8, kw, "return")) return .Return;
    if (std.mem.eql(u8, kw, "continue")) return .Continue;
    if (std.mem.eql(u8, kw, "break")) return .Break;

    // Declaration
    if (std.mem.eql(u8, kw, "pkg")) return .Pkg;
    if (std.mem.eql(u8, kw, "struct")) return .Struct;
    if (std.mem.eql(u8, kw, "var")) return .Var;
    if (std.mem.eql(u8, kw, "const")) return .Const;
    if (std.mem.eql(u8, kw, "static")) return .Static;
    if (std.mem.eql(u8, kw, "dyn")) return .Dyn;
    if (std.mem.eql(u8, kw, "mtd")) return .Mtd;
    if (std.mem.eql(u8, kw, "own")) return .Own;
    if (std.mem.eql(u8, kw, "ref")) return .Ref;

    // Builtin
    if (std.mem.eql(u8, kw, "new")) return .New;
    if (std.mem.eql(u8, kw, "drop")) return .Drop;
    if (std.mem.eql(u8, kw, "copy")) return .Copy;
    if (std.mem.eql(u8, kw, "clone")) return .Clone;
    if (std.mem.eql(u8, kw, "print")) return .Print ;

    return .Identifier;
}

