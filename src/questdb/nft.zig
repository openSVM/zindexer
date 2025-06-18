const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const c_questdb = @import("c-questdb-client");

// NFT-related operations for QuestDB
// These would be similar to the core.zig implementation but using ILP format

/// Insert an NFT collection into QuestDB
pub fn insertNftCollection(self: *@This(), network: []const u8, collection_address: []const u8, slot: u64, block_time: i64, name: []const u8, symbol: []const u8, uri: []const u8, seller_fee_basis_points: u16, creator_addresses: []const []const u8, creator_shares: []const u8) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT collection insert for {s}", .{collection_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_collections,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",collection_address=");
    try ilp_buffer.appendSlice(collection_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",name=\"");
    try ilp_buffer.appendSlice(name);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",symbol=\"");
    try ilp_buffer.appendSlice(symbol);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",uri=\"");
    try ilp_buffer.appendSlice(uri);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",seller_fee_basis_points=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{seller_fee_basis_points});
    
    // Format creator addresses and shares as JSON arrays
    try ilp_buffer.appendSlice(",creator_addresses=\"");
    for (creator_addresses, 0..) |addr, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(addr);
    }
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",creator_shares=\"");
    for (creator_shares, 0..) |share, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try std.fmt.format(ilp_buffer.writer(), "{d}", .{share});
    }
    try ilp_buffer.appendSlice("\"");
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT collection ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}