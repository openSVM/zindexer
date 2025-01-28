const std = @import("std");
const ClickHouseClient = @import("clickhouse.zig").ClickHouseClient;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize ClickHouse client
    var client = try ClickHouseClient.init(allocator, "http://localhost:8123", // Default ClickHouse HTTP port
        "default", // Default username
        "", // Empty password for default user
        "solana" // Database name
    );
    defer client.deinit();

    std.log.info("Connected to ClickHouse", .{});

    // Create tables
    try client.createTables();
    std.log.info("Tables created successfully", .{});
}
