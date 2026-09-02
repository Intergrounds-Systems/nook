const fe = @import("root.zig");
const log = @import("log");
const std = @import("std");
const types = @import("types");

const testing = std.testing;

/// Tokenize source and return the token types, excluding the trailing eof
fn typesOf(allocator: std.mem.Allocator, source: []const u8) ![]types.TokenType {
    log.setQuiet(true);
    const tokens = try fe.tokenize(allocator, source);
    const token_types = try allocator.alloc(types.TokenType, tokens.len - 1);
    for (tokens[0 .. tokens.len - 1], 0..) |token, i| token_types[i] = token.token_type;

    return token_types;
}

/// Assert that source tokenizes to exactly the given types
fn expectTypes(source: []const u8, expected: []const types.TokenType) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectEqualSlices(types.TokenType, expected, try typesOf(arena.allocator(), source));
}

/// Assert that source tokenizes to exactly the given values
fn expectValues(source: []const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const tokens = try fe.tokenize(arena.allocator(), source);
    try testing.expectEqual(expected.len, tokens.len - 1);
    for (expected, 0..) |want, i| try testing.expectEqualStrings(want, tokens[i].value);
}

test "empty source yields only eof" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const tokens = try fe.tokenize(arena.allocator(), "");
    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqual(types.TokenType.eof, tokens[0].token_type);
}

test "whitespace only yields only eof" {
    try expectTypes("  \t\n\n  ", &.{});
}

test "integer and float literals" {
    try expectTypes("1 2.5 0 300", &.{ .lit_int, .lit_float, .lit_int, .lit_int });
    try expectValues("1 2.5", &.{ "1", "2.5" });
}

test "string and char literals strip their quotes" {
    try expectTypes("\"hi\" 'c'", &.{ .lit_str, .lit_char });
    try expectValues("\"hi\" 'c'", &.{ "hi", "c" });
}

test "boolean literals are keywords, not identifiers" {
    try expectTypes("true false", &.{ .lit_true, .lit_false });
}

test "declaration keywords" {
    try expectTypes(
        "pkg struct var const static own ref",
        &.{ .decl_pkg, .decl_struct, .decl_var, .decl_const, .decl_static, .ptr_own, .ptr_ref },
    );
}

test "control flow keywords" {
    try expectTypes(
        "if else loop return continue break",
        &.{ .cf_if, .cf_else, .cf_loop, .cf_return, .cf_continue, .cf_break },
    );
}

test "builtin keywords" {
    try expectTypes(
        "new drop copy clone print",
        &.{ .builtin_new, .builtin_drop, .builtin_copy, .builtin_clone, .builtin_print },
    );
}

test "data type keywords" {
    try expectTypes(
        "u8 u16 u32 u64 uword i8 i16 i32 i64 iword f32 f64 char str bool func void",
        &.{
            .dt_u8,   .dt_u16,  .dt_u32,  .dt_u64, .dt_uword,
            .dt_i8,   .dt_i16,  .dt_i32,  .dt_i64, .dt_iword,
            .dt_f32,  .dt_f64,  .dt_char, .dt_str, .dt_bool,
            .dt_func, .dt_void,
        },
    );
}

test "non-keywords are identifiers" {
    try expectTypes("foo Bar _baz qux2", &.{ .identifier, .identifier, .identifier, .identifier });
}

test "keyword prefixes are not keywords" {
    // 'iffy' starts with 'if', 'variable' starts with 'var'
    try expectTypes("iffy variable printer", &.{ .identifier, .identifier, .identifier });
}

test "operators use longest match" {
    try expectTypes("> >= >> >>=", &.{ .op_right_angle, .op_greater_or_equals, .op_right_shift, .op_right_shift_equals });
    try expectTypes("* ** *= **=", &.{ .op_star, .op_star_star, .op_star_equals, .op_star_star_equals });
    try expectTypes(". .. ...", &.{ .op_dot, .op_dot_dot, .op_dot_dot_dot });
    try expectTypes("= == ! != < <=", &.{
        .op_equals,      .op_equals_equals, .op_bang,
        .op_bang_equals, .op_left_angle,    .op_less_or_equals,
    });
    try expectTypes("& && | || ^ ^^", &.{
        .op_and,       .op_and_and, .op_pipe,
        .op_pipe_pipe, .op_caret,   .op_caret_caret,
    });
}

test "adjacent operators without whitespace" {
    try expectTypes("a>>=b", &.{ .identifier, .op_right_shift_equals, .identifier });
    try expectTypes("1+2*3", &.{ .lit_int, .op_plus, .lit_int, .op_star, .lit_int });
}

test "comments become a single comment token" {
    try expectTypes("// a comment", &.{.comment});
    try expectTypes("var // trailing\nvar", &.{ .decl_var, .comment, .decl_var });
}

test "line and column tracking" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const tokens = try fe.tokenize(arena.allocator(), "var a\n  = 1;");
    try testing.expectEqual(@as(usize, 1), tokens[0].line); // var
    try testing.expectEqual(@as(usize, 1), tokens[0].col);
    try testing.expectEqual(@as(usize, 1), tokens[1].line); // a
    try testing.expectEqual(@as(usize, 5), tokens[1].col);
    try testing.expectEqual(@as(usize, 2), tokens[2].line); // =
    try testing.expectEqual(@as(usize, 3), tokens[2].col);
}

test "a realistic declaration" {
    try expectTypes("var x: own<i8> = new i8{ 9 };", &.{
        .decl_var,       .identifier,   .op_colon,       .ptr_own,
        .op_left_angle,  .dt_i8,        .op_right_angle, .op_equals,
        .builtin_new,    .dt_i8,        .op_left_brace,  .lit_int,
        .op_right_brace, .op_semicolon,
    });
}

test "nested pointer types lex the closer as a shift" {
    // The parser splits this back into two '>' via consumeRightAngle
    try expectTypes("own<ref<i8>>", &.{
        .ptr_own,       .op_left_angle, .ptr_ref,
        .op_left_angle, .dt_i8,         .op_right_shift,
    });
}
