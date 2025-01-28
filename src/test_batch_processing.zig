const std = @import("std");
const testing = std.testing;
const indexer = @import("indexer/core.zig");
const clickhouse = @import("clickhouse.zig");
const json = std.json;
const rpc = @import("rpc_client.zig");
const RpcClient = rpc.RpcClient;
const WebSocketClient = rpc.WebSocketClient;

const BatchProcessor = struct {
    allocator: std.mem.Allocator,
    batch: std.ArrayList(json.Value),
    start_time: i64,
    total_input_size: usize,
    total_output_size: usize,
    total_transactions: usize,
    successful_transactions: usize,
    failed_transactions: usize,
    db_client: *clickhouse.ClickHouseClient,
    table_size_before: usize,
    table_size_after: usize,
    db_size_before: usize,
    db_size_after: usize,

    pub fn init(allocator: std.mem.Allocator, db_client: *clickhouse.ClickHouseClient) !*BatchProcessor {
        const processor = try allocator.create(BatchProcessor);
        processor.* = .{
            .allocator = allocator,
            .batch = std.ArrayList(json.Value).init(allocator),
            .start_time = std.time.timestamp(),
            .total_input_size = 0,
            .total_output_size = 0,
            .total_transactions = 0,
            .successful_transactions = 0,
            .failed_transactions = 0,
            .db_client = db_client,
            .table_size_before = 0,
            .table_size_after = 0,
            .db_size_before = 0,
            .db_size_after = 0,
        };

        // Get initial DB and table sizes if not in logging-only mode
        if (!db_client.logging_only) {
            processor.db_size_before = db_client.getDatabaseSize() catch |err| blk: {
                std.log.warn("Failed to get initial database size: {any}", .{err});
                break :blk 0;
            };
            processor.table_size_before = db_client.getTableSize("transactions") catch |err| blk: {
                std.log.warn("Failed to get initial table size: {any}", .{err});
                break :blk 0;
            };
        }

        return processor;
    }

    pub fn deinit(self: *BatchProcessor) void {
        self.batch.deinit();
        self.allocator.destroy(self);
    }

    pub fn addTransaction(self: *BatchProcessor, tx_json: json.Value) !bool {
        // Calculate input size
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        var string_buffer = std.ArrayList(u8).init(arena.allocator());
        try std.json.stringify(tx_json, .{}, string_buffer.writer());
        self.total_input_size += string_buffer.items.len;

        try self.batch.append(tx_json);
        self.total_transactions += 1;

        // Process batch if it reaches 100 transactions
        if (self.batch.items.len >= 100) {
            try self.processBatch();
            self.batch.clearRetainingCapacity();
            return true;
        }

        return false;
    }

    fn processBatch(self: *BatchProcessor) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        // Track output size
        var output_buffer = std.ArrayList(u8).init(arena.allocator());

        // Process each transaction
        for (self.batch.items) |tx_json| {
            const tx = tx_json.object;
            const meta = tx.get("meta").?.object;

            // Track success/failure
            if (meta.get("err") == null) {
                self.successful_transactions += 1;
            } else {
                self.failed_transactions += 1;
            }

            // Calculate output size (what gets written to ClickHouse)
            try std.json.stringify(tx_json, .{}, output_buffer.writer());
        }
        self.total_output_size += output_buffer.items.len;

        // Insert batch into ClickHouse if not in logging-only mode
        if (!self.db_client.logging_only) {
            self.db_client.insertTransactionBatch(self.batch.items) catch |err| {
                std.log.warn("Failed to insert batch: {any}", .{err});
            };
        }
    }

    pub fn generateReport(self: *BatchProcessor) ![]const u8 {
        // Get final sizes if not in logging-only mode
        if (!self.db_client.logging_only) {
            self.db_size_after = self.db_client.getDatabaseSize() catch |err| blk: {
                std.log.warn("Failed to get final database size: {any}", .{err});
                break :blk 0;
            };
            self.table_size_after = self.db_client.getTableSize("transactions") catch |err| blk: {
                std.log.warn("Failed to get final table size: {any}", .{err});
                break :blk 0;
            };
        }

        const duration = std.time.timestamp() - self.start_time;
        const input_kb = @as(f64, @floatFromInt(self.total_input_size)) / 1024.0;
        const output_kb = @as(f64, @floatFromInt(self.total_output_size)) / 1024.0;

        // Calculate rates, handling division by zero
        const tx_per_second = if (duration > 0)
            @as(f64, @floatFromInt(self.total_transactions)) / @as(f64, @floatFromInt(duration))
        else
            0.0;
        const processing_rate = if (duration > 0)
            (input_kb + output_kb) / @as(f64, @floatFromInt(duration))
        else
            0.0;

        var report = std.ArrayList(u8).init(self.allocator);
        const writer = report.writer();

        try writer.print(
            \\Processing Report
            \\---------------
            \\Data Processed:
            \\  Input: {d:.2} KB
            \\  Output: {d:.2} KB
            \\
            \\Processing Rates:
            \\  Avg Data Rate: {d:.2} KB/s
            \\  Avg Transaction Rate: {d:.2} tx/s
            \\
            \\Database Metrics:
            \\  Database Size: {d} KB -> {d} KB (delta: {d} KB)
            \\  Table Size: {d} KB -> {d} KB (delta: {d} KB)
            \\
            \\Transaction Stats:
            \\  Total: {d}
            \\  Successful: {d}
            \\  Failed: {d}
            \\
            \\Timing:
            \\  Started: {d}
            \\  Ended: {d}
            \\  Duration: {d}s
            \\
        , .{
            input_kb,
            output_kb,
            processing_rate,
            tx_per_second,
            self.db_size_before / 1024,
            self.db_size_after / 1024,
            (self.db_size_after -| self.db_size_before) / 1024,
            self.table_size_before / 1024,
            self.table_size_after / 1024,
            (self.table_size_after -| self.table_size_before) / 1024,
            self.total_transactions,
            self.successful_transactions,
            self.failed_transactions,
            self.start_time,
            std.time.timestamp(),
            duration,
        });

        return report.toOwnedSlice();
    }
};

