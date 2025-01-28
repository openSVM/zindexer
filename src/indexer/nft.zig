const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processNftOperations(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    tx_json: std.json.Value,
    mint_count: *u32,
    sale_count: *u32,
    listing_count: *u32,
    bid_count: *u32,
) !void {
    const tx = tx_json.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    const signature = tx.get("transaction").?.object.get("signatures").?.array.items[0].string;
    
    // Process instructions
    const instructions = message.get("instructions").?.array;
    for (instructions.items) |ix| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = message.get("accountKeys").?.array.items[program_idx].string;
        
        // Extract instruction accounts
        var accounts = std.ArrayList([]const u8).init(indexer.allocator);
        defer accounts.deinit();
        
        for (ix.object.get("accounts").?.array.items) |acc_idx| {
            const account = message.get("accountKeys").?.array.items[@as(usize, @intCast(acc_idx.integer))].string;
            try accounts.append(account);
        }
        
        // Check if instruction is from NFT programs
        if (std.mem.eql(u8, program_id, types.METADATA_PROGRAM_ID) or
            std.mem.eql(u8, program_id, types.CANDY_MACHINE_PROGRAM_ID) or
            std.mem.eql(u8, program_id, types.AUCTION_HOUSE_PROGRAM_ID) or
            std.mem.eql(u8, program_id, types.MAGIC_EDEN_PROGRAM_ID)) {
            
            const data = ix.object.get("data").?.string;
            const instruction_type = types.NftInstruction.fromInstruction(program_id, data);
            
            switch (instruction_type) {
                .CreateMetadataAccount, .MintNFT => {
                    mint_count.* += 1;
                    try processNftMint(indexer, slot, block_time, program_id, accounts.items);
                },
                .CreateListing => {
                    listing_count.* += 1;
                    try processNftListing(indexer, slot, block_time, program_id, accounts.items);
                },
                .ExecuteSale => {
                    sale_count.* += 1;
                    try processNftSale(indexer, slot, block_time, signature, program_id, accounts.items);
                },
                .CreateBid => {
                    bid_count.* += 1;
                    try processNftBid(indexer, slot, block_time, program_id, accounts.items);
                },
                else => {},
            }
        }
    }
}

fn processNftMint(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    _: []const u8, // program_id
    accounts: []const []const u8,
) !void {
    // Update NFT collection
    try indexer.db_client.insertNftCollection(.{
        .collection_address = accounts[1], // Assume first non-user account is collection
        .slot = slot,
        .block_time = block_time,
        .name = "", // TODO: Extract metadata
        .symbol = "",
        .creator_address = accounts[0],
        .verified = 0,
        .total_supply = 0,
        .holder_count = 0,
        .floor_price_sol = 0,
        .volume_24h_sol = 0,
        .market_cap_sol = 0,
        .royalty_bps = 0,
        .metadata_uri = "",
    });
    
    // Update NFT mint
    try indexer.db_client.insertNftMint(.{
        .mint_address = accounts[2], // Assume third account is mint
        .slot = slot,
        .block_time = block_time,
        .collection_address = accounts[1],
        .owner = accounts[0],
        .creator_address = accounts[0],
        .name = "", // TODO: Extract metadata
        .symbol = "",
        .uri = "",
        .seller_fee_basis_points = 0,
        .primary_sale_happened = 0,
        .is_mutable = 1,
        .edition_nonce = null,
        .token_standard = "NonFungible",
        .uses = null,
    });
}

fn processNftListing(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    program_id: []const u8,
    accounts: []const []const u8,
) !void {
    try indexer.db_client.insertNftListing(.{
        .listing_address = accounts[1], // Assume first non-user account is listing
        .slot = slot,
        .block_time = block_time,
        .marketplace = program_id,
        .mint_address = accounts[2], // Assume third account is mint
        .collection_address = "", // TODO: Look up collection
        .seller = accounts[0],
        .price_sol = 0, // TODO: Extract price
        .expiry_time = 0,
        .cancelled = 0,
    });
}

fn processNftSale(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    signature: []const u8,
    program_id: []const u8,
    accounts: []const []const u8,
) !void {
    try indexer.db_client.insertNftSale(.{
        .signature = signature,
        .slot = slot,
        .block_time = block_time,
        .marketplace = program_id,
        .mint_address = accounts[2], // Assume third account is mint
        .collection_address = "", // TODO: Look up collection
        .seller = accounts[0],
        .buyer = accounts[1],
        .price_sol = 0, // TODO: Extract price
        .price_usd = 0,
        .fee_amount = 0,
        .royalty_amount = 0,
    });
}

fn processNftBid(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    program_id: []const u8,
    accounts: []const []const u8,
) !void {
    try indexer.db_client.insertNftBid(.{
        .bid_address = accounts[1], // Assume first non-user account is bid
        .slot = slot,
        .block_time = block_time,
        .marketplace = program_id,
        .mint_address = accounts[2], // Assume third account is mint
        .collection_address = "", // TODO: Look up collection
        .bidder = accounts[0],
        .price_sol = 0, // TODO: Extract price
        .expiry_time = 0,
        .cancelled = 0,
    });
}
