const cmd = @import("cmd.zig");
const std = @import("std");

/// Command for debugging the CLI
pub const command: cmd.Command = .{
    .name = "debug",
    .description = "Debug the Nook CLI",
    .args = &cmd_args,
    .options = &cmd_options,
    .callback = run,
};

/// Args for the debug command
const cmd_args = [_]cmd.Arg{
    .{
        .name = "foo",
        .description = "A string argument",
        .data_type = .string,
    },
    .{
        .name = "bar",
        .description = "An int argument",
        .data_type = .int,
    },
    .{
        .name = "baz",
        .description = "A bool argument",
        .data_type = .flag,
    },
    .{
        .name = "zap",
        .description = "A float argument",
        .data_type = .float,
    },
};

/// Options for the debug command
const cmd_options = [_]cmd.Option{
    .{
        .long = "string",
        .short = 's',
        .description = "A string option",
        .data_type = .string,
    },
    .{
        .long = "int",
        .short = 'i',
        .description = "An int option",
        .data_type = .int,
    },
    .{
        .long = "bool",
        .short = 'b',
        .description = "A bool/flag option",
        .data_type = .flag,
    },
    .{
        .long = "float",
        .short = 'f',
        .description = "A float option",
        .data_type = .float,
    },
    cmd.help_option,
};

/// Register the debug comand
pub fn register(allocator: std.mem.Allocator) !void {
    try cmd.commands.append(allocator, command);
}

/// Callback for the debug command
fn run(args: *std.ArrayList(cmd.Value), options: *std.StringHashMapUnmanaged(cmd.Value)) ?[]const u8 {
    std.debug.print("Got args:\n", .{});
    for (args.items, 0..) |arg, i| {
        const end = if (i < args.items.len - 1) ", " else "\n";
        std.debug.print("{s}=", .{cmd_args[i].name});
        printValue(arg);
        std.debug.print("{s}", .{end});
    }

    std.debug.print("Got options:\n", .{});
    var it = options.iterator();
    var i: u32 = 0;
    while (it.next()) |option| : (i += 1) {
        const end = if (i < options.size - 1) ", " else "\n";
        std.debug.print("{s}=", .{option.key_ptr.*});
        printValue(option.value_ptr.*);
        std.debug.print("{s}", .{end});
    }

    if (args.items[2].flag) return "Something went wrong";
    return null;
}

fn printValue(value: cmd.Value) void {
    switch (value) {
        .string => |v| std.debug.print("{s}", .{v}),
        .int => |v| std.debug.print("{d}", .{v}),
        .flag => |v| std.debug.print("{any}", .{v}),
        .float => |v| std.debug.print("{d}", .{v}),
    }
}
