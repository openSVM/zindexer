const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ClickHouseError = error{
    ConnectionFailed,
    QueryFailed,
    InsertFailed,
};

// Helper function to convert string array to JSON array string
pub fn arrayToJson(allocator: Allocator, array: []const []const u8) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    
    try list.append('[');
    for (array, 0..) |item, i| {
        if (i > 0) try list.append(',');
        try list.append('"');
        try list.appendSlice(item);
        try list.append('"');
    }
    try list.append(']');
    
    return list.toOwnedSlice();
}
