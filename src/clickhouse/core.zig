const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

fn jsonToString(allocator: Allocator, value: anytype) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();
    try std.json.stringify(value, .{}, buf.writer());
    return buf.toOwnedSlice();
}

pub fn insertTransaction(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const program_ids_json = try types.arrayToJson(arena.allocator(), data.program_ids);
    const signers_json = try types.arrayToJson(arena.allocator(), data.signers);
    const account_keys_json = try types.arrayToJson(arena.allocator(), data.account_keys);
    const log_messages_json = try types.arrayToJson(arena.allocator(), data.log_messages);
    
    // Convert balance arrays to JSON strings
    var pre_balances = std.ArrayList(u8).init(arena.allocator());
    defer pre_balances.deinit();
    try std.json.stringify(data.pre_balances, .{}, pre_balances.writer());
    
    var post_balances = std.ArrayList(u8).init(arena.allocator());
    defer post_balances.deinit();
    try std.json.stringify(data.post_balances, .{}, post_balances.writer());
    
    var pre_token_balances = std.ArrayList(u8).init(arena.allocator());
    defer pre_token_balances.deinit();
    try std.json.stringify(data.pre_token_balances, .{}, pre_token_balances.writer());
    
    var post_token_balances = std.ArrayList(u8).init(arena.allocator());
    defer post_token_balances.deinit();
    try std.json.stringify(data.post_token_balances, .{}, post_token_balances.writer());
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO transactions 
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', '{s}')
    , .{
        data.signature, data.slot, data.block_time, data.success, data.fee,
        data.compute_units_consumed, data.compute_units_price, data.recent_blockhash,
        program_ids_json, signers_json, account_keys_json,
        pre_balances.items, post_balances.items,
        pre_token_balances.items, post_token_balances.items,
        log_messages_json,
    });
    
    try self.executeQuery(query);
}

pub fn insertProgramExecution(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO program_executions
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, {})
    , .{
        data.program_id, data.slot, data.block_time,
        data.execution_count, data.total_cu_consumed,
        data.total_fee, data.success_count, data.error_count,
    });
    
    try self.executeQuery(query);
}

pub fn insertProgramMetrics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO program_metrics
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.program_id, data.slot, data.block_time,
        data.total_transactions, data.unique_users,
        data.total_compute_units, data.total_fees,
        data.avg_compute_units, data.avg_fees,
        data.error_rate,
    });
    
    try self.executeQuery(query);
}

pub fn insertAccountMetrics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO account_metrics
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.pubkey, data.slot, data.block_time,
        data.total_transactions, data.write_count,
        data.total_compute_units, data.total_fees,
        data.avg_compute_units, data.avg_fees,
        data.program_interaction_count,
    });
    
    try self.executeQuery(query);
}

pub fn insertBlockMetrics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO block_metrics
        \\VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.slot, data.block_time,
        data.transaction_count, data.successful_transactions,
        data.total_compute_units, data.total_fees,
        data.unique_signers, data.unique_programs,
        data.avg_compute_units, data.avg_fees,
    });
    
    try self.executeQuery(query);
}
