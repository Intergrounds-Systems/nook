const fe = @import("fe/root.zig");
const log = @import("log");
const std = @import("std");

/// Build a Nook project from the given root source file
pub fn build(path: []const u8) !void {
    log.debug("Opening '{s}'...", .{path});
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Read the file into a source code buffer
    log.debug("Reading file contents...", .{});

    // Tokenize the source code
    log.debug("Tokenizing source code...", .{});
    fe.tokenize();

    // Parse the tokens into an AST
    log.debug("Parsing tokens...", .{});
    fe.parse();
}
