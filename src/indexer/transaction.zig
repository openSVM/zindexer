const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processTransaction(indexer: *core.Indexer, slot: u64, block_time: i64, tx_json: std.json.Value) !void {
    const tx = tx_json.object;
    const meta = tx.get("meta").?.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    
    // Extract program IDs from instructions
    var program_ids = std.ArrayList([]const u8).init(indexer.allocator);
    defer program_ids.deinit();
    
    const instructions = message.get("instructions").?.array;
    for (instructions.items) |ix| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = message.get("accountKeys").?.array.items[program_idx].string;
        try program_ids.append(program_id);
    }
    
    // Extract account keys
    var account_keys = std.ArrayList([]const u8).init(indexer.allocator);
    defer account_keys.deinit();
    
    for (message.get("accountKeys").?.array.items) |key| {
        try account_keys.append(key.string);
    }
    
    // Extract signers (first N accounts where is_signer = true)
    var signers = std.ArrayList([]const u8).init(indexer.allocator);
    defer signers.deinit();
    
    const header = message.get("header").?.object;
    const num_signers: u8 = @intCast(header.get("numRequiredSignatures").?.integer);
    var i: usize = 0;
    while (i < num_signers) : (i += 1) {
        try signers.append(account_keys.items[i]);
    }
    
    // Format token balances
    var pre_token_balances = std.ArrayList(u8).init(indexer.allocator);
    defer pre_token_balances.deinit();
    var post_token_balances = std.ArrayList(u8).init(indexer.allocator);
    defer post_token_balances.deinit();
    
    if (meta.get("preTokenBalances")) |balances| {
        try std.json.stringify(balances, .{}, pre_token_balances.writer());
    }
    
    if (meta.get("postTokenBalances")) |balances| {
        try std.json.stringify(balances, .{}, post_token_balances.writer());
    }
    
    // Extract log messages
    var log_messages = std.ArrayList([]const u8).init(indexer.allocator);
    defer log_messages.deinit();
    
    if (meta.get("logMessages")) |logs| {
        for (logs.array.items) |log| {
            try log_messages.append(log.string);
        }
    }
    
    // Insert transaction data
    try indexer.db_client.insertTransaction(.{
        .signature = tx.get("transaction").?.object.get("signatures").?.array.items[0].string,
        .slot = slot,
        .block_time = block_time,
        .success = meta.get("err") == null,
        .fee = @as(u64, @intCast(meta.get("fee").?.integer)),
        .compute_units_consumed = if (meta.get("computeUnitsConsumed")) |cu| @as(u64, @intCast(cu.integer)) else 0,
        .compute_units_price = 0, // TODO: Extract from instructions
        .recent_blockhash = message.get("recentBlockhash").?.string,
        .program_ids = program_ids.items,
        .signers = signers.items,
        .account_keys = account_keys.items,
        .pre_balances = meta.get("preBalances").?.array.items,
        .post_balances = meta.get("postBalances").?.array.items,
        .pre_token_balances = pre_token_balances.items,
        .post_token_balances = post_token_balances.items,
        .log_messages = log_messages.items,
        .error_msg = if (meta.get("err")) |err| err.string else null,
    });
    
    // Update program execution stats
    const has_error = meta.get("err") != null;
    const compute_units = if (meta.get("computeUnitsConsumed")) |cu| @as(u64, @intCast(cu.integer)) else 0;
    const fee = @as(u64, @intCast(meta.get("fee").?.integer));
    
    for (program_ids.items) |program_id| {
        try indexer.db_client.insertProgramExecution(.{
            .program_id = program_id,
            .slot = slot,
            .block_time = block_time,
            .execution_count = 1,
            .total_cu_consumed = compute_units,
            .total_fee = fee,
            .success_count = if (has_error) @as(u32, 0) else @as(u32, 1),
            .error_count = if (has_error) @as(u32, 1) else @as(u32, 0),
        });
    }
    
    // Update account activity
    for (account_keys.items) |account| {
        try indexer.db_client.insertAccountActivity(.{
            .network = network_name,
            .pubkey = account,
            .slot = slot,
            .block_time = block_time,
            .program_id = program_ids.items[0], // Use first program as main program
            .write_count = 1,
            .cu_consumed = compute_units,
            .fee_paid = fee,
        });
    }
}