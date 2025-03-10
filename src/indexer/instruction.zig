const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processInstructions(indexer: *core.Indexer, slot: u64, block_time: i64, tx_json: std.json.Value) !void {
    const tx = tx_json.object;
    const meta = tx.get("meta").?.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    const signature = tx.get("transaction").?.object.get("signatures").?.array.items[0].string;
    
    // Process outer instructions
    const instructions = message.get("instructions").?.array;
    for (instructions.items, 0..) |ix, ix_idx| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = message.get("accountKeys").?.array.items[program_idx].string;
        
        // Extract instruction accounts
        var accounts = std.ArrayList([]const u8).init(indexer.allocator);
        defer accounts.deinit();
        
        for (ix.object.get("accounts").?.array.items) |acc_idx| {
            const account = message.get("accountKeys").?.array.items[@as(usize, @intCast(acc_idx.integer))].string;
            try accounts.append(account);
        }
        
        // Get instruction type for token program
        const instruction_type = if (std.mem.eql(u8, program_id, types.TOKEN_PROGRAM_ID)) blk: {
            const data = ix.object.get("data").?.string;
            break :blk @tagName(types.TokenInstruction.fromInstruction(program_id, data));
        } else "";
        
        // Parse instruction data
        var parsed_data = std.ArrayList(u8).init(indexer.allocator);
        defer parsed_data.deinit();
        
        if (ix.object.get("data")) |data| {
            try std.json.stringify(data, .{}, parsed_data.writer());
        }
        
        // Insert instruction data
        try indexer.db_client.insertInstruction(.{
            .signature = signature,
            .slot = slot,
            .block_time = block_time,
            .program_id = program_id,
            .instruction_index = @as(u32, @intCast(ix_idx)),
            .inner_instruction_index = null,
            .instruction_type = instruction_type,
            .parsed_data = parsed_data.items,
            .accounts = accounts.items,
        });
    }
    
    // Process inner instructions
    if (meta.get("innerInstructions")) |inner_ixs| {
        for (inner_ixs.array.items) |inner_ix_group| {
            const outer_idx: u32 = @intCast(inner_ix_group.object.get("index").?.integer);
            
            for (inner_ix_group.object.get("instructions").?.array.items, 0..) |inner_ix, inner_idx| {
                const program_idx: u8 = @intCast(inner_ix.object.get("programIdIndex").?.integer);
                const program_id = message.get("accountKeys").?.array.items[program_idx].string;
                
                var accounts = std.ArrayList([]const u8).init(indexer.allocator);
                defer accounts.deinit();
                
                for (inner_ix.object.get("accounts").?.array.items) |acc_idx| {
                    const account = message.get("accountKeys").?.array.items[@as(usize, @intCast(acc_idx.integer))].string;
                    try accounts.append(account);
                }
                
                // Get instruction type for token program
                const instruction_type = if (std.mem.eql(u8, program_id, types.TOKEN_PROGRAM_ID)) blk: {
                    const data = inner_ix.object.get("data").?.string;
                    break :blk @tagName(types.TokenInstruction.fromInstruction(program_id, data));
                } else "";
                
                // Parse instruction data
                var parsed_data = std.ArrayList(u8).init(indexer.allocator);
                defer parsed_data.deinit();
                
                if (inner_ix.object.get("data")) |data| {
                    try std.json.stringify(data, .{}, parsed_data.writer());
                }
                
                try indexer.db_client.insertInstruction(.{
                    .network = network_name,
                    .signature = signature,
                    .slot = slot,
                    .block_time = block_time,
                    .program_id = program_id,
                    .instruction_index = outer_idx,
                    .inner_instruction_index = @as(u32, @intCast(inner_idx)),
                    .instruction_type = instruction_type,
                    .parsed_data = parsed_data.items,
                    .accounts = accounts.items,
                });
            }
        }
    }
}