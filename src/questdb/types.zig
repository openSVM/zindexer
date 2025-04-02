const std = @import("std");

pub const QuestDBError = error{
    QueryFailed,
    InvalidResponse,
    ConnectionFailed,
    DatabaseError,
    AuthenticationError,
    InvalidUrl,
} || std.Uri.ParseError || std.fmt.AllocPrintError || std.mem.Allocator.Error;

// Helper functions for QuestDB-specific data formatting

/// Escape a string for use in ILP (InfluxDB Line Protocol)
pub fn escapeIlpString(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    for (input) |c| {
        switch (c) {
            '\\' => try result.appendSlice("\\\\"),
            '"' => try result.appendSlice("\\\""),
            ',' => try result.appendSlice("\\\\"),
            ' ' => try result.appendSlice("\\\\"),
            '=' => try result.appendSlice("\\\\"),
            else => try result.append(c),
        }
    }

    return result.toOwnedSlice();
}

/// Format a timestamp for QuestDB (nanoseconds since epoch)
pub fn formatTimestamp(timestamp: i64) i64 {
    // QuestDB expects timestamps in nanoseconds
    return timestamp * 1000000; // Convert milliseconds to nanoseconds
}

/// Convert a JSON array to a string representation for QuestDB
pub fn jsonArrayToString(allocator: std.mem.Allocator, array: []const std.json.Value) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    try result.append('[');

    for (array, 0..) |item, i| {
        if (i > 0) try result.appendSlice(",");

        switch (item) {
            .string => |s| {
                try result.append('"');
                try result.appendSlice(s);
                try result.append('"');
            },
            .integer => |n| try std.fmt.format(result.writer(), "{d}", .{n}),
            .float => |f| try std.fmt.format(result.writer(), "{d}", .{f}),
            .bool => |b| try result.appendSlice(if (b) "true" else "false"),
            .null => try result.appendSlice("null"),
            .object => try result.appendSlice("[object]"),
            .array => try result.appendSlice("[array]"),
        }
    }

    try result.append(']');
    return result.toOwnedSlice();
}