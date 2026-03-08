const cmd = @import("cmd.zig");
const log = @import("log");
const std = @import("std");

const cmd_build = @import("cmd_build.zig");
const cmd_debug = @import("cmd_debug.zig");
const cmd_help = @import("cmd_help.zig");
const cmd_init = @import("cmd_init.zig");
const cmd_version = @import("cmd_version.zig");

/// CLI parsing errors
const ParseError = error{
    InvalidValue,
    MalformedOption,
};

/// Parse and handle command line arguments
pub fn handle(allocator: std.mem.Allocator) !u8 {
    // Register commands
    defer cmd.commands.deinit(allocator);
    try cmd_build.register(allocator);
    try cmd_debug.register(allocator);
    try cmd_help.register(allocator);
    try cmd_init.register(allocator);
    try cmd_version.register(allocator);

    // Get command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Determine the command; no command given = help command
    var cmd_name: []const u8 = "help";
    if (args.len > 1) {
        cmd_name = args[1];
    }

    // Check if the command exists
    var maybe_command: ?cmd.Command = null;
    for (cmd.commands.items) |command| {
        if (!std.mem.eql(u8, command.name, cmd_name)) continue;
        maybe_command = command;
        break;
    }

    // Error if command not found
    const command = maybe_command orelse {
        log.err("Command '{s}' does not exist", .{cmd_name});
        return 1;
    };

    // Collect positional and optional arguments
    var pos_args: std.ArrayList(cmd.Value) = .empty;
    defer pos_args.deinit(allocator);
    var opt_args: std.StringHashMapUnmanaged(cmd.Value) = .empty;
    defer opt_args.deinit(allocator);

    // Null-coalesce this command's supported arguments
    const cmd_args = command.args orelse &[_]cmd.Arg{};
    const cmd_options = command.options orelse &[_]cmd.Option{};

    // Parse each user-provided argument
    for (args, 0..) |arg, i| {
        if (i < 2) continue;

        // Positional arg; check if we require more
        if (arg[0] != '-') {
            const count = pos_args.items.len;
            if (count == cmd_args.len) {
                log.err("Extra argument provided: '{s}'", .{arg});
                return 1;
            }

            // Attempt to parse the argument, fail gracefully if we can't
            const cmd_arg = cmd_args[count];
            const value = parseArg(arg, cmd_arg.data_type) catch return 1;
            try pos_args.append(allocator, value);
            continue;
        }

        // Optional arg; check if we recognize it
        var maybe_option: ?cmd.Option = null;
        const key = arg[0 .. std.mem.indexOfScalar(u8, arg, '=') orelse arg.len];
        for (cmd_options) |option| {

            // Check for matching short identifier
            if (option.short != '\u{0}' and
                key.len == 2 and
                key[0] == '-' and
                key[1] == option.short)
            {
                maybe_option = option;
                break;
            }

            // Check for matching long identifier
            if (!std.mem.startsWith(u8, key, "--")) continue;
            if (std.mem.eql(u8, option.long, std.mem.trimStart(u8, key, "--"))) {
                maybe_option = option;
                break;
            }
        }

        // Attempt to parse the option, fail gracefully if we can't
        if (maybe_option) |option| {
            const value = parseOption(arg, option.data_type) catch return 1;
            try opt_args.put(allocator, option.long, value);
            continue;
        }

        log.err("Unknown option: '{s}'", .{arg});
        return 1;
    }

    // Help option takes precedence
    var it = opt_args.iterator();
    while (it.next()) |option| {
        if (!std.mem.eql(u8, option.key_ptr.*, cmd.help_option.long)) continue;
        command.help();
        return 0;
    }

    // Check for missing positional arguments
    if (pos_args.items.len < cmd_args.len) {
        for (cmd_args[pos_args.items.len..]) |arg| {
            log.err("Missing required argument: '{s}'", .{arg.name});
        }
        return 1;
    }

    // Execute command
    if (command.callback(&pos_args, &opt_args)) |msg| {
        log.err("{s}", .{msg});
        return 1;
    }

    return 0;
}

/// Parse a positional arg string into its value
fn parseArg(arg: []const u8, data_type: cmd.DataType) ParseError!cmd.Value {
    switch (data_type) {
        .string => return cmd.Value{ .string = arg },
        .int => return cmd.Value{ .int = try parseInt(arg) },
        .float => return cmd.Value{ .float = try parseFloat(arg) },
        .flag => {
            const is_true = std.mem.eql(u8, arg, "true");
            const is_false = std.mem.eql(u8, arg, "false");

            if (!is_true and !is_false) {
                log.err("Invalid flag value: '{s}'; expected 'true' or 'false'", .{arg});
                return ParseError.InvalidValue;
            }

            return cmd.Value{ .flag = is_true };
        },
    }
}

/// Parse an optional arg string into its value
fn parseOption(option: []const u8, data_type: cmd.DataType) ParseError!cmd.Value {
    // Flag options are truthy
    if (data_type == .flag) return cmd.Value{ .flag = true };

    // Other types require key=val syntax
    var pivot: usize = 0;
    for (option, 0..) |char, i| {
        if (char == '=') {
            pivot = i;
            break;
        }
    }
    if (pivot == 0 or pivot == option.len - 1) {
        log.err("Malformed option '{s}'; expected form '--name=value'", .{option});
        return ParseError.MalformedOption;
    }

    // Value is everything beyond the pivot
    const value = option[pivot + 1 ..];

    // Parse ints and floats
    if (data_type == .int) {
        return cmd.Value{ .int = try parseInt(value) };
    } else if (data_type == .float) {
        return cmd.Value{ .float = try parseFloat(value) };
    }

    // Remaining data type is string
    return cmd.Value{ .string = value };
}

/// Parse an integer string
fn parseInt(string: []const u8) ParseError!i64 {
    const int_val = std.fmt.parseInt(i64, string, 10) catch {
        log.err("Invalid integer value: '{s}'", .{string});
        return ParseError.InvalidValue;
    };

    return int_val;
}

/// Parse a float string
fn parseFloat(string: []const u8) ParseError!f64 {
    const float_val = std.fmt.parseFloat(f64, string) catch {
        log.err("Invalid float value: '{s}'", .{string});
        return ParseError.InvalidValue;
    };

    return float_val;
}
