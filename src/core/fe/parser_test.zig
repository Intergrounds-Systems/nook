const fe = @import("root.zig");
const log = @import("log");
const std = @import("std");
const types = @import("types");

const testing = std.testing;

/// Parse source and render every statement, one per line
fn render(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    const tokens = try fe.tokenize(allocator, source);
    const ast = try fe.parse(allocator, tokens);

    var out: []const u8 = "";
    for (ast.items, 0..) |stmt, i| {
        out = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
            out,
            stmt.string(allocator),
            if (i < ast.items.len - 1) "\n" else "",
        });
    }

    return out;
}

/// Assert that a source fragment parses to exactly the given rendering
fn expectAst(source: []const u8, expected: []const u8) !void {
    log.setQuiet(true);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectEqualStrings(expected, try render(arena.allocator(), source));
}

/// Assert that a source fragment fails to parse
fn expectParseError(source: []const u8) !void {
    log.setQuiet(true);
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.ParseFailed, render(arena.allocator(), source));
}

// Declarations
// ------------

test "package declaration" {
    try expectAst("pkg main;", "<package> main");
}

test "symbol kinds" {
    try expectAst("var x = 1;", "<symbol> var x: (inferred) = [literal: [val_int: 1]]");
    try expectAst("const x = 1;", "<symbol> const x: (inferred) = [literal: [val_int: 1]]");
    try expectAst("static x = 1;", "<symbol> static x: (inferred) = [literal: [val_int: 1]]");
}

test "declaration without initializer requires an annotation slot" {
    try expectAst("var x: u32;", "<symbol> var x: u32");
}

test "declaration errors" {
    try expectParseError("var 1 = 2;"); // identifier required
    try expectParseError("var x = 1"); // missing terminator
    try expectParseError("var x: 9;"); // not a type
}

// Type annotations
// ----------------

test "named and pointer types" {
    try expectAst("var a: str;", "<symbol> var a: str");
    try expectAst("var a: MyStruct;", "<symbol> var a: MyStruct");
    try expectAst("var a: own<i8>;", "<symbol> var a: own<i8>");
    try expectAst("var a: ref<i64>;", "<symbol> var a: ref<i64>");
}

test "pointer types nest, closing through a shift token" {
    try expectAst("var a: own<ref<i8>>;", "<symbol> var a: own<ref<i8>>");
    try expectAst("var a: own<own<own<str>>>;", "<symbol> var a: own<own<own<str>>>");
}

test "function types" {
    try expectAst("var f: func<(f64, f64) -> f64>;", "<symbol> var f: func<(f64, f64) -> f64>");
    try expectAst("var f: func<() -> void>;", "<symbol> var f: func<() -> void>");
    try expectAst(
        "var f: func<(f64) -> func<(f64) -> f64>>;",
        "<symbol> var f: func<(f64) -> func<(f64) -> f64>>",
    );
    try expectAst("var f: own<func<() -> void>>;", "<symbol> var f: own<func<() -> void>>");
}

test "function type errors" {
    try expectParseError("var f: func<f64 -> f64>;"); // missing parens
    try expectParseError("var f: func<(f64)>;"); // missing arrow
    try expectParseError("var f: func;"); // missing angle
}

// Expression precedence
// ---------------------

test "arithmetic precedence" {
    try expectAst(
        "1 + 2 * 3;",
        "<expression> [binary: [literal: [val_int: 1]] + [binary: [literal: [val_int: 2]] * [literal: [val_int: 3]]]]",
    );
}

test "bitwise binds tighter than comparison, unlike C" {
    try expectAst(
        "a & b == c;",
        "<expression> [binary: [binary: [variable: a] & [variable: b]] == [variable: c]]",
    );
}

test "logical operators are looser than equality" {
    try expectAst(
        "x || y && z;",
        "<expression> [logical: [variable: x] || [logical: [variable: y] && [variable: z]]]",
    );
}

