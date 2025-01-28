const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

pub fn insertPoolSwap(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO pool_swaps
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', {}, {}, {}, {}, {}, '{s}')
    , .{
        data.signature, data.slot, data.block_time,
        data.pool_address, data.user_account,
        data.token_in_mint, data.token_out_mint,
        data.token_in_amount, data.token_out_amount,
        data.token_in_price_usd, data.token_out_price_usd,
        data.fee_amount, data.program_id,
    });
    
    try self.executeQuery(query);
}

pub fn insertLiquidityPool(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO liquidity_pools
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.pool_address, data.slot, data.block_time,
        data.amm_id, data.token_a_mint, data.token_b_mint,
        data.token_a_amount, data.token_b_amount,
        data.token_a_price_usd, data.token_b_price_usd,
        data.tvl_usd, data.fee_rate,
        data.volume_24h_usd, data.apy_24h,
    });
    
    try self.executeQuery(query);
}

pub fn insertLendingMarket(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO lending_markets
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', {}, {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.market_address, data.slot, data.block_time,
        data.protocol_id, data.asset_mint, data.c_token_mint,
        data.total_deposits, data.total_borrows,
        data.deposit_rate, data.borrow_rate,
        data.utilization_rate, data.liquidation_threshold,
        data.ltv_ratio, data.asset_price_usd, data.tvl_usd,
    });
    
    try self.executeQuery(query);
}

pub fn insertLendingPosition(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO lending_positions
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', {}, {}, {}, {}, {})
    , .{
        data.position_address, data.slot, data.block_time,
        data.market_address, data.owner,
        data.deposit_amount, data.borrow_amount,
        data.collateral_amount, data.liquidation_threshold,
        data.health_factor,
    });
    
    try self.executeQuery(query);
}

pub fn insertPerpetualMarket(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO perpetual_markets
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.market_address, data.slot, data.block_time,
        data.protocol_id, data.base_token_mint, data.quote_token_mint,
        data.base_price_usd, data.mark_price_usd,
        data.index_price_usd, data.funding_rate,
        data.open_interest, data.volume_24h_usd,
        data.base_deposit_total, data.quote_deposit_total,
    });
    
    try self.executeQuery(query);
}

pub fn insertPerpetualPosition(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO perpetual_positions
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', {}, {}, {}, {}, {}, {}, {})
    , .{
        data.position_address, data.slot, data.block_time,
        data.market_address, data.owner, data.position_size,
        data.entry_price, data.liquidation_price,
        data.unrealized_pnl, data.realized_pnl,
        data.collateral_amount, data.leverage,
    });
    
    try self.executeQuery(query);
}

pub fn insertDefiEvent(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO defi_events
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', {}, {}, {}, {}, {})
    , .{
        data.signature, data.slot, data.block_time,
        data.protocol_id, data.event_type, data.user_account,
        data.market_address, data.token_a_mint, data.token_b_mint,
        data.token_a_amount, data.token_b_amount,
        data.token_a_price_usd, data.token_b_price_usd,
        data.fee_amount,
    });
    
    try self.executeQuery(query);
}

pub fn insertDefiAnalytics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO defi_analytics
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.protocol_id, data.slot, data.block_time,
        data.tvl_usd, data.volume_24h_usd, data.fee_24h_usd,
        data.unique_users_24h, data.transaction_count_24h,
        data.revenue_24h_usd,
    });
    
    try self.executeQuery(query);
}
