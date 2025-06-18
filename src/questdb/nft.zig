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
    try ilp_buffer.appendSlice(creator_shares);
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

/// Insert NFT mint into QuestDB
pub fn insertNftMint(self: *@This(), network: []const u8, mint_address: []const u8, slot: u64, block_time: i64, collection_address: []const u8, owner: []const u8, creator_address: []const u8, name: []const u8, symbol: []const u8, uri: []const u8, seller_fee_basis_points: u16, primary_sale_happened: bool, is_mutable: bool, edition_nonce: ?u64, token_standard: []const u8, uses: ?[]const u8) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT mint insert for {s}", .{mint_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_mints,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",mint_address=");
    try ilp_buffer.appendSlice(mint_address);
    try ilp_buffer.appendSlice(",collection_address=");
    try ilp_buffer.appendSlice(collection_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",owner=\"");
    try ilp_buffer.appendSlice(owner);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",creator_address=\"");
    try ilp_buffer.appendSlice(creator_address);
    try ilp_buffer.appendSlice("\"");
    
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
    
    try ilp_buffer.appendSlice(",primary_sale_happened=");
    try std.fmt.format(ilp_buffer.writer(), "{}", .{primary_sale_happened});
    
    try ilp_buffer.appendSlice(",is_mutable=");
    try std.fmt.format(ilp_buffer.writer(), "{}", .{is_mutable});
    
    if (edition_nonce) |nonce| {
        try ilp_buffer.appendSlice(",edition_nonce=");
        try std.fmt.format(ilp_buffer.writer(), "{d}", .{nonce});
    }
    
    try ilp_buffer.appendSlice(",token_standard=\"");
    try ilp_buffer.appendSlice(token_standard);
    try ilp_buffer.appendSlice("\"");
    
    if (uses) |uses_str| {
        try ilp_buffer.appendSlice(",uses=\"");
        try ilp_buffer.appendSlice(uses_str);
        try ilp_buffer.appendSlice("\"");
    }
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT mint ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert NFT listing into QuestDB
pub fn insertNftListing(self: *@This(), network: []const u8, listing_address: []const u8, slot: u64, block_time: i64, marketplace: []const u8, mint_address: []const u8, collection_address: []const u8, seller: []const u8, price_sol: f64, expiry_time: i64, cancelled: bool) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT listing insert for {s}", .{listing_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_listings,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",listing_address=");
    try ilp_buffer.appendSlice(listing_address);
    try ilp_buffer.appendSlice(",marketplace=");
    try ilp_buffer.appendSlice(marketplace);
    try ilp_buffer.appendSlice(",mint_address=");
    try ilp_buffer.appendSlice(mint_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",collection_address=\"");
    try ilp_buffer.appendSlice(collection_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",seller=\"");
    try ilp_buffer.appendSlice(seller);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",price_sol=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{price_sol});
    
    try ilp_buffer.appendSlice(",expiry_time=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{expiry_time});
    
    try ilp_buffer.appendSlice(",cancelled=");
    try std.fmt.format(ilp_buffer.writer(), "{}", .{cancelled});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT listing ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert NFT sale into QuestDB
pub fn insertNftSale(self: *@This(), network: []const u8, signature: []const u8, slot: u64, block_time: i64, marketplace: []const u8, mint_address: []const u8, collection_address: []const u8, seller: []const u8, buyer: []const u8, price_sol: f64, price_usd: f64, fee_amount: f64, royalty_amount: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT sale insert for {s}", .{signature});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_sales,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",signature=");
    try ilp_buffer.appendSlice(signature);
    try ilp_buffer.appendSlice(",marketplace=");
    try ilp_buffer.appendSlice(marketplace);
    try ilp_buffer.appendSlice(",mint_address=");
    try ilp_buffer.appendSlice(mint_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",collection_address=\"");
    try ilp_buffer.appendSlice(collection_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",seller=\"");
    try ilp_buffer.appendSlice(seller);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",buyer=\"");
    try ilp_buffer.appendSlice(buyer);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",price_sol=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{price_sol});
    
    try ilp_buffer.appendSlice(",price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{price_usd});
    
    try ilp_buffer.appendSlice(",fee_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{fee_amount});
    
    try ilp_buffer.appendSlice(",royalty_amount=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{royalty_amount});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT sale ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert NFT bid into QuestDB
pub fn insertNftBid(self: *@This(), network: []const u8, bid_address: []const u8, slot: u64, block_time: i64, marketplace: []const u8, mint_address: []const u8, collection_address: []const u8, bidder: []const u8, price_sol: f64, expiry_time: i64, cancelled: bool) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT bid insert for {s}", .{bid_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_bids,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",bid_address=");
    try ilp_buffer.appendSlice(bid_address);
    try ilp_buffer.appendSlice(",marketplace=");
    try ilp_buffer.appendSlice(marketplace);
    try ilp_buffer.appendSlice(",mint_address=");
    try ilp_buffer.appendSlice(mint_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",collection_address=\"");
    try ilp_buffer.appendSlice(collection_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",bidder=\"");
    try ilp_buffer.appendSlice(bidder);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",price_sol=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{price_sol});
    
    try ilp_buffer.appendSlice(",expiry_time=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{expiry_time});
    
    try ilp_buffer.appendSlice(",cancelled=");
    try std.fmt.format(ilp_buffer.writer(), "{}", .{cancelled});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT bid ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert NFT activity into QuestDB
pub fn insertNftActivity(self: *@This(), network: []const u8, signature: []const u8, slot: u64, block_time: i64, activity_type: []const u8, marketplace: []const u8, mint_address: []const u8, collection_address: []const u8, user_account: []const u8, price_sol: f64, price_usd: f64, success: bool) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT activity insert for {s}", .{signature});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_activity,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",signature=");
    try ilp_buffer.appendSlice(signature);
    try ilp_buffer.appendSlice(",activity_type=");
    try ilp_buffer.appendSlice(activity_type);
    try ilp_buffer.appendSlice(",marketplace=");
    try ilp_buffer.appendSlice(marketplace);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",mint_address=\"");
    try ilp_buffer.appendSlice(mint_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",collection_address=\"");
    try ilp_buffer.appendSlice(collection_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",user_account=\"");
    try ilp_buffer.appendSlice(user_account);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",price_sol=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{price_sol});
    
    try ilp_buffer.appendSlice(",price_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{price_usd});
    
    try ilp_buffer.appendSlice(",success=");
    try std.fmt.format(ilp_buffer.writer(), "{}", .{success});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT activity ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert NFT analytics into QuestDB
pub fn insertNftAnalytics(self: *@This(), network: []const u8, collection_address: []const u8, slot: u64, block_time: i64, mint_count: u64, sale_count: u64, listing_count: u64, bid_count: u64, unique_holders: u64, total_volume_sol: f64, avg_price_sol: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping NFT analytics insert for {s}", .{collection_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("nft_analytics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",collection_address=");
    try ilp_buffer.appendSlice(collection_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",mint_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{mint_count});
    
    try ilp_buffer.appendSlice(",sale_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{sale_count});
    
    try ilp_buffer.appendSlice(",listing_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{listing_count});
    
    try ilp_buffer.appendSlice(",bid_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{bid_count});
    
    try ilp_buffer.appendSlice(",unique_holders=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unique_holders});
    
    try ilp_buffer.appendSlice(",total_volume_sol=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_volume_sol});
    
    try ilp_buffer.appendSlice(",avg_price_sol=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{avg_price_sol});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert NFT analytics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}