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
const option_ast: cmd.Option = .{
    .long = "ast",
    .short = 'a',
    .description = "Output abstract syntax tree",
    .data_type = .flag,
};
const option_out: cmd.Option = .{
    .long = "out",
    .short = 'o',
    .description = "Output file name, default is module name",
    .data_type = .string,
};
const option_tokens: cmd.Option = .{
    .long = "tokens",
    .short = 't',
    .description = "Output token stream",
    .data_type = .flag,
};
const option_verbose: cmd.Option = .{
    .long = "verbose",
    .short = 'v',
    .description = "Enable verbose logging",
    .data_type = .flag,
};
const cmd_options = [_]cmd.Option{
    option_ast,
    option_out,
    option_tokens,
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
    core.build(allocator, .{
        .output_tokens = cmd.cmd_options.contains(option_tokens.long),
        .output_ast = cmd.cmd_options.contains(option_ast.long),
    }) catch |err| {
        const msg = "Could not build module";
        return std.fmt.allocPrint(allocator, msg ++ ": {any}", .{err}) catch msg;
    };

    const same_name = std.mem.eql(u8, mod.name, outfile);
    const arrow = if (same_name) "" else " -> ";
    const suffix = if (same_name) "" else outfile;
    log.success("Built {s}{s}{s}", .{
        mod.name,
        arrow,
        suffix,
    });

    return null;
}
