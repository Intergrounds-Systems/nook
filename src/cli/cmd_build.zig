const cmd = @import("cmd.zig");
const log = @import("log");
const std = @import("std");

/// Command to build a Nook project
pub const command: cmd.Command = .{
    .name = "build",
    .description = "Build a Nook project",
    .options = &cmd_options,
    .callback = run,
};

/// Options for the build command
const option_out: cmd.Option = .{
    .long = "out",
    .short = 'o',
    .description = "Output file name, default is module name",
    .data_type = .string,
};
const option_verbose: cmd.Option = .{
    .long = "verbose",
    .short = 'v',
    .description = "Enable verbose logging",
    .data_type = .flag,
};
const cmd_options = [_]cmd.Option{
    option_out,
    option_verbose,
    cmd.help_option,
};

/// Register the build comand
pub fn register(allocator: std.mem.Allocator) !void {
    try cmd.commands.append(allocator, command);
}

/// Callback for the build command
fn run(_: *std.ArrayList(cmd.Value), options: *std.StringHashMapUnmanaged(cmd.Value)) ?[]const u8 {
    log.setVerbose(options.contains(option_verbose.long));

    
    
    return null;
}