test "exponent is right associative" {
    try expectAst(
        "2 ** 3 ** 2;",
        "<expression> [binary: [literal: [val_int: 2]] ** [binary: [literal: [val_int: 3]] ** [literal: [val_int: 2]]]]",
    );
}

test "unary minus is looser than exponent on the left" {
    // -2 ** 2 is -(2 ** 2), matching Python
    try expectAst(
        "-2 ** 2;",
        "<expression> [unary: -[binary: [literal: [val_int: 2]] ** [literal: [val_int: 2]]]]",
    );
}

test "unary binds tighter than exponent on the right" {
    try expectAst(
        "2 ** -1;",
        "<expression> [binary: [literal: [val_int: 2]] ** [unary: -[literal: [val_int: 1]]]]",
    );
}

test "pointer operators bind tighter than exponent" {
    try expectAst(
        "$p ** 2;",
        "<expression> [binary: [unary: $[variable: p]] ** [literal: [val_int: 2]]]",
    );
}

test "grouping overrides precedence" {
    try expectAst(
        "(1 + 2) * 3;",
        "<expression> [binary: [grouping: ([binary: [literal: [val_int: 1]] + [literal: [val_int: 2]]])] * [literal: [val_int: 3]]]",
    );
}

// Construction
// ------------

test "named construction" {
    try expectAst(
        "Foo{ a: 1 };",
        "<expression> [construct: Foo{a: [literal: [val_int: 1]]}]",
    );
}

test "positional construction" {
    try expectAst(
        "Foo{ 1, 2 };",
        "<expression> [construct: Foo{[literal: [val_int: 1]], [literal: [val_int: 2]]}]",
    );
}

test "empty construction and trailing commas" {
    try expectAst("Foo{};", "<expression> [construct: Foo{}]");
    try expectAst("Foo{ a: 1, };", "<expression> [construct: Foo{a: [literal: [val_int: 1]]}]");
}

test "construction nests" {
    try expectAst(
        "A{ b: B{ c: 1 } };",
        "<expression> [construct: A{b: [construct: B{c: [literal: [val_int: 1]]}]}]",
    );
}

test "a bare identifier is still a variable, not a construction" {
    try expectAst("user;", "<expression> [variable: user]");
}

// Postfix
// -------

test "calls and field access chain left to right" {
    try expectAst("foo();", "<expression> [call: [variable: foo]()]");
    try expectAst("a.b;", "<expression> [get: [variable: a].b]");
    try expectAst(
        "a.b(1).c;",
        "<expression> [get: [call: [get: [variable: a].b]([literal: [val_int: 1]])].c]",
    );
}

test "implicit self member access" {
    try expectAst(".name;", "<expression> [get: .name]");
    try expectAst(".name.other;", "<expression> [get: [get: .name].other]");
    try expectAst(".method();", "<expression> [call: [get: .method]()]");
}

test "postfix errors" {
    try expectParseError("a.;");
    try expectParseError("foo(1;");
}

// Statements
// ----------

test "assignment targets" {
    try expectAst("x = 5;", "<assignment> [variable: x] = [literal: [val_int: 5]]");
    try expectAst("a.b = 5;", "<assignment> [get: [variable: a].b] = [literal: [val_int: 5]]");
    try expectAst("x **= 2;", "<assignment> [variable: x] **= [literal: [val_int: 2]]");
}

test "invalid assignment targets are rejected" {
    try expectParseError("5 = 1;");
    try expectParseError("foo() = 1;");
    try expectParseError("x = y = 1;"); // no chaining
}

test "builtin statements" {
    try expectAst("print \"hi\";", "<builtin_print> [literal: [val_str: hi]]");
    try expectAst("drop user;", "<builtin_drop> [variable: user]");
}

test "builtins that produce values are expressions" {
    try expectAst("clone user;", "<expression> [unary: clone[variable: user]]");
    try expectAst("copy user;", "<expression> [unary: copy[variable: user]]");
}

