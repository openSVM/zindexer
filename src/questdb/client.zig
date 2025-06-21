const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const Uri = std.Uri;
const types = @import("types.zig");
const core = @import("core.zig");
const token = @import("token.zig");
const defi = @import("defi.zig");
const nft = @import("nft.zig");
const security = @import("security.zig");
const instruction = @import("instruction.zig");
const account = @import("account.zig");
const database = @import("../database.zig");

pub const QuestDBClient = struct {
    allocator: Allocator,
    url: []const u8,
    user: []const u8,
    password: []const u8,
    database: []const u8,
    http_client: std.http.Client,
    db_client: database.DatabaseClient,

    const Self = @This();

    // VTable implementation for DatabaseClient interface
    const vtable = database.DatabaseClient.VTable{
        .deinitFn = deinitImpl,
        .executeQueryFn = executeQueryImpl,
        .verifyConnectionFn = verifyConnectionImpl,
        .createTablesFn = createTablesImpl,
        .insertTransactionBatchFn = insertTransactionBatchImpl,
        .getDatabaseSizeFn = getDatabaseSizeImpl,
        .getTableSizeFn = getTableSizeImpl,
    };

    pub fn init(
        allocator: Allocator,
        url: []const u8,
        user: []const u8,
        password: []const u8,
        database: []const u8,
    ) !Self {
        std.log.info("Initializing QuestDB client with URL: {s}, user: {s}, database: {s}", .{ url, user, database });

        // Validate URL
        _ = try std.Uri.parse(url);

        // Create HTTP client
        var http_client = std.http.Client{ .allocator = allocator };

        // Create the client instance
        var client = Self{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .user = try allocator.dupe(u8, user),
            .password = try allocator.dupe(u8, password),
            .database = try allocator.dupe(u8, database),
            .http_client = http_client,
            .db_client = database.DatabaseClient{
                .vtable = &vtable,
            },
        };

        return client;
    }

    // Implementation of DatabaseClient interface methods
    fn deinitImpl(ptr: *anyopaque) void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        self.deinit();
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
        self.allocator.free(self.url);
        self.allocator.free(self.user);
        self.allocator.free(self.password);
        self.allocator.free(self.database);
    }

    fn executeQueryImpl(ptr: *anyopaque, query: []const u8) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.executeQuery(query);
    }

    pub fn executeQuery(self: *Self, query: []const u8) !void {
        std.log.debug("Executing QuestDB query: {s}", .{query});
        
        // Parse the URL to get the host and port
        const uri = try std.Uri.parse(self.url);
        const host = uri.host orelse return types.QuestDBError.InvalidUrl;
        const port = uri.port orelse 9000;

        // Create HTTP request to QuestDB SQL endpoint
        var request_uri_buffer: [1024]u8 = undefined;
        const request_uri = try std.fmt.bufPrint(request_uri_buffer, "{s}/exec?query={s}", .{ self.url, query });
        
        var req = try self.http_client.open(.GET, try std.Uri.parse(request_uri), .{
            .server_header_buffer = &.{},
        });
        defer req.deinit();

        try req.send();
        try req.finish();
        try req.wait();

        // Check response status
        if (req.response.status != .ok) {
            std.log.err("QuestDB query failed with status: {}", .{req.response.status});
            return types.QuestDBError.QueryFailed;
        }

        std.log.debug("QuestDB query executed successfully");
    }

    fn verifyConnectionImpl(ptr: *anyopaque) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.verifyConnection();
    }

    pub fn verifyConnection(self: *Self) !void {
        // Try a simple query to verify connection
        try self.executeQuery("SELECT 1");
        std.log.info("QuestDB connection verified", .{});
    }

    fn createTablesImpl(ptr: *anyopaque) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.createTables();
    }

    pub fn createTables(self: *Self) !void {
        // Verify connection first
        try self.verifyConnection();
        
        // Create tables - these would be created by the schema application script
        // We'll just verify they exist here
        try self.executeQuery("SHOW TABLES");
    }

    fn insertTransactionBatchImpl(ptr: *anyopaque, transactions: []const std.json.Value, network_name: []const u8) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertTransactionBatch(transactions, network_name);
    }

    pub fn insertTransactionBatch(self: *Self, transactions: []const std.json.Value, network_name: []const u8) !void {
        std.log.debug("Inserting batch of {d} transactions for network {s}", .{ transactions.len, network_name });

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        // Create a buffer for ILP data
        var ilp_buffer = std.ArrayList(u8).init(arena.allocator());

        // Format transactions as ILP (InfluxDB Line Protocol)
        for (transactions) |tx_json| {
            const tx = tx_json.object;
            const meta = tx.get("meta").?.object;
            const message = tx.get("transaction").?.object.get("message").?.object;

            // Format: measurement,tag_set field_set timestamp
            try ilp_buffer.appendSlice("transactions,");
            
            // Tags
            try ilp_buffer.appendSlice("network=");
            try ilp_buffer.appendSlice(network_name);
            try ilp_buffer.appendSlice(",signature=");
            try ilp_buffer.appendSlice(tx.get("transaction").?.object.get("signatures").?.array.items[0].string);
            
            // Fields
            try ilp_buffer.appendSlice(" slot=");
            try std.fmt.format(ilp_buffer.writer(), "{d}", .{tx.get("slot").?.integer});
            
            try ilp_buffer.appendSlice(",block_time=");
            try std.fmt.format(ilp_buffer.writer(), "{d}", .{tx.get("blockTime").?.integer});
            
            const success: u8 = if (meta.get("err") == null) 1 else 0;
            try ilp_buffer.appendSlice(",success=");
            try std.fmt.format(ilp_buffer.writer(), "{d}", .{success});
            
            try ilp_buffer.appendSlice(",fee=");
            try std.fmt.format(ilp_buffer.writer(), "{d}", .{meta.get("fee").?.integer});
            
            try ilp_buffer.appendSlice(",compute_units_consumed=");
            try std.fmt.format(ilp_buffer.writer(), "{d}", .{if (meta.get("computeUnitsConsumed")) |cu| cu.integer else 0});
            
            try ilp_buffer.appendSlice(",compute_units_price=");
            try std.fmt.format(ilp_buffer.writer(), "{d}", .{0}); // compute_units_price
            
            try ilp_buffer.appendSlice(",recent_blockhash=\"");
            try ilp_buffer.appendSlice(message.get("recentBlockhash").?.string);
            try ilp_buffer.appendSlice("\"");
            
            // Timestamp (use block_time as timestamp in nanoseconds)
            try ilp_buffer.appendSlice(" ");
            try std.fmt.format(ilp_buffer.writer(), "{d}000000000", .{tx.get("blockTime").?.integer});
            
            try ilp_buffer.appendSlice("\n");
        }

        // Send the ILP data to QuestDB via HTTP
        try self.sendILP(ilp_buffer.items);
    }

    /// Send ILP data to QuestDB via HTTP
    fn sendILP(self: *Self, ilp_data: []const u8) !void {
        // Parse the URL to get the host and port
        const uri = try std.Uri.parse(self.url);
        const host = uri.host orelse return types.QuestDBError.InvalidUrl;
        const port = uri.port orelse 9000;

        // Create HTTP request to QuestDB ILP endpoint
        var request_uri_buffer: [1024]u8 = undefined;
        const request_uri = try std.fmt.bufPrint(request_uri_buffer, "{s}/write", .{self.url});
        
        var req = try self.http_client.open(.POST, try std.Uri.parse(request_uri), .{
            .server_header_buffer = &.{},
        });
        defer req.deinit();

        // Set content type for ILP
        try req.headers.append("content-type", "text/plain");
        
        req.transfer_encoding = .{ .content_length = ilp_data.len };
        try req.send();
        try req.writeAll(ilp_data);
        try req.finish();
        try req.wait();

        // Check response status
        if (req.response.status != .ok and req.response.status != .no_content) {
            std.log.err("QuestDB ILP insert failed with status: {}", .{req.response.status});
            return types.QuestDBError.QueryFailed;
        }

        std.log.debug("ILP data sent successfully to QuestDB");
    }

    fn getDatabaseSizeImpl(ptr: *anyopaque) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getDatabaseSize();
    }

    pub fn getDatabaseSize(self: *Self) !usize {
        // Query to get database size
        const query = "SELECT sum(table_size) FROM sys.tables";
        
        // For now, return 0 since we'd need to parse the HTTP response
        // This would require implementing a full HTTP response parser
        _ = self;
        _ = query;
        return 0;
    }

    fn getTableSizeImpl(ptr: *anyopaque, table_name: []const u8) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getTableSize(table_name);
    }

    pub fn getTableSize(self: *Self, table_name: []const u8) !usize {
        // For now, return 0 since we'd need to parse the HTTP response
        // This would require implementing a full HTTP response parser
        _ = self;
        _ = table_name;
        return 0;
    }

    // Core table operations
    pub usingnamespace core;

    // Token table operations
    pub usingnamespace token;

    // DeFi table operations
    pub usingnamespace defi;

    // NFT table operations
    pub usingnamespace nft;

    // Security table operations
    pub usingnamespace security;

    // Instruction table operations
    pub usingnamespace instruction;

    // Account table operations
    pub usingnamespace account;
};
