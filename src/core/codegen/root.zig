const std = @import("std");
const types = @import("types");

/// Generates C code from the Nook AST
pub fn generate(allocator: std.mem.Allocator, ast: []*types.Stmt, filename: []const u8) anyerror!void {
    // Create the empty C file
    const file = try std.fs.cwd().createFile(
        std.fmt.allocPrint(allocator, "{s}.c", .{filename}) catch "main.c",
        .{},
    );
    defer file.close();

    // Base includes
    _ = try file.write("#include <stdint.h>\n\n");

    // Walk the AST and generate C code from nodes
    for (ast) |node| {
        const c = switch (node.*) {
            inline else => |stmt| stmt.generate(allocator),
        };

        _ = try file.write(c);
    }
}
