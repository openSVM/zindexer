const std = @import("std");
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
    should_stop: bool,

    pub fn init(allocator: std.mem.Allocator, db_client: *clickhouse.ClickHouseClient, network_name: []const u8) !*BatchProcessor {
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
            .should_stop = false,
            .network_name = try allocator.dupe(u8, network_name),
        };

        // Get initial DB and table sizes
        processor.db_size_before = db_client.getDatabaseSize() catch |err| blk: {
            std.log.warn("Failed to get initial database size: {any}", .{err});
            break :blk 0;
        };
        processor.table_size_before = db_client.getTableSize("transactions") catch |err| blk: {
            std.log.warn("Failed to get initial table size: {any}", .{err});
            break :blk 0;
        };

        return processor;
    }

    pub fn deinit(self: *BatchProcessor) void {
        self.batch.deinit();
        self.allocator.free(self.network_name);
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

        // Insert batch into ClickHouse
        try self.db_client.insertTransactionBatch(self.batch.items, self.network_name);

        // Check if we've reached 10k transactions
        if (self.total_transactions >= 10000) {
            self.should_stop = true;
        }
    }

    pub fn generateReport(self: *BatchProcessor) ![]const u8 {
        // Get final sizes
        self.db_size_after = self.db_client.getDatabaseSize() catch |err| blk: {
            std.log.warn("Failed to get final database size: {any}", .{err});
            break :blk 0;
        };
        self.table_size_after = self.db_client.getTableSize("transactions") catch |err| blk: {
            std.log.warn("Failed to get final table size: {any}", .{err});
            break :blk 0;
        };

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

pub fn main() !void {
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
        "195.200.29.12:9000",
        "rin",
        "rpdQ4fkBWQWQ6P96q85WlXhyZREsKsCsaSxLDaQq5IiVMR1VENtjGwoYe7mVIaTV",
        "solana",
    );
    defer db_client.deinit();

    // Create tables if they don't exist
    try db_client.createTables();

    // Get all available networks
    const networks = try rpc_client.getNetworkNames(allocator);
    defer {
        for (networks) |name| {
            allocator.free(name);
        }
        allocator.free(networks);
    }

    // Create a batch processor for each network
    var processors = std.ArrayList(*BatchProcessor).init(allocator);
    defer {
        for (processors.items) |processor| {
            processor.deinit();
        }
        processors.deinit();
    }

    // Initialize batch processors for each network
    for (networks) |network_name| {
        std.log.info("Initializing processor for network: {s}", .{network_name});
        const processor = try BatchProcessor.init(allocator, &db_client, network_name);
        try processors.append(processor);
    }

    // Subscribe to transaction updates for each network
    for (processors.items) |processor| {
        std.log.info("Subscribing to transactions for network: {s}", .{processor.network_name});
        try rpc_client.subscribeTransaction(processor.network_name, processor, struct {
            fn callback(ctx: *anyopaque, _: *WebSocketClient, value: json.Value) void {
                const batch_processor = @as(*BatchProcessor, @alignCast(@ptrCast(ctx)));

                // Stop if we've processed 10k transactions
                if (batch_processor.should_stop) {
                    return;
                }

                // Process transaction
                _ = batch_processor.addTransaction(value) catch |err| {
                    std.log.err("Failed to process transaction on network {s}: {any}", .{batch_processor.network_name, err});
                    return;
                };
            }
        }.callback);
    }

    // Wait until all processors have processed 10k transactions or timeout after 5 minutes
    const start_time = std.time.timestamp();
    const timeout = 5 * 60; // 5 minutes in seconds
    
    while (true) {
        // Check if all processors are done
        var all_done = true;
        for (processors.items) |processor| {
            if (!processor.should_stop) {
                all_done = false;
                break;
            }
        }
        
        if (all_done) break;
        
        // Check for timeout
        if (std.time.timestamp() - start_time > timeout) {
            std.log.warn("Timeout reached after {d} seconds", .{timeout});
            break;
        }
        
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    // Generate and print reports for each network
    for (processors.items) |processor| {
        const report = try processor.generateReport();
        defer allocator.free(report);
        std.debug.print("\n{s}\n", .{report});
    }
}