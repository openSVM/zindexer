const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

pub fn insertSecurityEvent(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const affected_accounts_json = try types.arrayToJson(arena.allocator(), data.affected_accounts);
    const affected_tokens_json = try types.arrayToJson(arena.allocator(), data.affected_tokens);
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO security_events
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', {}, '{s}')
    , .{
        data.event_id, data.slot, data.block_time,
        data.event_type, data.severity, data.program_id,
        affected_accounts_json, affected_tokens_json,
        data.loss_amount_usd, data.description,
    });
    
    try self.executeQuery(query);
}

pub fn insertSuspiciousAccount(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const risk_factors_json = try types.arrayToJson(arena.allocator(), data.risk_factors);
    const associated_events_json = try types.arrayToJson(arena.allocator(), data.associated_events);
    const linked_accounts_json = try types.arrayToJson(arena.allocator(), data.linked_accounts);
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO suspicious_accounts
        \\VALUES ('{s}', {}, {}, {}, '{s}', '{s}', '{s}', {}, {})
    , .{
        data.account_address, data.slot, data.block_time,
        data.risk_score, risk_factors_json, associated_events_json,
        linked_accounts_json, data.last_activity_slot,
        data.total_volume_usd,
    });
    
    try self.executeQuery(query);
}

pub fn insertProgramSecurityMetrics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO program_security_metrics
        \\VALUES ('{s}', {}, {}, '{s}', {}, {}, {}, {}, {}, {}, '{s}', {})
    , .{
        data.program_id, data.slot, data.block_time,
        data.audit_status, data.vulnerability_count,
        data.critical_vulnerabilities, data.high_vulnerabilities,
        data.medium_vulnerabilities, data.low_vulnerabilities,
        data.last_audit_date, data.auditor,
        data.tvl_at_risk_usd,
    });
    
    try self.executeQuery(query);
}

pub fn insertSecurityAnalytics(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO security_analytics
        \\VALUES ({}, {}, '{s}', {}, {}, {}, {}, {}, {})
    , .{
        data.slot, data.block_time, data.category,
        data.total_events_24h, data.critical_events_24h,
        data.affected_users_24h, data.total_loss_usd,
        data.average_risk_score, data.unique_attack_vectors,
    });
    
    try self.executeQuery(query);
}

pub fn insertRiskAssessment(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const risk_factors_json = try types.arrayToJson(arena.allocator(), data.risk_factors);
    const mitigation_steps_json = try types.arrayToJson(arena.allocator(), data.mitigation_steps);
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO risk_assessments
        \\VALUES ('{s}', {}, {}, '{s}', {}, '{s}', '{s}', {}, {}, {})
    , .{
        data.program_id, data.slot, data.block_time,
        data.risk_category, data.risk_score,
        risk_factors_json, mitigation_steps_json,
        data.impact_score, data.likelihood_score,
        data.tvl_exposed_usd,
    });
    
    try self.executeQuery(query);
}

pub fn insertSecurityAlert(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const affected_accounts_json = try types.arrayToJson(arena.allocator(), data.affected_accounts);
    const affected_programs_json = try types.arrayToJson(arena.allocator(), data.affected_programs);
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO security_alerts
        \\VALUES ('{s}', {}, {}, '{s}', '{s}', '{s}', '{s}', '{s}', {}, {})
    , .{
        data.alert_id, data.slot, data.block_time,
        data.alert_type, data.severity, data.description,
        affected_accounts_json, affected_programs_json,
        data.loss_amount_usd, data.resolved,
    });
    
    try self.executeQuery(query);
}
