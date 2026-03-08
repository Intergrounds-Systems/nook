const cmd = @import("cmd.zig");
const meta = @import("meta");
const std = @import("std");

/// Command to display the Nook version
pub const command: cmd.Command = .{
    .name = "version",
    .description = "Display the Nook version",
    .callback = run,
};

/// Register the version comand
pub fn register(allocator: std.mem.Allocator) !void {
    try cmd.commands.append(allocator, command);
}

/// Callback for the version command
fn run(_: *std.ArrayList(cmd.Value), _: *std.StringHashMapUnmanaged(cmd.Value)) ?[]const u8 {
    std.debug.print("{s} v{s}\n", .{ meta.name, meta.version });
    return null;
}
