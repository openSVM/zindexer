const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

pub fn insertTokenAccount(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_accounts
        \\VALUES ('{s}', '{s}', {}, {}, '{s}', {}, '{s}', {}, {}, {}, {}, {}, '{s}')
    , .{
        data.account_address, data.mint_address, data.slot,
        data.block_time, data.owner, data.amount,
        data.delegate orelse "null", data.delegated_amount,
        data.is_initialized, data.is_frozen, data.is_native,
        data.rent_exempt_reserve orelse "null",
        data.close_authority orelse "null",
    });
    
    try self.executeQuery(query);
}

pub fn insertTokenTransfer(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_transfers
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', {}, {}, '{s}', '{s}')
    , .{
        data.signature, data.slot, data.block_time,
        data.mint_address, data.from_account, data.to_account,
        data.amount, data.decimals, data.program_id,
        data.instruction_type,
    });
    
    try self.executeQuery(query);
}

pub fn insertTokenHolder(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_holders
        \\VALUES ('{s}', {}, {}, '{s}', {}, {})
    , .{
        data.mint_address, data.slot, data.block_time,
        data.owner, data.balance, data.balance_usd,
    });
    
    try self.executeQuery(query);
}

pub fn insertTokenAnalytics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_analytics
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, {})
    , .{
        data.mint_address, data.slot, data.block_time,
        data.transfer_count, data.unique_holders,
        data.active_accounts, data.total_volume_usd,
        data.avg_transaction_size,
    });
    
    try self.executeQuery(query);
}

pub fn insertTokenProgramActivity(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_program_activity
        \\VALUES ('{s}', {}, {}, '{s}', {}, {}, {}, {})
    , .{
        data.program_id, data.slot, data.block_time,
        data.instruction_type, data.execution_count,
        data.error_count, data.unique_users,
        data.unique_tokens,
    });
    
    try self.executeQuery(query);
}

pub fn insertTokenSupplyHistory(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_supply_history
        \\VALUES ('{s}', {}, {}, {}, {}, {})
    , .{
        data.mint_address, data.slot, data.block_time,
        data.total_supply, data.circulating_supply,
        data.holder_count,
    });
    
    try self.executeQuery(query);
}

pub fn insertTokenPrice(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO token_prices
        \\VALUES ('{s}', {}, {}, {}, {}, {}, '{s}')
    , .{
        data.mint_address, data.slot, data.block_time,
        data.price_usd, data.volume_usd, data.liquidity_usd,
        data.source,
    });
    
    try self.executeQuery(query);
}
