const std = @import("std");

/// An individual semantic unit in the source code
pub const Token = struct {
    value: []const u8,
    token_type: TokenType,
    line: usize,
    col: usize,

    /// Create a new Token
    pub fn init(value: []const u8, token_type: TokenType, line: u32, col: u32) Token {
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

    // Pointer types
    ptr_own,
    ptr_ref,

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

    // Builtins
    builtin_new,
    builtin_drop,
    builtin_copy,
    builtin_clone,
    builtin_print,

    // Other
    comment,
    eof,
};
