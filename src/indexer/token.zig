const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processTokenOperations(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    tx_json: std.json.Value,
    transfer_count: *u32,
    mint_count: *u32,
    burn_count: *u32,
    account_count: *u32,
) !void {
    const tx = tx_json.object;
    const meta = tx.get("meta").?.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    const signature = tx.get("transaction").?.object.get("signatures").?.array.items[0].string;
    
    // Process token account balance changes
    if (meta.get("preTokenBalances")) |pre_balances| {
        if (meta.get("postTokenBalances")) |post_balances| {
            for (post_balances.array.items) |post_balance| {
                const account_index = @as(usize, @intCast(post_balance.object.get("accountIndex").?.integer));
                const mint = post_balance.object.get("mint").?.string;
                const owner = post_balance.object.get("owner").?.string;
                const amount = @as(u64, @intCast(post_balance.object.get("uiTokenAmount").?.object.get("amount").?.integer));
                const decimals = @as(u8, @intCast(post_balance.object.get("uiTokenAmount").?.object.get("decimals").?.integer));
                
                // Find pre-balance
                var pre_amount: u64 = 0;
                for (pre_balances.array.items) |pre_balance| {
                    if (@as(usize, @intCast(pre_balance.object.get("accountIndex").?.integer)) == account_index) {
                        pre_amount = @as(u64, @intCast(pre_balance.object.get("uiTokenAmount").?.object.get("amount").?.integer));
                        break;
                    }
                }
                
                // Update token account
                try indexer.db_client.insertTokenAccount(.{
                    .account_address = message.get("accountKeys").?.array.items[account_index].string,
                    .mint_address = mint,
                    .slot = slot,
                    .block_time = block_time,
                    .owner = owner,
                    .amount = amount,
                    .delegate = null, // TODO: Extract delegate info
                    .delegated_amount = 0,
                    .is_initialized = 1,
                    .is_frozen = 0,
                    .is_native = 0,
                    .rent_exempt_reserve = null,
                    .close_authority = null,
                });
                
                account_count.* += 1;
                
                // Record transfer if amount changed
                if (amount != pre_amount) {
                    if (amount > pre_amount) {
                        mint_count.* += 1;
                        try indexer.db_client.insertTokenTransfer(.{
                            .signature = signature,
                            .slot = slot,
                            .block_time = block_time,
                            .mint_address = mint,
                            .from_account = "",
                            .to_account = message.get("accountKeys").?.array.items[account_index].string,
                            .amount = amount - pre_amount,
                            .decimals = decimals,
                            .program_id = types.TOKEN_PROGRAM_ID,
                            .instruction_type = "mint",
                        });
                    } else {
                        burn_count.* += 1;
                        try indexer.db_client.insertTokenTransfer(.{
                            .signature = signature,
                            .slot = slot,
                            .block_time = block_time,
                            .mint_address = mint,
                            .from_account = message.get("accountKeys").?.array.items[account_index].string,
                            .to_account = "",
                            .amount = pre_amount - amount,
                            .decimals = decimals,
                            .program_id = types.TOKEN_PROGRAM_ID,
                            .instruction_type = "burn",
                        });
                    }
                    transfer_count.* += 1;
                    
                    // Update token holder info
                    try indexer.db_client.insertTokenHolder(.{
                        .mint_address = mint,
                        .slot = slot,
                        .block_time = block_time,
                        .owner = owner,
                        .balance = amount,
                        .balance_usd = 0, // TODO: Calculate USD value
                    });
                }
                
                // Update token analytics
                try indexer.db_client.insertTokenAnalytics(.{
                    .mint_address = mint,
                    .slot = slot,
                    .block_time = block_time,
                    .transfer_count = transfer_count.*,
                    .unique_holders = 0, // TODO: Count unique holders
                    .active_accounts = account_count.*,
                    .total_volume_usd = 0, // TODO: Calculate volume
                    .avg_transaction_size = 0, // TODO: Calculate average size
                });
            }
        }
    }
    
    // Process token program instructions
    const instructions = message.get("instructions").?.array;
    for (instructions.items) |ix| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = message.get("accountKeys").?.array.items[program_idx].string;
        
        if (std.mem.eql(u8, program_id, types.TOKEN_PROGRAM_ID)) {
            const data = ix.object.get("data").?.string;
            const instruction_type = @tagName(types.TokenInstruction.fromInstruction(program_id, data));
            
            try indexer.db_client.insertTokenProgramActivity(.{
                .program_id = program_id,
                .slot = slot,
                .block_time = block_time,
                .instruction_type = instruction_type,
                .execution_count = 1,
                .error_count = if (meta.get("err") == null) 0 else 1,
                .unique_users = 0, // TODO: Count unique users
                .unique_tokens = 0, // TODO: Count unique tokens
            });
        }
    }
    
    // Process inner token instructions
    if (meta.get("innerInstructions")) |inner_ixs| {
        for (inner_ixs.array.items) |inner_ix_group| {
            for (inner_ix_group.object.get("instructions").?.array.items) |inner_ix| {
                const program_idx: u8 = @intCast(inner_ix.object.get("programIdIndex").?.integer);
                const program_id = message.get("accountKeys").?.array.items[program_idx].string;
                
                if (std.mem.eql(u8, program_id, types.TOKEN_PROGRAM_ID)) {
                    const data = inner_ix.object.get("data").?.string;
                    const instruction_type = @tagName(types.TokenInstruction.fromInstruction(program_id, data));
                    
                    try indexer.db_client.insertTokenProgramActivity(.{
                        .program_id = program_id,
                        .slot = slot,
                        .block_time = block_time,
                        .instruction_type = instruction_type,
                        .execution_count = 1,
                        .error_count = if (meta.get("err") == null) 0 else 1,
                        .unique_users = 0, // TODO: Count unique users
                        .unique_tokens = 0, // TODO: Count unique tokens
                    });
                }
            }
        }
    }
}
