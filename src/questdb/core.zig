const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

/// Insert a block into QuestDB
pub fn insertBlock(self: *@This(), network: []const u8, slot: u64, blockhash: []const u8, previous_blockhash: []const u8, parent_slot: u64, block_time: i64, block_height: ?u64, leader_identity: []const u8, rewards: f64, transaction_count: u32, successful_transaction_count: u32, failed_transaction_count: u32) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping block insert for slot {d}", .{slot});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("blocks,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",blockhash=\"");
    try ilp_buffer.appendSlice(blockhash);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",previous_blockhash=\"");
    try ilp_buffer.appendSlice(previous_blockhash);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",parent_slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{parent_slot});
    
    if (block_height) |height| {
        try ilp_buffer.appendSlice(",block_height=");
        try std.fmt.format(ilp_buffer.writer(), "{d}", .{height});
    }
    
    try ilp_buffer.appendSlice(",leader_identity=\"");
    try ilp_buffer.appendSlice(leader_identity);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",rewards=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{rewards});
    
    try ilp_buffer.appendSlice(",transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{transaction_count});
    
    try ilp_buffer.appendSlice(",successful_transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{successful_transaction_count});
    
    try ilp_buffer.appendSlice(",failed_transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{failed_transaction_count});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = // c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert block ILP data: {any}", .{err});
}