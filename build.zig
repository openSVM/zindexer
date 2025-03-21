const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create modules with explicit dependencies
    const rpc_module = b.addModule("rpc", .{
        .source_file = .{ .path = "src/rpc.zig" },
    });

    const clickhouse_module = b.addModule("clickhouse", .{
        .source_file = .{ .path = "src/clickhouse.zig" },
    });

    const indexer_module = b.addModule("indexer", .{
        .source_file = .{ .path = "src/indexer.zig" },
        .dependencies = &.{
            .{ .name = "rpc", .module = rpc_module },
            .{ .name = "clickhouse", .module = clickhouse_module },
        },
    });

    // Create executable with optimized settings
    const exe = b.addExecutable(.{
        .name = "solana-indexer",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        // Force ReleaseSafe for faster builds while maintaining safety
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add empty.c with minimal flags
    exe.addCSourceFile(.{
        .file = .{ .path = "src/empty.c" },
        .flags = &.{"-Wall"},
    });

    // Add module dependencies
    exe.addModule("indexer", indexer_module);
    exe.addModule("rpc", rpc_module);
    exe.addModule("clickhouse", clickhouse_module);

    // Link system libraries
    exe.linkLibC();

    // Set SDK path for macOS
    if (target.os_tag == .macos) {
        exe.addSystemIncludePath(.{ .path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include" });
        exe.addLibraryPath(.{ .path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib" });
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

    const run_step = b.step("run", "Run the Solana indexer");
    run_step.dependOn(&run_cmd.step);

    // Create test step with optimized settings
    // Add main tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add realtime tests
    const realtime_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test_realtime.zig" },
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });

    // Add module dependencies to tests
    main_tests.addModule("indexer", indexer_module);
    main_tests.addModule("rpc", rpc_module);
    main_tests.addModule("clickhouse", clickhouse_module);
    main_tests.linkLibC();
    main_tests.want_lto = false;

    realtime_tests.addModule("indexer", indexer_module);
    realtime_tests.addModule("rpc", rpc_module);
    realtime_tests.addModule("clickhouse", clickhouse_module);
    realtime_tests.linkLibC();
    realtime_tests.want_lto = false;

    const run_main_tests = b.addRunArtifact(main_tests);
    const run_realtime_tests = b.addRunArtifact(realtime_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_realtime_tests.step);
}
