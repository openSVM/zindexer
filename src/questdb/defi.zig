const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const c_questdb = @import("c-questdb-client");

// DeFi-related operations for QuestDB
// These would be similar to the core.zig implementation but using ILP format

/// Insert a liquidity pool into QuestDB
pub fn insertLiquidityPool(self: *@This(), network: []const u8, pool_address: []const u8, slot: u64, block_time: i64, protocol: []const u8, token_a_mint: []const u8, token_b_mint: []const u8, token_a_amount: u64, token_b_amount: u64, lp_token_mint: []const u8, lp_token_supply: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping liquidity pool insert for {s}", .{pool_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("liquidity_pools,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",pool_address=");
    try ilp_buffer.appendSlice(pool_address);
    try ilp_buffer.appendSlice(",protocol=");
    try ilp_buffer.appendSlice(protocol);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",token_a_mint=\"");
    try ilp_buffer.appendSlice(token_a_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_b_mint=\"");
    try ilp_buffer.appendSlice(token_b_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_a_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_a_amount});
    
    try ilp_buffer.appendSlice(",token_b_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_b_amount});
    
    try ilp_buffer.appendSlice(",lp_token_mint=\"");
    try ilp_buffer.appendSlice(lp_token_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",lp_token_supply=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{lp_token_supply});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert liquidity pool ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert a pool swap into QuestDB
pub fn insertPoolSwap(self: *@This(), network: []const u8, signature: []const u8, slot: u64, block_time: i64, pool_address: []const u8, user_account: []const u8, token_in_mint: []const u8, token_out_mint: []const u8, token_in_amount: u64, token_out_amount: u64, token_in_price_usd: f64, token_out_price_usd: f64, fee_amount: u64, program_id: []const u8) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping pool swap insert for {s}", .{signature});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("pool_swaps,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",signature=");
    try ilp_buffer.appendSlice(signature);
    try ilp_buffer.appendSlice(",pool_address=");
    try ilp_buffer.appendSlice(pool_address);
    try ilp_buffer.appendSlice(",program_id=");
    try ilp_buffer.appendSlice(program_id);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",user_account=\"");
    try ilp_buffer.appendSlice(user_account);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_in_mint=\"");
    try ilp_buffer.appendSlice(token_in_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_out_mint=\"");
    try ilp_buffer.appendSlice(token_out_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_in_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_in_amount});
    
    try ilp_buffer.appendSlice(",token_out_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_out_amount});
    
    try ilp_buffer.appendSlice(",token_in_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_in_price_usd});
    
    try ilp_buffer.appendSlice(",token_out_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_out_price_usd});
    
    try ilp_buffer.appendSlice(",fee_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{fee_amount});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert pool swap ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert lending market into QuestDB
pub fn insertLendingMarket(self: *@This(), network: []const u8, market_address: []const u8, slot: u64, block_time: i64, protocol_id: []const u8, asset_mint: []const u8, c_token_mint: []const u8, total_deposits: u64, total_borrows: u64, deposit_rate: f64, borrow_rate: f64, utilization_rate: f64, liquidation_threshold: f64, ltv_ratio: f64, asset_price_usd: f64, tvl_usd: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping lending market insert for {s}", .{market_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("lending_markets,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",market_address=");
    try ilp_buffer.appendSlice(market_address);
    try ilp_buffer.appendSlice(",protocol_id=");
    try ilp_buffer.appendSlice(protocol_id);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",asset_mint=\"");
    try ilp_buffer.appendSlice(asset_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",c_token_mint=\"");
    try ilp_buffer.appendSlice(c_token_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",total_deposits=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_deposits});
    
    try ilp_buffer.appendSlice(",total_borrows=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_borrows});
    
    try ilp_buffer.appendSlice(",deposit_rate=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{deposit_rate});
    
    try ilp_buffer.appendSlice(",borrow_rate=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{borrow_rate});
    
    try ilp_buffer.appendSlice(",utilization_rate=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{utilization_rate});
    
    try ilp_buffer.appendSlice(",liquidation_threshold=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{liquidation_threshold});
    
    try ilp_buffer.appendSlice(",ltv_ratio=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{ltv_ratio});
    
    try ilp_buffer.appendSlice(",asset_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{asset_price_usd});
    
    try ilp_buffer.appendSlice(",tvl_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{tvl_usd});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert lending market ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert lending position into QuestDB
pub fn insertLendingPosition(self: *@This(), network: []const u8, position_address: []const u8, slot: u64, block_time: i64, market_address: []const u8, owner: []const u8, deposit_amount: u64, borrow_amount: u64, collateral_amount: u64, liquidation_threshold: f64, health_factor: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping lending position insert for {s}", .{position_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("lending_positions,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",position_address=");
    try ilp_buffer.appendSlice(position_address);
    try ilp_buffer.appendSlice(",market_address=");
    try ilp_buffer.appendSlice(market_address);
    try ilp_buffer.appendSlice(",owner=");
    try ilp_buffer.appendSlice(owner);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",deposit_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{deposit_amount});
    
    try ilp_buffer.appendSlice(",borrow_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{borrow_amount});
    
    try ilp_buffer.appendSlice(",collateral_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{collateral_amount});
    
    try ilp_buffer.appendSlice(",liquidation_threshold=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{liquidation_threshold});
    
    try ilp_buffer.appendSlice(",health_factor=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{health_factor});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert lending position ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert perpetual market into QuestDB
pub fn insertPerpetualMarket(self: *@This(), network: []const u8, market_address: []const u8, slot: u64, block_time: i64, protocol_id: []const u8, base_token_mint: []const u8, quote_token_mint: []const u8, base_price_usd: f64, mark_price_usd: f64, index_price_usd: f64, funding_rate: f64, open_interest: u64, volume_24h_usd: f64, base_deposit_total: u64, quote_deposit_total: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping perpetual market insert for {s}", .{market_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("perpetual_markets,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",market_address=");
    try ilp_buffer.appendSlice(market_address);
    try ilp_buffer.appendSlice(",protocol_id=");
    try ilp_buffer.appendSlice(protocol_id);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",base_token_mint=\"");
    try ilp_buffer.appendSlice(base_token_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",quote_token_mint=\"");
    try ilp_buffer.appendSlice(quote_token_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",base_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{base_price_usd});
    
    try ilp_buffer.appendSlice(",mark_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{mark_price_usd});
    
    try ilp_buffer.appendSlice(",index_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{index_price_usd});
    
    try ilp_buffer.appendSlice(",funding_rate=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{funding_rate});
    
    try ilp_buffer.appendSlice(",open_interest=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{open_interest});
    
    try ilp_buffer.appendSlice(",volume_24h_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{volume_24h_usd});
    
    try ilp_buffer.appendSlice(",base_deposit_total=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{base_deposit_total});
    
    try ilp_buffer.appendSlice(",quote_deposit_total=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{quote_deposit_total});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert perpetual market ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert perpetual position into QuestDB
pub fn insertPerpetualPosition(self: *@This(), network: []const u8, position_address: []const u8, slot: u64, block_time: i64, market_address: []const u8, owner: []const u8, position_size: i64, entry_price: f64, liquidation_price: f64, unrealized_pnl: f64, realized_pnl: f64, collateral_amount: u64, leverage: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping perpetual position insert for {s}", .{position_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("perpetual_positions,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",position_address=");
    try ilp_buffer.appendSlice(position_address);
    try ilp_buffer.appendSlice(",market_address=");
    try ilp_buffer.appendSlice(market_address);
    try ilp_buffer.appendSlice(",owner=");
    try ilp_buffer.appendSlice(owner);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",position_size=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{position_size});
    
    try ilp_buffer.appendSlice(",entry_price=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{entry_price});
    
    try ilp_buffer.appendSlice(",liquidation_price=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{liquidation_price});
    
    try ilp_buffer.appendSlice(",unrealized_pnl=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unrealized_pnl});
    
    try ilp_buffer.appendSlice(",realized_pnl=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{realized_pnl});
    
    try ilp_buffer.appendSlice(",collateral_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{collateral_amount});
    
    try ilp_buffer.appendSlice(",leverage=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{leverage});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert perpetual position ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert DeFi event into QuestDB
pub fn insertDefiEvent(self: *@This(), network: []const u8, signature: []const u8, slot: u64, block_time: i64, protocol_id: []const u8, event_type: []const u8, user_account: []const u8, market_address: []const u8, token_a_mint: []const u8, token_b_mint: []const u8, token_a_amount: u64, token_b_amount: u64, token_a_price_usd: f64, token_b_price_usd: f64, fee_amount: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping DeFi event insert for {s}", .{signature});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("defi_events,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",signature=");
    try ilp_buffer.appendSlice(signature);
    try ilp_buffer.appendSlice(",protocol_id=");
    try ilp_buffer.appendSlice(protocol_id);
    try ilp_buffer.appendSlice(",event_type=");
    try ilp_buffer.appendSlice(event_type);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",user_account=\"");
    try ilp_buffer.appendSlice(user_account);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",market_address=\"");
    try ilp_buffer.appendSlice(market_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_a_mint=\"");
    try ilp_buffer.appendSlice(token_a_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_b_mint=\"");
    try ilp_buffer.appendSlice(token_b_mint);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",token_a_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_a_amount});
    
    try ilp_buffer.appendSlice(",token_b_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_b_amount});
    
    try ilp_buffer.appendSlice(",token_a_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_a_price_usd});
    
    try ilp_buffer.appendSlice(",token_b_price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{token_b_price_usd});
    
    try ilp_buffer.appendSlice(",fee_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{fee_amount});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert DeFi event ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert DeFi analytics into QuestDB
pub fn insertDefiAnalytics(self: *@This(), network: []const u8, protocol_id: []const u8, slot: u64, block_time: i64, tvl_usd: f64, volume_24h_usd: f64, fee_24h_usd: f64, unique_users_24h: u64, transaction_count_24h: u64, revenue_24h_usd: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping DeFi analytics insert for {s}", .{protocol_id});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("defi_analytics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",protocol_id=");
    try ilp_buffer.appendSlice(protocol_id);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",tvl_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{tvl_usd});
    
    try ilp_buffer.appendSlice(",volume_24h_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{volume_24h_usd});
    
    try ilp_buffer.appendSlice(",fee_24h_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{fee_24h_usd});
    
    try ilp_buffer.appendSlice(",unique_users_24h=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unique_users_24h});
    
    try ilp_buffer.appendSlice(",transaction_count_24h=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{transaction_count_24h});
    
    try ilp_buffer.appendSlice(",revenue_24h_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{revenue_24h_usd});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert DeFi analytics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}