test "batch process 10k transactions" {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize RPC client with files
    var rpc_client = try RpcClient.initFromFiles(allocator, "src/rpc_nodes.json", "src/ws_nodes.json");
    defer rpc_client.deinit();

    // Initialize ClickHouse client
    var db_client = try clickhouse.ClickHouseClient.init(
        allocator,
        "127.0.0.1:9000",
        "default",
        "",
        "test_db",
    );
    defer db_client.deinit();

    // Initialize batch processor
    var processor = try BatchProcessor.init(allocator, &db_client);
    defer processor.deinit();

    // Only proceed with WebSocket subscription if not in logging-only mode
    if (!db_client.logging_only) {
        // Subscribe to transaction updates
        try rpc_client.subscribeTransaction(processor, struct {
            fn callback(ctx: *anyopaque, _: *WebSocketClient, value: json.Value) void {
                const batch_processor = @as(*BatchProcessor, @alignCast(@ptrCast(ctx)));

                // Stop if we've processed 10k transactions
                if (batch_processor.total_transactions >= 10000) {
                    return;
                }

                // Process transaction
                _ = batch_processor.addTransaction(value) catch |err| {
                    std.log.err("Failed to process transaction: {any}", .{err});
                    return;
                };
            }
        }.callback);

        // Wait until we've processed 10k transactions
        while (processor.total_transactions < 10000) {
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    } else {
        std.log.info("Running in logging-only mode, skipping transaction processing", .{});
    }

    // Generate and print report
    const report = try processor.generateReport();
    defer allocator.free(report);
    std.debug.print("\n{s}\n", .{report});
}