test "jumps" {
    try expectAst("return;", "<jump> return");
    try expectAst("return 5;", "<jump> return ([literal: [val_int: 5]])");
    try expectAst("break;", "<jump> break");
    try expectAst("continue;", "<jump> continue");
    try expectParseError("return 5");
    try expectParseError("break 5;");
}

// Blocks and control flow
// -----------------------

test "blocks" {
    try expectAst("{ }", "<block> {\n\n}");
    try expectAst(
        "{ x = 1; }",
        "<block> {\n\t<assignment> [variable: x] = [literal: [val_int: 1]]\n}",
    );
}

test "blocks nest and indent cumulatively" {
    try expectAst(
        "{ { x = 1; } }",
        "<block> {\n\t<block> {\n\t\t<assignment> [variable: x] = [literal: [val_int: 1]]\n\t}\n}",
    );
}

test "conditionals" {
    try expectAst("if (x) { }", "<conditional> if ([variable: x]) <block> {\n\n}");
    try expectAst(
        "if (x) { } else { }",
        "<conditional> if ([variable: x]) <block> {\n\n} else <block> {\n\n}",
    );
}

test "loops share the conditional node, tagged by keyword" {
    try expectAst("loop (x) { }", "<conditional> loop ([variable: x]) <block> {\n\n}");
}

test "if and loop mix in one else chain" {
    try expectAst(
        "if (x) { } else loop (y) { }",
        "<conditional> if ([variable: x]) <block> {\n\n} else <conditional> loop ([variable: y]) <block> {\n\n}",
    );
}

test "control flow requires parens and braces" {
    try expectParseError("if x { }");
    try expectParseError("if (x) y = 1;");
    try expectParseError("loop x { }");
}

test "one syntax error inside a block does not cascade" {
    // Recovery must leave the closing brace for the enclosing block
    try expectParseError("{ x = 1 }");
    try expectParseError("{ { x = 1 } }");
}

// Functions
// ---------

test "function literals" {
    try expectAst(
        "var f = () -> void { }",
        "<symbol> var f: (inferred) = [func: () -> void: <block> {\n\n}]",
    );
    try expectAst(
        "var f = (a: f64) -> f64 { return a; }",
        "<symbol> var f: (inferred) = [func: (a: f64) -> f64: <block> {\n\t<jump> return ([variable: a])\n}]",
    );
}

test "parenthesized expressions are still groupings" {
    try expectAst(
        "var z = (1 + 2) * 3;",
        "<symbol> var z: (inferred) = [binary: [grouping: ([binary: [literal: [val_int: 1]] + [literal: [val_int: 2]]])] * [literal: [val_int: 3]]]",
    );
    try expectAst("var z = (a);", "<symbol> var z: (inferred) = [grouping: ([variable: a])]");
}

test "function literal errors" {
    try expectParseError("var f = () -> void;"); // body required
    try expectParseError("var f = (a: f64) f64 { };"); // arrow required
}

// Terminators
// -----------

test "brace-bodied declarations take no terminator" {
    try expectAst(
        "const f = () -> void { }",
        "<symbol> const f: (inferred) = [func: () -> void: <block> {\n\n}]",
    );
    try expectParseError("const f = () -> void { };");
}

test "construction is an expression and still needs a terminator" {
    try expectParseError("var p = Foo{ a: 1 }");
}

// Structs
// -------

test "struct declarations take no terminator" {
    try expectAst(
        "struct Point { var x: u32; }",
        "<structure> Point: <block> {\n\t<symbol> var x: u32\n}",
    );
    try expectParseError("struct Point { };");
}

test "struct members cover fields and all three method kinds" {
    try expectAst(
        "struct P { var a: u32; const f = () -> void { } static g = () -> void { } }",
        "<structure> P: <block> {" ++
            "\n\t<symbol> var a: u32" ++
            "\n\t<symbol> const f: (inferred) = [func: () -> void: <block> {\n\t\n\t}]" ++
            "\n\t<symbol> static g: (inferred) = [func: () -> void: <block> {\n\t\n\t}]" ++
            "\n}",
    );
}
