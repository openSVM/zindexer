const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

// Account-related operations for QuestDB
// These would be similar to the core.zig implementation but using ILP format

/// Insert an account into QuestDB
pub fn insertAccount(self: *@This(), network: []const u8, pubkey: []const u8, slot: u64, block_time: i64, owner: []const u8, lamports: u64, executable: u8, rent_epoch: u64, data_len: u64, write_version: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping account insert for {s}", .{pubkey});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("accounts,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",pubkey=");
    try ilp_buffer.appendSlice(pubkey);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",owner=\"");
    try ilp_buffer.appendSlice(owner);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",lamports=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{lamports});
    
    try ilp_buffer.appendSlice(",executable=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{executable});
    
    try ilp_buffer.appendSlice(",rent_epoch=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{rent_epoch});
    
    try ilp_buffer.appendSlice(",data_len=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{data_len});
    
    try ilp_buffer.appendSlice(",write_version=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{write_version});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = // c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert account ILP data: {any}", .{err});
}

/// Insert an account update into QuestDB
pub fn insertAccountUpdate(self: *@This(), network: []const u8, pubkey: []const u8, slot: u64, block_time: i64, owner: []const u8, lamports: u64, executable: u8, rent_epoch: u64, data_len: u64, write_version: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping account update insert for {s}", .{pubkey});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("account_updates,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",pubkey=");
    try ilp_buffer.appendSlice(pubkey);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",owner=\"");
    try ilp_buffer.appendSlice(owner);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",lamports=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{lamports});
    
    try ilp_buffer.appendSlice(",executable=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{executable});
    
    try ilp_buffer.appendSlice(",rent_epoch=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{rent_epoch});
    
    try ilp_buffer.appendSlice(",data_len=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{data_len});
    
    try ilp_buffer.appendSlice(",write_version=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{write_version});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = // c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert account update ILP data: {any}", .{err});
}