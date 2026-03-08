const log = @import("log");
const meta = @import("meta");
const std = @import("std");

// The command registry
pub var commands: std.ArrayList(Command) = .empty;

/// Global options
pub const help_option: Option = .{
    .long = "help",
    .short = 'h',
    .description = "Display help for this command",
    .data_type = .flag,
};

/// Represents a command supported by the CLI
pub const Command = struct {
    name: []const u8,
    description: []const u8,
    args: ?[]const Arg = null,
    options: ?[]const Option = null,
    callback: *const fn (args: *std.ArrayList(Value), options: *std.StringHashMapUnmanaged(Value)) ?[]const u8,

    /// Print the Command's help string
    pub fn help(self: Command) void {
        std.debug.print("{s}\n\n{s}USAGE{s}:\n\t{s}{s} {s}{s}{s}", .{
            self.description,
            log.BOLD,
            log.RESET,
            log.GREEN,
            meta.name,
            log.BLUE,
            self.name,
            log.RESET,
        });

        // Null-coalesce args and options
        const args = self.args orelse &[_]Arg{};
        const options = self.options orelse &[_]Option{};

        // List positional arguments in usage string if this command has them
        for (args) |arg| {
            std.debug.print(" {s}<{s}>{s}", .{
                log.YELLOW,
                arg.name,
                log.RESET,
            });
        }

        // Add options to usage string if this command has them
        if (options.len > 0)
            std.debug.print(" {s}[--OPTIONS]{s}", .{
                log.MAGENTA,
                log.RESET,
            });
        std.debug.print("\n", .{});

        // Measure spaces to align arg and option descriptions
        var arg_spaces: usize = 0;
        var opt_spaces: usize = 0;
        for (args) |arg| {
            if (arg.name.len > arg_spaces) arg_spaces = arg.name.len;
        }
        for (options) |option| {
            if (option.long.len > opt_spaces) opt_spaces = option.long.len;
        }

        // List args
        if (args.len > 0)
            std.debug.print("\n{s}ARGS{s}:\n", .{
                log.BOLD,
                log.RESET,
            });
        for (args) |arg| {
            arg.help(arg_spaces);
        }

        // List options
        if (options.len > 0)
            std.debug.print("\n{s}OPTIONS{s}:\n", .{
                log.BOLD,
                log.RESET,
            });
        for (options) |option| {
            option.help(opt_spaces);
        }
    }
};

/// Represents a required positional argument for a command
pub const Arg = struct {
    name: []const u8,
    description: []const u8,
    data_type: DataType,

    /// Print the Arg's help string
    fn help(self: Arg, spaces: usize) void {
        std.debug.print("\t{s}{s}{s}: ", .{
            log.YELLOW,
            self.name,
            log.RESET,
        });

        for (0..spaces - self.name.len) |_| {
            std.debug.print(" ", .{});
        }

        std.debug.print("{s}{s}{s} ({s})\n", .{
            log.DIM,
            self.description,
            log.RESET,
            @tagName(self.data_type),
        });
    }
};

/// Represents a key-value argument for a command
pub const Option = struct {
    long: []const u8,
    short: u8 = '\u{0}',
    description: []const u8,
    data_type: DataType,

    /// Print the Option's help string
    fn help(self: Option, spaces: usize) void {
        std.debug.print("\t{s}--{s} ", .{
            log.MAGENTA,
            self.long,
        });
        for (0..spaces - self.long.len) |_| {
            std.debug.print(" ", .{});
        }

        if (self.short == '\u{0}') {
            std.debug.print("  ", .{});
        } else {
            std.debug.print("-{c}", .{self.short});
        }

        std.debug.print("{s}: {s}{s}{s} ({s})\n", .{
            log.RESET,
            log.DIM,
            self.description,
            log.RESET,
            @tagName(self.data_type),
        });
    }
};

/// Represents the data type of a command argument
pub const DataType = enum {
    string,
    int,
    float,
    flag,
};

/// Represents the literal value of a command argument
pub const Value = union(enum) {
    string: []const u8,
    int: i64,
    float: f64,
    flag: bool,
};
