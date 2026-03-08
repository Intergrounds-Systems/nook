const std = @import("std");

const MODULE_FILE = "nook.mod";

/// Module tooling errors
pub const ModuleError = error{
    AlreadyExists,
    DoesNotExist,
};

/// Represents a Nook module (project)
pub const Module = struct {
    name: []const u8,
    version: []const u8,
    hash: []const u8,
    nook_version: []const u8,

    /// Write the module file to the disk
    fn write(self: Module, file: *const std.fs.File) !void {
        inline for (std.meta.fields(Module)) |field| {
            const value = @field(self, field.name);
            _ = try file.write(field.name);
            _ = try file.write(": ");
            _ = try file.write(value);
            _ = try file.write("\n");
        }
    }
};

/// Create a new module in the current directory
pub fn init(nook_version: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    // Check if a module file already exists here
    var it = dir.iterate();
    while (try it.next()) |entry|
        if (std.mem.eql(u8, entry.name, MODULE_FILE)) return ModuleError.AlreadyExists;

    // Create the module data
    const cwd_path = try std.process.getCwdAlloc(allocator);
    const name = std.fs.path.basename(cwd_path);
    const hash = try std.fmt.allocPrint(allocator, "{x}", .{std.time.nanoTimestamp()});
    var module: Module = .{
        .name = name,
        .version = "0.1.0",
        .hash = hash,
        .nook_version = nook_version,
    };

    // Create the module file
    const file = try dir.createFile(MODULE_FILE, .{});
    defer file.close();

    // Write the module to the disk
    try module.write(&file);
}

/// Load an existing module file
pub fn load(_: std.mem.Allocator, _: []const u8) ModuleError!Module {
    
}
