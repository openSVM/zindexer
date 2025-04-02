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
    var database_type: indexer.core.dependencies.database.DatabaseType = .ClickHouse;
    var database_url: []const u8 = "195.200.29.12:9000";
    var database_user: []const u8 = "rin";
    var database_password: []const u8 = "rpdQ4fkBWQWQ6P96q85WlXhyZREsKsCsaSxLDaQq5IiVMR1VENtjGwoYe7mVIaTV";
    var database_name: []const u8 = "solana";
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
        } else if (std.mem.eql(u8, arg, "--database-type") or std.mem.eql(u8, arg, "-t")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --database-type", .{});
                return error.InvalidArgument;
            }
            if (std.mem.eql(u8, args[i], "clickhouse")) {
                database_type = .ClickHouse;
            } else if (std.mem.eql(u8, args[i], "questdb")) {
                database_type = .QuestDB;
            } else {
                std.log.err("Invalid database type: {s}. Must be 'clickhouse' or 'questdb'", .{args[i]});
                return error.InvalidArgument;
            }
        } else if (std.mem.eql(u8, arg, "--database-url") or std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --database-url", .{});
                return error.InvalidArgument;
            }
            database_url = args[i];
        } else if (std.mem.eql(u8, arg, "--database-user") or std.mem.eql(u8, arg, "-u")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --database-user", .{});
                return error.InvalidArgument;
            }
            database_user = args[i];
        } else if (std.mem.eql(u8, arg, "--database-password") or std.mem.eql(u8, arg, "-p")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --database-password", .{});
                return error.InvalidArgument;
            }
            database_password = args[i];
        } else if (std.mem.eql(u8, arg, "--database-name") or std.mem.eql(u8, arg, "-d")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --database-name", .{});
                return error.InvalidArgument;
            }
            database_name = args[i];
        // Keep backward compatibility with old clickhouse arguments
        } else if (std.mem.eql(u8, arg, "--clickhouse-url")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-url", .{});
                return error.InvalidArgument;
            }
            database_url = args[i];
            database_type = .ClickHouse;
        } else if (std.mem.eql(u8, arg, "--clickhouse-user")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-user", .{});
                return error.InvalidArgument;
            }
            database_user = args[i];
            database_type = .ClickHouse;
        } else if (std.mem.eql(u8, arg, "--clickhouse-password")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-password", .{});
                return error.InvalidArgument;
            }
            database_password = args[i];
            database_type = .ClickHouse;
        } else if (std.mem.eql(u8, arg, "--clickhouse-database")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --clickhouse-database", .{});
                return error.InvalidArgument;
            }
            database_name = args[i];
            database_type = .ClickHouse;
        // QuestDB specific arguments for backward compatibility
        } else if (std.mem.eql(u8, arg, "--questdb-url")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --questdb-url", .{});
                return error.InvalidArgument;
            }
            database_url = args[i];
            database_type = .QuestDB;
        } else if (std.mem.eql(u8, arg, "--questdb-user")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --questdb-user", .{});
                return error.InvalidArgument;
            }
            database_user = args[i];
            database_type = .QuestDB;
        } else if (std.mem.eql(u8, arg, "--questdb-password")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --questdb-password", .{});
                return error.InvalidArgument;
            }
            database_password = args[i];
            database_type = .QuestDB;
        } else if (std.mem.eql(u8, arg, "--questdb-database")) {
            i += 1;
            if (i >= args.len) {
                std.log.err("Missing value for --questdb-database", .{});
                return error.InvalidArgument;
            }
            database_name = args[i];
            database_type = .QuestDB;
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
        .database_type = database_type,
        .database_url = database_url,
        .database_user = database_user,
        .database_password = database_password,
        .database_name = database_name,
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
        fn run(ui_ptr: *tui.IndexerUI) !void {
            try ui_ptr.run();
        }
    }.run, .{ui});

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
        \\  -t, --database-type <type>        Database type (clickhouse or questdb)
        \\  -c, --database-url <url>          Database server URL
        \\  -u, --database-user <user>        Database username
        \\  -p, --database-password <pass>    Database password
        \\  -d, --database-name <db>          Database name
        \\  -b, --batch-size <size>           Batch size for historical indexing
        \\      --max-retries <count>         Maximum retry attempts
        \\      --retry-delay <ms>            Delay between retries in milliseconds
        \\
        \\Legacy ClickHouse options (deprecated):
        \\      --clickhouse-url <url>        ClickHouse server URL
        \\      --clickhouse-user <user>      ClickHouse username
        \\      --clickhouse-password <pass>  ClickHouse password
        \\      --clickhouse-database <db>    ClickHouse database name
        \\
        \\QuestDB options:
        \\      --questdb-url <url>           QuestDB server URL
        \\      --questdb-user <user>         QuestDB username
        \\      --questdb-password <pass>     QuestDB password
        \\      --questdb-database <db>       QuestDB database name
        \\
        \\  -h, --help                        Show this help message
        \\
    , .{});
}
