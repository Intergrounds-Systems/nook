const cmd = @import("cmd.zig");
const log = @import("log");
const meta = @import("meta");
const module = @import("module");
const std = @import("std");

/// Command to create a new Nook project
pub const command: cmd.Command = .{
    .name = "init",
    .description = "Create a new Nook project",
    .options = &cmd_options,
    .callback = run,
};

/// Options for the init command
const cmd_options = [_]cmd.Option{cmd.help_option};

/// Register the init comand
pub fn register(allocator: std.mem.Allocator) !void {
    try cmd.commands.append(allocator, command);
}

/// Callback for the init command
fn run(allocator: std.mem.Allocator) ?[]const u8 {
    const name = module.init(allocator, meta.version) catch |err| {
        return switch (err) {
            module.ModuleError.AlreadyExists => "A module already exists in this directory",
            else => @errorName(err),
        };
    };

    log.success("Created module '{s}'", .{name});
    return null;
}
