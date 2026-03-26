const fe = @import("fe/root.zig");
const log = @import("log");
const types = @import("types");
const std = @import("std");

/// Options for the build
pub const BuildOptions = struct {
    path: []const u8 = "main.nk",
    output_tokens: bool = false,
    output_ast: bool = false,
};

/// Build a Nook project from the given root source file
pub fn build(allocator: std.mem.Allocator, build_options: BuildOptions) !void {
    log.debug("Opening '{s}'...", .{build_options.path});
    var file = try std.fs.cwd().openFile(build_options.path, .{});
    defer file.close();

    // Read the file into a source code buffer
    log.debug("Reading file contents...", .{});
    const stat = try file.stat();
    const n = @as(usize, stat.size);
    const buffer = try allocator.alloc(u8, n);
    var reader = file.reader(buffer);
    const source_code = try reader.interface.readAlloc(allocator, n);

    // Tokenize the source code
    log.debug("Tokenizing source code...", .{});
    const tokens = try fe.tokenize(allocator, source_code[0..n]);
    defer reportTokens(allocator, tokens, build_options.output_tokens);

    // Parse the tokens into an AST
    log.debug("Parsing tokens...", .{});
    const ast = try fe.parse(allocator, tokens);
    defer reportAST(allocator, ast.items, build_options.output_ast);
}

/// Print out the token stream
fn reportTokens(allocator: std.mem.Allocator, tokens: []types.Token, report: bool) void {
    if (!report) return;

    std.debug.print("\nToken Stream:\n", .{});
    for (tokens) |token| {
        std.debug.print("{s}\n", .{token.string(allocator)});
    }
    std.debug.print("\n", .{});
}

/// Print out the abstract syntax tree
fn reportAST(allocator: std.mem.Allocator, ast: []*types.Stmt, report: bool) void {
    if (!report) return;

    std.debug.print("\nAbstract Syntax Tree:\n", .{});
    for (ast) |stmt| {
        std.debug.print("{s}\n", .{stmt.string(allocator)});
    }
    std.debug.print("\n", .{});
}
