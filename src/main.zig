const cli = @import("cli");
const std = @import("std");

/// Nook toolchain CLI entry point
pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const exit_code = try cli.handle(arena.allocator());
    return exit_code;
}
