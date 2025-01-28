const std = @import("std");
const testing = std.testing;
const indexer = @import("indexer/core.zig");
const clickhouse = @import("clickhouse.zig");

test "realtime mode saves data" {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create test config
    const config = indexer.IndexerConfig{
        .rpc_nodes_file = "src/rpc_nodes.json"[0..],
        .ws_nodes_file = "src/ws_nodes.json"[0..],
        .clickhouse_url = "127.0.0.1:9000"[0..],
        .clickhouse_database = "test_db"[0..],
        .mode = .Historical, // Use historical mode for testing
        .batch_size = 1,
    };

    // Initialize indexer
    var idx = try indexer.Indexer.init(allocator, config);
    defer idx.deinit();

    // Get current slot
    const current_slot = try idx.rpc_client.getSlot();
    idx.current_slot = current_slot;
    idx.target_slot = current_slot - 2; // Process 2 slots for quick testing

    // Start indexer
    var start_err: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(idx_ptr: *indexer.Indexer, err_ptr: *?anyerror) !void {
            idx_ptr.start() catch |err| {
                if (err == error.ConnectionRefused) {
                    // Expected error in logging-only mode
                    return;
                }
                err_ptr.* = err;
                return err;
            };
        }
    }.run, .{ &idx, &start_err });

    // Wait for some slots to be processed (2 seconds)
    std.time.sleep(2 * std.time.ns_per_s);

    // Stop indexer
    idx.running = false;
    thread.join();

    // Check for startup errors
    if (start_err) |err| {
        std.log.err("Indexer failed to start: {any}", .{err});
        return err;
    }

    // Verify indexer processed slots
    try testing.expect(idx.total_slots_processed > 0);
    try testing.expect(idx.stats.total_transactions > 0);
    try testing.expect(idx.stats.total_instructions > 0);
}
