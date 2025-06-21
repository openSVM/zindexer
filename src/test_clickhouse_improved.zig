const std = @import("std");
const ClickHouseClient = @import("clickhouse.zig").ClickHouseClient;
const database = @import("database.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Testing improved ClickHouse indexing...", .{});

    // Initialize ClickHouse client with optimized settings
    var client = try ClickHouseClient.initWithOptions(allocator, 
        "http://localhost:8123",
        "default",
        "",
        "solana_test",
        .{
            .use_http = true,
            .auto_flush = true,
            .batch_size = 1000,
            .compression = true,
        }
    );
    defer client.deinit();

    std.log.info("✅ Initialized optimized ClickHouse client", .{});

    // Test connection health
    const health = try client.healthCheck();
    std.log.info("Connection health: OK={}, Buffer size={}", .{ health.connection_ok, health.bulk_buffer_size });

    // Create optimized tables
    try client.createTables();
    std.log.info("✅ Created optimized tables with proper engines and indexes", .{});

    // Test bulk transaction insertion
    const test_tx = database.Transaction{
        .network = "mainnet-beta",
        .signature = "test_signature_12345",
        .slot = 123456789,
        .block_time = std.time.timestamp(),
        .success = true,
        .fee = 5000,
        .compute_units_consumed = 200000,
        .compute_units_price = 1,
        .recent_blockhash = "test_blockhash_12345",
        .error_msg = null,
    };

    // Insert individual transaction (will use bulk manager)
    try client.insertSingleTransaction(test_tx);
    std.log.info("✅ Added transaction to bulk buffer", .{});

    // Test bulk block insertion
    const test_block = database.Block{
        .network = "mainnet-beta",
        .slot = 123456789,
        .block_time = std.time.timestamp(),
        .block_hash = "test_block_hash_12345",
        .parent_slot = 123456788,
        .parent_hash = "test_parent_hash_12345",
        .block_height = 98765432,
        .transaction_count = 1,
        .successful_transaction_count = 1,
        .failed_transaction_count = 0,
        .total_fee = 5000,
        .total_compute_units = 200000,
    };

    // Add block to bulk manager
    if (client.bulk_manager) |*manager| {
        try manager.addBlock(test_block);
        std.log.info("✅ Added block to bulk buffer", .{});

        // Get buffer statistics
        const stats = manager.getBufferStats();
        std.log.info("Buffer stats: {} rows across {} tables", .{ stats.total_buffered_rows, stats.table_count });
    }

    // Test token transfer
    const test_transfer = database.TokenTransfer{
        .signature = "test_transfer_sig_12345",
        .slot = 123456789,
        .block_time = std.time.timestamp(),
        .mint_address = "So11111111111111111111111111111111111111112",
        .from_account = "sender_account_12345",
        .to_account = "receiver_account_12345", 
        .amount = 1000000000,
        .instruction_type = "transfer",
    };

    if (client.bulk_manager) |*manager| {
        try manager.addTokenTransfer(test_transfer);
        std.log.info("✅ Added token transfer to bulk buffer", .{});
    }

    // Flush all pending operations
    try client.flushBulkOperations();
    std.log.info("✅ Flushed all bulk operations to database", .{});

    // Get database metrics
    const metrics = try client.getDatabaseMetrics();
    std.log.info("Database metrics: rows={}, bytes={}, tables={}", .{ 
        metrics.total_rows, metrics.total_bytes, metrics.table_count 
    });

    // Optimize tables for better performance
    try client.optimizeAllTables();
    std.log.info("✅ Optimized all tables", .{});

    // Test database size calculation (simplified)
    const db_size = try client.getDatabaseSize();
    std.log.info("Database size: {} bytes", .{db_size});

    std.log.info("🎉 All ClickHouse indexing improvements tested successfully!", .{});
}

test "ClickHouse bulk operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test bulk manager initialization
    var client = try ClickHouseClient.initWithOptions(allocator, 
        "http://localhost:8123",
        "default", 
        "",
        "test_db",
        .{ .use_http = true, .batch_size = 100 }
    );
    defer client.deinit();

    // Verify components are initialized
    try std.testing.expect(client.http_client != null);
    try std.testing.expect(client.bulk_manager != null);
    try std.testing.expect(client.use_http == true);
    try std.testing.expect(client.batch_size == 100);
}

test "ClickHouse health check" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try ClickHouseClient.initWithOptions(allocator, 
        "http://localhost:8123",
        "default",
        "",
        "test_db",
        .{}
    );
    defer client.deinit();

    // Health check should not crash
    const health = try client.healthCheck();
    try std.testing.expect(health.bulk_buffer_size == 0); // Should be empty initially
}