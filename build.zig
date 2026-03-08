const std = @import("std");

/// Represents package metadata
const PackageMeta = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
};

/// Configure the build
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the executable
    const exe = b.addExecutable(.{
        .name = "nook",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Define internal modules
    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/root.zig"),
    });
    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/root.zig"),
    });
    const log_mod = b.createModule(.{
        .root_source_file = b.path("src/log/root.zig"),
    });
    const module_mod = b.createModule(.{
        .root_source_file = b.path("src/module/root.zig"),
    });
    const util_mod = b.createModule(.{
        .root_source_file = b.path("src/util/root.zig"),
    });

    // Configure metadata
    const pkg_meta = parseMeta(b);
    const meta = b.addOptions();
    meta.addOption([]const u8, "name", pkg_meta.name);
    meta.addOption([]const u8, "version", pkg_meta.version);
    meta.addOption([]const u8, "description", pkg_meta.description);

    // Configure internal module imports
    cli_mod.addImport("core", core_mod);
    cli_mod.addImport("log", log_mod);
    cli_mod.addImport("module", module_mod);
    cli_mod.addImport("util", util_mod);
    cli_mod.addOptions("meta", meta);

    log_mod.addImport("util", util_mod);
    exe.root_module.addImport("cli", cli_mod);

    b.installArtifact(exe);
}

/// Parses build.zig.zon into package metadata
fn parseMeta(b: *std.Build) PackageMeta {
    const contents = std.fs.cwd().readFileAlloc(
        b.allocator,
        "build.zig.zon",
        1024 * 10,
    ) catch @panic("Could not read build.zig.zon");

    return .{
        .name = "nook",
        .version = extractField(contents, "version") orelse "0.0.0",
        .description = extractField(contents, "description") orelse "",
    };
}

/// Extracts a field from the build.zig.zon contents
fn extractField(source: []const u8, field: []const u8) ?[]const u8 {
    var lines = std.mem.tokenizeScalar(u8, source, '\n');

    while (lines.next()) |line| {
        if (!std.mem.containsAtLeast(u8, line, 1, field)) continue;

        const start = std.mem.indexOfScalar(u8, line, '"') orelse continue;
        const after = line[start + 1 ..];
        const end = std.mem.indexOfScalar(u8, after, '"') orelse continue;

        return after[0..end];
    }

    return null;
}
