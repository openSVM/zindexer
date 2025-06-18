const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const c_questdb = @import("c-questdb-client");

// Security-related operations for QuestDB
// These would be similar to the core.zig implementation but using ILP format

/// Insert a security event into QuestDB
pub fn insertSecurityEvent(self: *@This(), network: []const u8, event_type: []const u8, slot: u64, block_time: i64, signature: []const u8, program_id: []const u8, account_address: []const u8, severity: []const u8, description: []const u8) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping security event insert for {s}", .{signature});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("security_events,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",event_type=");
    try ilp_buffer.appendSlice(event_type);
    try ilp_buffer.appendSlice(",signature=");
    try ilp_buffer.appendSlice(signature);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",program_id=\"");
    try ilp_buffer.appendSlice(program_id);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",account_address=\"");
    try ilp_buffer.appendSlice(account_address);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",severity=\"");
    try ilp_buffer.appendSlice(severity);
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",description=\"");
    // Escape quotes in description
    var escaped_desc = std.ArrayList(u8).init(arena.allocator());
    for (description) |c| {
        if (c == '"') {
            try escaped_desc.appendSlice("\\");
        }
        try escaped_desc.append(c);
    }
    try ilp_buffer.appendSlice(escaped_desc.items);
    try ilp_buffer.appendSlice("\"");
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert security event ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert suspicious account into QuestDB
pub fn insertSuspiciousAccount(self: *@This(), network: []const u8, account_address: []const u8, slot: u64, block_time: i64, risk_score: f64, risk_factors: []const []const u8, associated_events: []const []const u8, linked_accounts: []const []const u8, last_activity_slot: u64, total_volume_usd: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping suspicious account insert for {s}", .{account_address});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("suspicious_accounts,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",account_address=");
    try ilp_buffer.appendSlice(account_address);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",risk_score=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{risk_score});
    
    // Format risk factors as JSON array
    try ilp_buffer.appendSlice(",risk_factors=\"");
    for (risk_factors, 0..) |factor, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(factor);
    }
    try ilp_buffer.appendSlice("\"");
    
    // Format associated events as JSON array
    try ilp_buffer.appendSlice(",associated_events=\"");
    for (associated_events, 0..) |event, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(event);
    }
    try ilp_buffer.appendSlice("\"");
    
    // Format linked accounts as JSON array
    try ilp_buffer.appendSlice(",linked_accounts=\"");
    for (linked_accounts, 0..) |account, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(account);
    }
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",last_activity_slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{last_activity_slot});
    
    try ilp_buffer.appendSlice(",total_volume_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_volume_usd});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert suspicious account ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert program security metrics into QuestDB
pub fn insertProgramSecurityMetrics(self: *@This(), network: []const u8, program_id: []const u8, slot: u64, block_time: i64, audit_status: []const u8, vulnerability_count: u32, critical_vulnerabilities: u32, high_vulnerabilities: u32, medium_vulnerabilities: u32, low_vulnerabilities: u32, last_audit_date: i64, auditor: []const u8, tvl_at_risk_usd: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping program security metrics insert for {s}", .{program_id});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("program_security_metrics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",program_id=");
    try ilp_buffer.appendSlice(program_id);
    try ilp_buffer.appendSlice(",audit_status=");
    try ilp_buffer.appendSlice(audit_status);
    try ilp_buffer.appendSlice(",auditor=");
    try ilp_buffer.appendSlice(auditor);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",vulnerability_count=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{vulnerability_count});
    
    try ilp_buffer.appendSlice(",critical_vulnerabilities=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{critical_vulnerabilities});
    
    try ilp_buffer.appendSlice(",high_vulnerabilities=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{high_vulnerabilities});
    
    try ilp_buffer.appendSlice(",medium_vulnerabilities=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{medium_vulnerabilities});
    
    try ilp_buffer.appendSlice(",low_vulnerabilities=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{low_vulnerabilities});
    
    try ilp_buffer.appendSlice(",last_audit_date=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{last_audit_date});
    
    try ilp_buffer.appendSlice(",tvl_at_risk_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{tvl_at_risk_usd});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert program security metrics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert security analytics into QuestDB
pub fn insertSecurityAnalytics(self: *@This(), network: []const u8, slot: u64, block_time: i64, category: []const u8, total_events_24h: u64, critical_events_24h: u64, affected_users_24h: u64, total_loss_usd: f64, average_risk_score: f64, unique_attack_vectors: u64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping security analytics insert", .{});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("security_analytics,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",category=");
    try ilp_buffer.appendSlice(category);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",total_events_24h=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_events_24h});
    
    try ilp_buffer.appendSlice(",critical_events_24h=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{critical_events_24h});
    
    try ilp_buffer.appendSlice(",affected_users_24h=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{affected_users_24h});
    
    try ilp_buffer.appendSlice(",total_loss_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{total_loss_usd});
    
    try ilp_buffer.appendSlice(",average_risk_score=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{average_risk_score});
    
    try ilp_buffer.appendSlice(",unique_attack_vectors=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{unique_attack_vectors});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert security analytics ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert risk assessment into QuestDB
pub fn insertRiskAssessment(self: *@This(), network: []const u8, program_id: []const u8, slot: u64, block_time: i64, risk_category: []const u8, risk_score: f64, risk_factors: []const []const u8, mitigation_steps: []const []const u8, impact_score: f64, likelihood_score: f64, tvl_exposed_usd: f64) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping risk assessment insert for {s}", .{program_id});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("risk_assessments,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",program_id=");
    try ilp_buffer.appendSlice(program_id);
    try ilp_buffer.appendSlice(",risk_category=");
    try ilp_buffer.appendSlice(risk_category);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",risk_score=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{risk_score});
    
    // Format risk factors as JSON array
    try ilp_buffer.appendSlice(",risk_factors=\"");
    for (risk_factors, 0..) |factor, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(factor);
    }
    try ilp_buffer.appendSlice("\"");
    
    // Format mitigation steps as JSON array
    try ilp_buffer.appendSlice(",mitigation_steps=\"");
    for (mitigation_steps, 0..) |step, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(step);
    }
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",impact_score=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{impact_score});
    
    try ilp_buffer.appendSlice(",likelihood_score=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{likelihood_score});
    
    try ilp_buffer.appendSlice(",tvl_exposed_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{tvl_exposed_usd});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert risk assessment ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}

/// Insert security alert into QuestDB
pub fn insertSecurityAlert(self: *@This(), network: []const u8, alert_id: []const u8, slot: u64, block_time: i64, alert_type: []const u8, severity: []const u8, description: []const u8, affected_accounts: []const []const u8, affected_programs: []const []const u8, loss_amount_usd: f64, resolved: bool) !void {
    if (self.logging_only) {
        std.log.info("Logging-only mode, skipping security alert insert for {s}", .{alert_id});
        return;
    }

    if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    // Format as ILP (InfluxDB Line Protocol)
    var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

    // Format: measurement,tag_set field_set timestamp
    try ilp_buffer.appendSlice("security_alerts,");
    
    // Tags
    try ilp_buffer.appendSlice("network=");
    try ilp_buffer.appendSlice(network);
    try ilp_buffer.appendSlice(",alert_id=");
    try ilp_buffer.appendSlice(alert_id);
    try ilp_buffer.appendSlice(",alert_type=");
    try ilp_buffer.appendSlice(alert_type);
    try ilp_buffer.appendSlice(",severity=");
    try ilp_buffer.appendSlice(severity);
    
    // Fields
    try ilp_buffer.appendSlice(" slot=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{slot});
    
    try ilp_buffer.appendSlice(",description=\"");
    // Escape quotes in description
    var escaped_desc = std.ArrayList(u8).init(arena.allocator());
    for (description) |c| {
        if (c == '"') {
            try escaped_desc.appendSlice("\\");
        }
        try escaped_desc.append(c);
    }
    try ilp_buffer.appendSlice(escaped_desc.items);
    try ilp_buffer.appendSlice("\"");
    
    // Format affected accounts as JSON array
    try ilp_buffer.appendSlice(",affected_accounts=\"");
    for (affected_accounts, 0..) |account, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(account);
    }
    try ilp_buffer.appendSlice("\"");
    
    // Format affected programs as JSON array
    try ilp_buffer.appendSlice(",affected_programs=\"");
    for (affected_programs, 0..) |program, i| {
        if (i > 0) try ilp_buffer.appendSlice(",");
        try ilp_buffer.appendSlice(program);
    }
    try ilp_buffer.appendSlice("\"");
    
    try ilp_buffer.appendSlice(",loss_amount_usd=");
    try std.fmt.format(ilp_buffer.writer(), "{d}", .{loss_amount_usd});
    
    try ilp_buffer.appendSlice(",resolved=");
    try std.fmt.format(ilp_buffer.writer(), "{}", .{resolved});
    
    // Timestamp (use block_time as timestamp in nanoseconds)
    try ilp_buffer.appendSlice(" ");
    try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{block_time});
    
    try ilp_buffer.appendSlice("\n");

    // Send the ILP data to QuestDB
    if (self.ilp_client) |client| {
        _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.err("Failed to insert security alert ILP data: {any}", .{err});
            return types.QuestDBError.QueryFailed;
        };
    }
}