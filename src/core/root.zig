const fe = @import("fe/root.zig");
const log = @import("log");
const std = @import("std");

/// Build a Nook project from the given root source file
pub fn build(allocator: std.mem.Allocator, path: []const u8) !void {
    log.debug("Opening '{s}'...", .{path});
    var file = try std.fs.cwd().openFile(path, .{});
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

    // Report tokens
    // TODO: Allow dumping this to a file
    std.debug.print("\n", .{});
    log.debug("------------- Tokens Output -------------:", .{});
    for (tokens) |token| {
        log.debug("{s}", .{token.string(allocator)});
    }

    // Parse the tokens into an AST
    log.debug("Parsing tokens...", .{});
    const ast = try fe.parse(allocator, tokens);

    // Report AST
    // TODO: Allow dumping this to a file
    std.debug.print("\n", .{});
    log.debug("---------- AST Output ----------", .{});
    for (ast.items) |stmt| {
        log.debug("{s}", .{stmt.string(allocator)});
    }
}
