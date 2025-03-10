const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

pub fn insertAccount(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO accounts
        \\VALUES ('{s}', '{s}', {}, {}, '{s}', {}, {}, {}, {}, {})
    , .{
        data.network, data.pubkey, data.slot, data.block_time,
        data.owner, data.lamports, data.executable,
        data.rent_epoch, data.data_len,
        data.write_version,
    });
    
    try self.executeQuery(query);
}

pub fn insertAccountActivity(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO account_activity
        \\VALUES ('{s}', '{s}', {}, {}, '{s}', {}, {}, {})
    , .{
        data.network, data.pubkey, data.slot, data.block_time,
        data.program_id, data.write_count,
        data.cu_consumed, data.fee_paid,
    });
    
    try self.executeQuery(query);
}