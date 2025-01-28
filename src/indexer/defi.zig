const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processDefiOperations(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    tx_json: std.json.Value,
    swap_count: *u32,
    deposit_count: *u32,
    withdraw_count: *u32,
    borrow_count: *u32,
    repay_count: *u32,
    liquidate_count: *u32,
) !void {
    const tx = tx_json.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    const signature = tx.get("transaction").?.object.get("signatures").?.array.items[0].string;
    
    // Process instructions
    const instructions = message.get("instructions").?.array;
    for (instructions.items) |ix| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = message.get("accountKeys").?.array.items[program_idx].string;
        
        const protocol = types.DefiProtocol.fromProgramId(program_id);
        if (protocol == .Unknown) continue;
        
        // Extract instruction accounts
        var accounts = std.ArrayList([]const u8).init(indexer.allocator);
        defer accounts.deinit();
        
        for (ix.object.get("accounts").?.array.items) |acc_idx| {
            const account = message.get("accountKeys").?.array.items[@as(usize, @intCast(acc_idx.integer))].string;
            try accounts.append(account);
        }
        
        // Process by protocol
        switch (protocol) {
            .Orca, .Raydium => try processAmmInstruction(
                indexer,
                slot,
                block_time,
                signature,
                program_id,
                accounts.items,
                swap_count,
            ),
            .Marinade => try processStakingInstruction(
                indexer,
                slot,
                block_time,
                signature,
                program_id,
                accounts.items,
                deposit_count,
                withdraw_count,
            ),
            .Solend => try processLendingInstruction(
                indexer,
                slot,
                block_time,
                signature,
                program_id,
                accounts.items,
                deposit_count,
                withdraw_count,
                borrow_count,
                repay_count,
                liquidate_count,
            ),
            .Mango, .Drift => try processPerpInstruction(
                indexer,
                slot,
                block_time,
                signature,
                program_id,
                accounts.items,
            ),
            else => {},
        }
    }
}

fn processAmmInstruction(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    _: []const u8, // signature
    program_id: []const u8,
    accounts: []const []const u8,
    swap_count: *u32,
) !void {
    // TODO: Parse instruction data to determine event type
    // For now, just count all instructions as swaps
    swap_count.* += 1;
    
    // Record pool swap
    try indexer.db_client.insertPoolSwap(.{
        .signature = "", // TODO: Use actual signature
        .slot = slot,
        .block_time = block_time,
        .pool_address = accounts[1], // Assume first non-user account is pool
        .user_account = accounts[0],
        .token_in_mint = "", // TODO: Extract token info
        .token_out_mint = "",
        .token_in_amount = 0,
        .token_out_amount = 0,
        .token_in_price_usd = 0,
        .token_out_price_usd = 0,
        .fee_amount = 0,
        .program_id = program_id,
    });
    
    // Update liquidity pool
    try indexer.db_client.insertLiquidityPool(.{
        .pool_address = accounts[1],
        .slot = slot,
        .block_time = block_time,
        .amm_id = program_id,
        .token_a_mint = "", // TODO: Extract token info
        .token_b_mint = "",
        .token_a_amount = 0,
        .token_b_amount = 0,
        .token_a_price_usd = 0,
        .token_b_price_usd = 0,
        .tvl_usd = 0,
        .fee_rate = 0,
        .volume_24h_usd = 0,
        .apy_24h = 0,
    });
}

fn processStakingInstruction(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    _: []const u8, // signature
    program_id: []const u8,
    accounts: []const []const u8,
    deposit_count: *u32,
    _: *u32, // withdraw_count
) !void {
    // TODO: Parse instruction data to determine event type
    // For now, just count all instructions as deposits
    deposit_count.* += 1;
    
    // Record DeFi event
    try indexer.db_client.insertDefiEvent(.{
        .signature = "", // TODO: Use actual signature
        .slot = slot,
        .block_time = block_time,
        .protocol_id = program_id,
        .event_type = "deposit",
        .user_account = accounts[0],
        .market_address = accounts[1],
        .token_a_mint = "", // TODO: Extract token info
        .token_b_mint = "",
        .token_a_amount = 0,
        .token_b_amount = 0,
        .token_a_price_usd = 0,
        .token_b_price_usd = 0,
        .fee_amount = 0,
    });
}

fn processLendingInstruction(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    _: []const u8, // signature
    program_id: []const u8,
    accounts: []const []const u8,
    deposit_count: *u32,
    _: *u32, // withdraw_count
    _: *u32, // borrow_count
    _: *u32, // repay_count
    _: *u32, // liquidate_count
) !void {
    // TODO: Parse instruction data to determine event type
    // For now, just count all instructions as deposits
    deposit_count.* += 1;
    
    // Update lending market
    try indexer.db_client.insertLendingMarket(.{
        .market_address = accounts[1],
        .slot = slot,
        .block_time = block_time,
        .protocol_id = program_id,
        .asset_mint = "", // TODO: Extract token info
        .c_token_mint = "",
        .total_deposits = 0,
        .total_borrows = 0,
        .deposit_rate = 0,
        .borrow_rate = 0,
        .utilization_rate = 0,
        .liquidation_threshold = 0,
        .ltv_ratio = 0,
        .asset_price_usd = 0,
        .tvl_usd = 0,
    });
    
    // Update lending position
    try indexer.db_client.insertLendingPosition(.{
        .position_address = accounts[0],
        .slot = slot,
        .block_time = block_time,
        .market_address = accounts[1],
        .owner = accounts[0],
        .deposit_amount = 0, // TODO: Extract amounts
        .borrow_amount = 0,
        .collateral_amount = 0,
        .liquidation_threshold = 0,
        .health_factor = 0,
    });
}

fn processPerpInstruction(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    _: []const u8, // signature
    program_id: []const u8,
    accounts: []const []const u8,
) !void {
    // Update perpetual market
    try indexer.db_client.insertPerpetualMarket(.{
        .market_address = accounts[1],
        .slot = slot,
        .block_time = block_time,
        .protocol_id = program_id,
        .base_token_mint = "", // TODO: Extract token info
        .quote_token_mint = "",
        .base_price_usd = 0,
        .mark_price_usd = 0,
        .index_price_usd = 0,
        .funding_rate = 0,
        .open_interest = 0,
        .volume_24h_usd = 0,
        .base_deposit_total = 0,
        .quote_deposit_total = 0,
    });
    
    // Update perpetual position
    try indexer.db_client.insertPerpetualPosition(.{
        .position_address = accounts[0],
        .slot = slot,
        .block_time = block_time,
        .market_address = accounts[1],
        .owner = accounts[0],
        .position_size = 0, // TODO: Extract position info
        .entry_price = 0,
        .liquidation_price = 0,
        .unrealized_pnl = 0,
        .realized_pnl = 0,
        .collateral_amount = 0,
        .leverage = 0,
    });
}
