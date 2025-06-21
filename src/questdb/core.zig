const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

/// Insert a block into QuestDB
pub fn insertBlock(self: *@This(), network: []const u8, slot: u64, blockhash: []const u8, previous_blockhash: []const u8, parent_slot: u64, block_time: i64, block_height: ?u64, leader_identity: []const u8, rewards: f64, transaction_count: u32, successful_transaction_count: u32, failed_transaction_count: u32) !void {
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
    try std.fmt.format(ilp_buffer.writer(), "{f}", .{rewards});
    
    try ilp_buffer.appendSlice(",transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{transaction_count});
    
    try ilp_buffer.appendSlice(",successful_transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{successful_transaction_count});
    
    try ilp_buffer.appendSlice(",failed_transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{failed_transaction_count});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    try self.sendILP(ilp_buffer.items);
}

/// Insert a transaction into QuestDB
pub fn insertTransaction(self: *@This(), network: []const u8, signature: []const u8, slot: u64, block_time: i64, success: bool, fee: u64, compute_units_consumed: u64, compute_units_price: u64, recent_blockhash: []const u8, program_ids: []const []const u8, signers: []const []const u8, account_keys: []const []const u8, pre_balances: []const u8, post_balances: []const u8, pre_token_balances: []const u8, post_token_balances: []const u8, log_messages: []const []const u8, error_msg: ?[]const u8) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("transactions,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",signature=");
    try ilp_buffer.appendSlice(signature);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",success=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{if (success) 1 else 0});
    
    try ilp_buffer.appendSlice(",fee=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{fee});
    
    try ilp_buffer.appendSlice(",compute_units_consumed=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{compute_units_consumed});
    
    try ilp_buffer.appendSlice(",compute_units_price=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{compute_units_price});
    
    try ilp_buffer.appendSlice(",recent_blockhash=\"");
    try ilp_buffer.appendSlice(recent_blockhash);
    try ilp_buffer.appendSlice("\"");
    
    if (error_msg) |err_msg| {
        try ilp_buffer.appendSlice(",error_msg=\"");
        try ilp_buffer.appendSlice(err_msg);
        try ilp_buffer.appendSlice("\"");
    }
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    try self.sendILP(ilp_buffer.items);
}

/// Insert program execution metrics into QuestDB
pub fn insertProgramExecution(self: *@This(), network: []const u8, program_id: []const u8, slot: u64, block_time: i64, execution_count: u32, total_cu_consumed: u64, total_fee: u64, success_count: u32, error_count: u32) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("program_executions,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",program_id=");
    try ilp_buffer.appendSlice(program_id);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",execution_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{execution_count});
    
    try ilp_buffer.appendSlice(",total_cu_consumed=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_cu_consumed});
    
    try ilp_buffer.appendSlice(",total_fee=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_fee});
    
    try ilp_buffer.appendSlice(",success_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{success_count});
    
    try ilp_buffer.appendSlice(",error_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{error_count});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    try self.sendILP(ilp_buffer.items);
}

/// Insert program metrics into QuestDB
pub fn insertProgramMetrics(self: *@This(), network: []const u8, program_id: []const u8, slot: u64, block_time: i64, total_transactions: u64, unique_users: u64, total_compute_units: u64, total_fees: u64, avg_compute_units: f64, avg_fees: f64, error_rate: f64) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("program_metrics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",program_id=");
    try ilp_buffer.appendSlice(program_id);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",total_transactions=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_transactions});
    
    try ilp_buffer.appendSlice(",unique_users=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unique_users});
    
    try ilp_buffer.appendSlice(",total_compute_units=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_compute_units});
    
    try ilp_buffer.appendSlice(",total_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_fees});
    
    try ilp_buffer.appendSlice(",avg_compute_units=");
    try std.fmt.format(ilp_buffer.writer(), "{f}", .{avg_compute_units});
    
    try ilp_buffer.appendSlice(",avg_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{f}", .{avg_fees});
    
    try ilp_buffer.appendSlice(",error_rate=");
    try std.fmt.format(ilp_buffer.writer(), "{f}", .{error_rate});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    try self.sendILP(ilp_buffer.items);
}

/// Insert an account activity record into QuestDB
pub fn insertAccountActivity(self: *@This(), network: []const u8, account: []const u8, slot: u64, block_time: i64, transaction_count: u32, total_sol_transferred: u64, total_fee_paid: u64, program_interactions: []const []const u8, transaction_signatures: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("account_activity,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",account=");
    try ilp_buffer.appendSlice(account);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{transaction_count});
    
    try ilp_buffer.appendSlice(",total_sol_transferred=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_sol_transferred});
    
    try ilp_buffer.appendSlice(",total_fee_paid=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_fee_paid});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    try self.sendILP(ilp_buffer.items);
}