const std = @import("std");
const database = @import("../database.zig");

// Stubbed QuestDB implementation
pub const QuestDBClient = struct {
    allocator: std.mem.Allocator,
    logging_only: bool = true,
    
    pub fn init(allocator: std.mem.Allocator, url: []const u8, user: []const u8, password: []const u8, db_name: []const u8) !@This() {
        _ = url; _ = user; _ = password; _ = db_name;
        std.log.info("QuestDB client initialized (stub)", .{});
        return @This(){
            .allocator = allocator,
            .logging_only = true,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        _ = self;
        std.log.info("QuestDB client deinitialized (stub)", .{});
    }
};
