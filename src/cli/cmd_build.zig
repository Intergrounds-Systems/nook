const cmd = @import("cmd.zig");
const core = @import("core");
const log = @import("log");
const module = @import("module");
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
fn run(allocator: std.mem.Allocator) ?[]const u8 {
    // Configure logger
    log.setVerbose(cmd.cmd_options.contains(option_verbose.long));

    // Load the module
    const mod = module.load(allocator) catch |err| {
        const msg = "Could not load module";
        return std.fmt.allocPrint(allocator, msg ++ ": {any}", .{err}) catch msg;
    };

    // Determine output file
    var outfile = mod.name;
    if (cmd.cmd_options.get(option_out.long)) |value| {
        outfile = value.string;
    }

    log.info("Building {s} v{s}", .{
        mod.name,
        mod.version,
    });

    // Start the build
    core.build(allocator, "main.nk") catch |err| {
        const msg = "Could not build module";
        return std.fmt.allocPrint(allocator, msg ++ ": {any}", .{err}) catch msg;
    };

    log.success("Built {s} -> {s}", .{
        mod.name,
        outfile,
    });
    return null;
}
