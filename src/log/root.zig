const std = @import("std");

// ANSI escape codes for terminal styling
pub const RED = "\x1b[31m";
pub const GREEN = "\x1b[32m";
pub const YELLOW = "\x1b[33m";
pub const BLUE = "\x1b[34m";
pub const MAGENTA = "\x1b[35m";
pub const BOLD = "\x1b[1m";
pub const DIM = "\x1b[2m";
pub const RESET = "\x1b[0m";

/// Whether verbose logging is enabled (allows debug logs)
var verbose = false;

/// Sets the verbose flag
pub fn setVerbose(v: bool) void {
    verbose = v;
}

/// Logs a message at the info level
pub fn info(comptime fmt: []const u8, args: anytype) void {
    std.log.info(" " ++ BLUE ++ fmt ++ RESET, args);
}

/// Logs a message at the success level
pub fn success(comptime fmt: []const u8, args: anytype) void {
    std.log.info(" " ++ GREEN ++ BOLD ++ fmt ++ RESET, args);
}

/// Logs a message at the debug level
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (!verbose) return;
    std.log.debug(BLUE ++ fmt ++ RESET, args);
}

/// Logs a message at the warning level
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    std.log.warn(" " ++ YELLOW ++ fmt ++ RESET, args);
}

/// Logs a message at the error level
pub fn err(comptime fmt: []const u8, args: anytype) void {
    std.log.err(RED ++ fmt ++ RESET, args);
}
