const std = @import("std");
const clickhouse = @import("clickhouse.zig");
const json = std.json;
const rpc = @import("rpc_client.zig");
const indexer = @import("indexer.zig");
const tui = @import("tui.zig");

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var mode: indexer.IndexerMode = .RealTime;
    var rpc_nodes_file: []const u8 = "src/rpc_nodes.json";
    var ws_nodes_file: []const u8 = "src/ws_nodes.json";
    var clickhouse_url: []const u8 = "195.200.29.12:9000";
    var clickhouse_user: []const u8 = "rin";
    var clickhouse_password: []const u8 = "rpdQ4fkBWQWQ6P96q85WlXhyZREsKsCsaSxLDaQq5IiVMR1VENtjGwoYe7mVIaTV";
    var clickhouse_database: []const u8 = "solana";
    var batch_size: u32 = 20;
    var max_retries: u32 = 3;
    var retry_delay_ms: u32 = 1000;

    // Parse command line arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--mode") or std.mem.eql(u8, arg, "-m")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --mode", .{});
                return error.InvalidArgument;
            }
            if (std.mem.eql(u8, args[i], "historical")) {
                mode = .Historical;
            } else if (std.mem.eql(u8, args[i], "realtime")) {
                mode = .RealTime;
            } else {
                std.log.err("Invalid mode: {s}", .{args[i]});
                return error.InvalidArgument;
            }
        } else if (std.mem.eql(u8, arg, "--rpc-nodes") or std.mem.eql(u8, arg, "-r")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --rpc-nodes", .{});
                return error.InvalidArgument;
            }
            rpc_nodes_file = args[i];
        } else if (std.mem.eql(u8, arg, "--ws-nodes") or std.mem.eql(u8, arg, "-w")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --ws-nodes", .{});
                return error.InvalidArgument;
            }
            ws_nodes_file = args[i];
        } else if (std.mem.eql(u8, arg, "--clickhouse-url") or std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-url", .{});
                return error.InvalidArgument;
            }
            clickhouse_url = args[i];
        } else if (std.mem.eql(u8, arg, "--clickhouse-user") or std.mem.eql(u8, arg, "-u")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-user", .{});
                return error.InvalidArgument;
            }
            clickhouse_user = args[i];
        } else if (std.mem.eql(u8, arg, "--clickhouse-password") or std.mem.eql(u8, arg, "-p")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-password", .{});
                return error.InvalidArgument;
            }
            clickhouse_password = args[i];
        } else if (std.mem.eql(u8, arg, "--clickhouse-database") or std.mem.eql(u8, arg, "-d")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-database", .{});
                return error.InvalidArgument;
            }
            clickhouse_database = args[i];
        } else if (std.mem.eql(u8, arg, "--batch-size") or std.mem.eql(u8, arg, "-b")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --batch-size", .{});
                return error.InvalidArgument;
            }
            batch_size = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--max-retries")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --max-retries", .{});
                return error.InvalidArgument;
            }
            max_retries = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--retry-delay")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --retry-delay", .{});
                return error.InvalidArgument;
            }
            retry_delay_ms = try std.fmt.parseInt(u32, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        } else {
            std.log.err("Unknown argument: {s}", .{arg});
            printUsage();
            return error.InvalidArgument;
        }
    }

    // Initialize indexer config
    const config = indexer.IndexerConfig{
        .rpc_nodes_file = rpc_nodes_file,
        .ws_nodes_file = ws_nodes_file,
        .clickhouse_url = clickhouse_url,
        .clickhouse_user = clickhouse_user,
        .clickhouse_password = clickhouse_password,
        .clickhouse_database = clickhouse_database,
        .mode = mode,
        .batch_size = batch_size,
        .max_retries = max_retries,
        .retry_delay_ms = retry_delay_ms,
    };

    // Initialize indexer
    var idx = try indexer.Indexer.init(allocator, config);
    defer idx.deinit();

    // Initialize TUI
    var ui = try tui.IndexerUI.init(allocator);
    defer ui.deinit();

    // Set stats callback
    idx.setStatsCallback(struct {
        fn callback(ctx: *anyopaque, network_name: []const u8, current_slot: u64, total_slots: u64, rpc_ok: bool, db_ok: bool) void {
            const ui_ptr = @as(*tui.IndexerUI, @alignCast(@ptrCast(ctx)));
            ui_ptr.updateStats(network_name, current_slot, total_slots, rpc_ok, db_ok);
        }
    }.callback, &ui);

    // Start UI in a separate thread
    const ui_thread = try std.Thread.spawn(.{}, struct {
        fn run(ui_ptr: **tui.IndexerUI) !void {
            try ui_ptr.*.run();
        }
    }.run, .{&ui});

    // Start indexer
    try idx.start();

    // Wait for UI thread to finish
    ui_thread.join();
}

fn printUsage() void {
    std.debug.print(
        \\Usage: zindexer [options]
        \\
        \\Options:
        \\  -m, --mode <mode>                 Indexer mode (historical or realtime)
        \\  -r, --rpc-nodes <file>            RPC nodes configuration file
        \\  -w, --ws-nodes <file>             WebSocket nodes configuration file
        \\  -c, --clickhouse-url <url>        ClickHouse server URL
        \\  -u, --clickhouse-user <user>      ClickHouse username
        \\  -p, --clickhouse-password <pass>  ClickHouse password
        \\  -d, --clickhouse-database <db>    ClickHouse database name
        \\  -b, --batch-size <size>           Batch size for historical indexing
        \\      --max-retries <count>         Maximum retry attempts
        \\      --retry-delay <ms>            Delay between retries in milliseconds
        \\  -h, --help                        Show this help message
        \\
    , .{});
}
