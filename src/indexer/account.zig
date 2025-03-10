const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processAccountUpdates(indexer: *core.Indexer, slot: u64, block_time: i64, tx_json: std.json.Value, network_name: []const u8) !void {
    const tx = tx_json.object;
    const meta = tx.get("meta").?.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    const account_keys = message.get("accountKeys").?.array;
    
    // Track account writes
    if (meta.get("postAccountKeys")) |post_keys| {
        for (post_keys.array.items, 0..) |key, i| {
            const pre_balance = meta.get("preBalances").?.array.items[i].integer;
            const post_balance = meta.get("postBalances").?.array.items[i].integer;
            
            // Get account owner
            const owner = if (i < account_keys.items.len) account_keys.items[i].string else "";
            
            // Get account data info
            var data_len: u64 = 0;
            var executable: u8 = 0;
            var rent_epoch: u64 = 0;
            
            if (meta.get("postAccountInfo")) |info| {
                if (i < info.array.items.len) {
                    const account_info = info.array.items[i].object;
                    data_len = @as(u64, @intCast(account_info.get("data").?.array.items[0].string.len));
                    executable = if (account_info.get("executable").?.bool) 1 else 0;
                    rent_epoch = @as(u64, @intCast(account_info.get("rentEpoch").?.integer));
                }
            }
            
            // Insert account data if balance changed
            if (pre_balance != post_balance) {
                try indexer.db_client.insertAccount(.{
                    .pubkey = key.string,
                    .slot = slot,
                    .block_time = block_time,
                    .owner = owner,
                    .lamports = @as(u64, @intCast(post_balance)),
                    .executable = executable,
                    .rent_epoch = rent_epoch,
                    .data_len = data_len,
                    .write_version = 0, // TODO: Track write version
                });
            }
        }
    }
    
    // Track program account activity
    const instructions = message.get("instructions").?.array;
    for (instructions.items) |ix| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = account_keys.items[program_idx].string;
        
        // Extract accounts used by this instruction
        for (ix.object.get("accounts").?.array.items) |acc_idx| {
            const account = account_keys.items[@as(usize, @intCast(acc_idx.integer))].string;
            
            try indexer.db_client.insertAccountActivity(.{
                .network = network_name,
                .slot = slot,
                .block_time = block_time,
                .pubkey = account,
                .program_id = program_id,
                .write_count = 1,
                .cu_consumed = if (meta.get("computeUnitsConsumed")) |cu| @as(u64, @intCast(cu.integer)) else 0,
                .fee_paid = @as(u64, @intCast(meta.get("fee").?.integer)),
            });
        }
    }
    
    // Track inner instruction account activity
    if (meta.get("innerInstructions")) |inner_ixs| {
        for (inner_ixs.array.items) |inner_ix_group| {
            for (inner_ix_group.object.get("instructions").?.array.items) |inner_ix| {
                const program_idx: u8 = @intCast(inner_ix.object.get("programIdIndex").?.integer);
                const program_id = account_keys.items[program_idx].string;
                
                for (inner_ix.object.get("accounts").?.array.items) |acc_idx| {
                    const account = account_keys.items[@as(usize, @intCast(acc_idx.integer))].string;
                    
                    try indexer.db_client.insertAccountActivity(.{
                        .network = network_name,
                        .slot = slot,
                        .block_time = block_time,
                        .pubkey = account,
                        .program_id = program_id,
                        .write_count = 1,
                        .cu_consumed = if (meta.get("computeUnitsConsumed")) |cu| @as(u64, @intCast(cu.integer)) else 0,
                        .fee_paid = @as(u64, @intCast(meta.get("fee").?.integer)),
                    });
                }
            }
        }
    }
}