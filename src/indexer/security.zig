const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const core = @import("core.zig");

pub fn processSecurityEvents(
    indexer: *core.Indexer,
    slot: u64,
    block_time: i64,
    tx_json: std.json.Value,
    event_count: *u32,
    critical_count: *u32,
    affected_users: *u32,
) !void {
    const tx = tx_json.object;
    const meta = tx.get("meta").?.object;
    const message = tx.get("transaction").?.object.get("message").?.object;
    const account_keys = message.get("accountKeys").?.array;
    
    // Check for suspicious patterns
    if (meta.get("err")) |err| {
        // Failed transaction analysis
        const error_msg = err.string;
        // Analyze error message for security implications
        if (std.mem.indexOf(u8, error_msg, "overflow") != null or
            std.mem.indexOf(u8, error_msg, "underflow") != null) {
                event_count.* += 1;
                critical_count.* += 1;
                
                // Extract affected accounts
                var affected_accounts = std.ArrayList([]const u8).init(indexer.allocator);
                defer affected_accounts.deinit();
                
                for (account_keys.items) |key| {
                    try affected_accounts.append(key.string);
                }
                
                // Insert security event
                try indexer.db_client.insertSecurityEvent(.{
                    .event_id = try std.fmt.allocPrint(indexer.allocator, "error_{s}", .{error_msg}),
                    .slot = slot,
                    .block_time = block_time,
                    .event_type = "overflow_error",
                    .severity = "critical",
                    .program_id = account_keys.items[0].string,
                    .affected_accounts = affected_accounts.items,
                    .affected_tokens = &[_][]const u8{},
                    .loss_amount_usd = 0,
                    .description = error_msg,
                });
                
                // Update suspicious accounts
                for (affected_accounts.items) |account| {
                    try indexer.db_client.insertSuspiciousAccount(.{
                        .account_address = account,
                        .slot = slot,
                        .block_time = block_time,
                        .risk_score = 0.8, // High risk for overflow errors
                        .risk_factors = &[_][]const u8{"overflow_error"},
                        .associated_events = &[_][]const u8{try std.fmt.allocPrint(indexer.allocator, "error_{s}", .{error_msg})},
                        .last_activity_slot = slot,
                        .total_volume_usd = 0,
                        .linked_accounts = &[_][]const u8{},
                    });
                }
            }
    }
    
    // Check for large value transfers
    const pre_balances = meta.get("preBalances").?.array.items;
    const post_balances = meta.get("postBalances").?.array.items;
    for (pre_balances, 0..) |pre_balance, i| {
        const post_balance = post_balances[i];
        const balance_change = if (post_balance.integer > pre_balance.integer)
            post_balance.integer - pre_balance.integer
        else
            pre_balance.integer - post_balance.integer;
        
        // TODO: Configure threshold
        if (balance_change > 1000000000000) { // 1000 SOL
            event_count.* += 1;
            affected_users.* += 1;
            
            // Insert security event
            try indexer.db_client.insertSecurityEvent(.{
                .event_id = try std.fmt.allocPrint(indexer.allocator, "large_transfer_{d}", .{slot}),
                .slot = slot,
                .block_time = block_time,
                .event_type = "large_transfer",
                .severity = "warning",
                .program_id = account_keys.items[0].string,
                .affected_accounts = &[_][]const u8{account_keys.items[i].string},
                .affected_tokens = &[_][]const u8{},
                .loss_amount_usd = @as(f64, @floatFromInt(balance_change)) * 0.00000001, // Convert lamports to SOL
                .description = "Large value transfer detected",
            });
            
            // Update suspicious account
            try indexer.db_client.insertSuspiciousAccount(.{
                .account_address = account_keys.items[i].string,
                .slot = slot,
                .block_time = block_time,
                .risk_score = 0.5, // Medium risk for large transfers
                .risk_factors = &[_][]const u8{"large_transfer"},
                .associated_events = &[_][]const u8{try std.fmt.allocPrint(indexer.allocator, "large_transfer_{d}", .{slot})},
                .last_activity_slot = slot,
                .total_volume_usd = @as(f64, @floatFromInt(balance_change)) * 0.00000001,
                .linked_accounts = &[_][]const u8{},
            });
        }
    }
    
    // Update program security metrics
    const instructions = message.get("instructions").?.array;
    for (instructions.items) |ix| {
        const program_idx: u8 = @intCast(ix.object.get("programIdIndex").?.integer);
        const program_id = account_keys.items[program_idx].string;
        
        try indexer.db_client.insertProgramSecurityMetrics(.{
            .program_id = program_id,
            .slot = slot,
            .block_time = block_time,
            .audit_status = "unknown",
            .vulnerability_count = if (meta.get("err") == null) 0 else 1,
            .critical_vulnerabilities = if (critical_count.* > 0) 1 else 0,
            .high_vulnerabilities = 0,
            .medium_vulnerabilities = 0,
            .low_vulnerabilities = 0,
            .last_audit_date = 0,
            .auditor = "",
            .tvl_at_risk_usd = 0,
        });
    }
    
    // Update security analytics
    try indexer.db_client.insertSecurityAnalytics(.{
        .slot = slot,
        .block_time = block_time,
        .category = "all",
        .total_events_24h = event_count.*,
        .critical_events_24h = critical_count.*,
        .affected_users_24h = affected_users.*,
        .total_loss_usd = 0, // TODO: Calculate total losses
        .average_risk_score = 0, // TODO: Calculate average risk
        .unique_attack_vectors = 0, // TODO: Count unique vectors
    });
}
