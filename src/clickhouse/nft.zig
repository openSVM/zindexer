const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

pub fn insertNftCollection(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_collections
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', {}, {}, {}, {}, {}, {}, {}, '{s}')
    , .{
        data.collection_address, data.slot, data.block_time,
        data.name, data.symbol, data.creator_address,
        data.verified, data.total_supply, data.holder_count,
        data.floor_price_sol, data.volume_24h_sol,
        data.market_cap_sol, data.royalty_bps,
        data.metadata_uri,
    });
    
    try self.executeQuery(query);
}

pub fn insertNftMint(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_mints
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', {}, {}, {}, {}, '{s}', '{s}')
    , .{
        data.mint_address, data.slot, data.block_time,
        data.collection_address, data.owner, data.creator_address,
        data.name, data.symbol, data.uri,
        data.seller_fee_basis_points, data.primary_sale_happened,
        data.is_mutable, data.edition_nonce orelse "null",
        data.token_standard, data.uses orelse "null",
    });
    
    try self.executeQuery(query);
}

pub fn insertNftListing(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_listings
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', {}, {}, {})
    , .{
        data.listing_address, data.slot, data.block_time,
        data.marketplace, data.mint_address, data.collection_address,
        data.seller, data.price_sol, data.expiry_time,
        data.cancelled,
    });
    
    try self.executeQuery(query);
}

pub fn insertNftSale(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_sales
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', {}, {}, {}, {})
    , .{
        data.signature, data.slot, data.block_time,
        data.marketplace, data.mint_address, data.collection_address,
        data.seller, data.buyer, data.price_sol,
        data.price_usd, data.fee_amount, data.royalty_amount,
    });
    
    try self.executeQuery(query);
}

pub fn insertNftBid(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_bids
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', {}, {}, {})
    , .{
        data.bid_address, data.slot, data.block_time,
        data.marketplace, data.mint_address, data.collection_address,
        data.bidder, data.price_sol, data.expiry_time,
        data.cancelled,
    });
    
    try self.executeQuery(query);
}

pub fn insertNftActivity(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_activity
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', {}, {}, {})
    , .{
        data.signature, data.slot, data.block_time,
        data.activity_type, data.marketplace, data.mint_address,
        data.collection_address, data.user_account,
        data.price_sol, data.price_usd, data.success,
    });
    
    try self.executeQuery(query);
}

pub fn insertNftAnalytics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO nft_analytics
        \\VALUES ('{s}', {}, {}, {}, {}, {}, {}, {}, {}, {})
    , .{
        data.collection_address, data.slot, data.block_time,
        data.mint_count, data.sale_count, data.listing_count,
        data.bid_count, data.unique_holders,
        data.total_volume_sol, data.avg_price_sol,
    });
    
    try self.executeQuery(query);
}
