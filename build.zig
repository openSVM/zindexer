const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get dependencies (commented out for now to simplify build)
    // const questdb_dep = b.dependency("c-questdb-client", .{});

    // Create modules with explicit dependencies
    const rpc_mod = b.addModule("rpc", .{
        .root_source_file = b.path("src/rpc.zig"),
    });

    const database_mod = b.addModule("database", .{
        .root_source_file = b.path("src/database.zig"),
    });

    const clickhouse_mod = b.addModule("clickhouse", .{
        .root_source_file = b.path("src/clickhouse.zig"),
        .imports = &.{
            .{ .name = "database", .module = database_mod },
        },
    });

    const questdb_mod = b.addModule("questdb", .{
        .root_source_file = b.path("src/questdb.zig"),
        .imports = &.{
            .{ .name = "database", .module = database_mod },
            // .{ .name = "c-questdb-client", .module = questdb_dep.module("c-questdb-client") },
        },
    });

    const indexer_mod = b.addModule("indexer", .{
        .root_source_file = b.path("src/indexer.zig"),
        .imports = &.{
            .{ .name = "rpc", .module = rpc_mod },
            .{ .name = "database", .module = database_mod },
            .{ .name = "clickhouse", .module = clickhouse_mod },
            .{ .name = "questdb", .module = questdb_mod },
        },
    });

    // Create executable with optimized settings
    const exe = b.addExecutable(.{
        .name = "zindexer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        // Force ReleaseSafe for faster builds while maintaining safety
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add empty.c with minimal flags
    exe.addCSourceFile(.{
        .file = b.path("src/empty.c"),
        .flags = &.{"-Wall"},
    });

    // Add module dependencies
    exe.root_module.addImport("indexer", indexer_mod);
    exe.root_module.addImport("rpc", rpc_mod);
    exe.root_module.addImport("clickhouse", clickhouse_mod);

    // Link system libraries
    exe.linkLibC();

    // Set SDK path for macOS
    if (target.result.os.tag == .macos) {
        exe.addSystemIncludePath(b.path("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include"));
        exe.addLibraryPath(b.path("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib"));
    }

    // Disable CPU feature detection and LTO for faster builds
    exe.want_lto = false;

    // Install the executable
    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the ZIndexer");
    run_step.dependOn(&run_cmd.step);

    // Create test step with optimized settings
    // Add main tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add simple tests that don't require network access (for CI)
    const simple_tests = b.addTest(.{
        .root_source_file = b.path("src/test_simple.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add realtime tests (disabled by default in CI)
    const realtime_tests = b.addTest(.{
        .root_source_file = b.path("src/test_realtime.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add module dependencies to tests
    main_tests.root_module.addImport("indexer", indexer_mod);
    main_tests.root_module.addImport("rpc", rpc_mod);
    main_tests.root_module.addImport("clickhouse", clickhouse_mod);
    main_tests.linkLibC();
    main_tests.want_lto = false;

    // Simple tests don't need any dependencies

    realtime_tests.root_module.addImport("indexer", indexer_mod);
    realtime_tests.root_module.addImport("rpc", rpc_mod);
    realtime_tests.root_module.addImport("clickhouse", clickhouse_mod);
    realtime_tests.linkLibC();
    realtime_tests.want_lto = false;

    const run_main_tests = b.addRunArtifact(main_tests);
    const run_simple_tests = b.addRunArtifact(simple_tests);
    const run_realtime_tests = b.addRunArtifact(realtime_tests);

    // Define different test steps
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_simple_tests.step); // Only run simple tests by default

    // Add full test step that includes all tests
    const full_test_step = b.step("test-full", "Run all tests including network-dependent ones");
    full_test_step.dependOn(&run_main_tests.step);
    full_test_step.dependOn(&run_simple_tests.step);
    full_test_step.dependOn(&run_realtime_tests.step);
}
