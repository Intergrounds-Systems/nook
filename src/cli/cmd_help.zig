const cmd = @import("cmd.zig");
const log = @import("log");
const meta = @import("meta");
const std = @import("std");

/// Command to display Nook CLI help
pub const command: cmd.Command = .{
    .name = "help",
    .description = "Display the Nook CLI help message",
    .callback = run,
};

/// Register the help comand
pub fn register(allocator: std.mem.Allocator) !void {
    try cmd.commands.append(allocator, command);
}

/// Callback for the help command
fn run(_: std.mem.Allocator) ?[]const u8 {
    // TODO: Use a string builder and write to stdout
    // Nook intro
    std.debug.print("{s}\n\n", .{meta.description});

    // Usage
    std.debug.print("{s}USAGE:{s}\n\t{s}{s} {s}[COMMAND] {s}[ARGS] {s}[--OPTIONS]{s}\n\n", .{
        log.BOLD,
        log.RESET,
        log.GREEN,
        meta.name,
        log.BLUE,
        log.YELLOW,
        log.MAGENTA,
        log.RESET,
    });

    // Measure spaces for command description aligment
    var spaces: usize = 0;
    for (cmd.commands.items) |c| {
        if (c.name.len > spaces) spaces = c.name.len;
    }

    // Commands list
    std.debug.print("{s}COMMANDS{s}:\n", .{
        log.BOLD,
        log.RESET,
    });
    for (cmd.commands.items) |c| {
        std.debug.print("\t{s}{s}{s}: ", .{
            log.BLUE,
            c.name,
            log.RESET,
        });

        // Align with spaces
        for (0..spaces - c.name.len) |_| {
            std.debug.print(" ", .{});
        }
        std.debug.print("{s}{s}{s}\n", .{
            log.DIM,
            c.description,
            log.RESET,
        });
    }

    return null;
}
