const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const c_questdb = @import("c-questdb-client");

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
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert block ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert a transaction into QuestDB
pub fn insertTransaction(self: *@This(), network: []const u8, signature: []const u8, slot: u64, block_time: i64, success: bool, fee: u64, compute_units_consumed: u64, compute_units_price: u64, recent_blockhash: []const u8, program_ids: []const []const u8, signers: []const []const u8, account_keys: []const []const u8, pre_balances: []const u8, post_balances: []const u8, pre_token_balances: []const u8, post_token_balances: []const u8, log_messages: []const []const u8, error_msg: ?[]const u8) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping transaction insert for signature {s}", .{signature});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

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
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert transaction ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert program execution metrics into QuestDB
pub fn insertProgramExecution(self: *@This(), network: []const u8, program_id: []const u8, slot: u64, block_time: i64, execution_count: u32, total_cu_consumed: u64, total_fee: u64, success_count: u32, error_count: u32) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping program execution insert for program {s}", .{program_id});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

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
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert program execution ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert program metrics into QuestDB
pub fn insertProgramMetrics(self: *@This(), network: []const u8, program_id: []const u8, slot: u64, block_time: i64, total_transactions: u64, unique_users: u64, total_compute_units: u64, total_fees: u64, avg_compute_units: f64, avg_fees: f64, error_rate: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping program metrics insert for program {s}", .{program_id});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

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
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_compute_units});
    
    try ilp_buffer.appendSlice(",avg_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_fees});
    
    try ilp_buffer.appendSlice(",error_rate=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{error_rate});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert program metrics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert account metrics into QuestDB
pub fn insertAccountMetrics(self: *@This(), network: []const u8, pubkey: []const u8, slot: u64, block_time: i64, total_transactions: u64, write_count: u64, total_compute_units: u64, total_fees: u64, avg_compute_units: f64, avg_fees: f64, program_interaction_count: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping account metrics insert for account {s}", .{pubkey});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("account_metrics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",pubkey=");
    try ilp_buffer.appendSlice(pubkey);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",total_transactions=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_transactions});
    
    try ilp_buffer.appendSlice(",write_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{write_count});
    
    try ilp_buffer.appendSlice(",total_compute_units=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_compute_units});
    
    try ilp_buffer.appendSlice(",total_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_fees});
    
    try ilp_buffer.appendSlice(",avg_compute_units=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_compute_units});
    
    try ilp_buffer.appendSlice(",avg_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_fees});
    
    try ilp_buffer.appendSlice(",program_interaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{program_interaction_count});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert account metrics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert block metrics into QuestDB
pub fn insertBlockMetrics(self: *@This(), network: []const u8, slot: u64, block_time: i64, transaction_count: u32, successful_transactions: u32, total_compute_units: u64, total_fees: u64, unique_signers: u32, unique_programs: u32, avg_compute_units: f64, avg_fees: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping block metrics insert for slot {d}", .{slot});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("block_metrics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",transaction_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{transaction_count});
    
    try ilp_buffer.appendSlice(",successful_transactions=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{successful_transactions});
    
    try ilp_buffer.appendSlice(",total_compute_units=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_compute_units});
    
    try ilp_buffer.appendSlice(",total_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_fees});
    
    try ilp_buffer.appendSlice(",unique_signers=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unique_signers});
    
    try ilp_buffer.appendSlice(",unique_programs=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unique_programs});
    
    try ilp_buffer.appendSlice(",avg_compute_units=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_compute_units});
    
    try ilp_buffer.appendSlice(",avg_fees=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_fees});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert block metrics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}