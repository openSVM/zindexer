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
const c_questdb = @import("c-questdb-client");

pub const QuestDBClient = struct {
    allocator: Allocator,
    url: []const u8,
    user: []const u8,
    password: []const u8,
    database: []const u8,
    ilp_client: ?*c_questdb.QuestDBClient,
    logging_only: bool,
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

        // Initialize the QuestDB client
        var ilp_client: ?*c_questdb.QuestDBClient = null;
        var logging_only = false;

        // Create the client
        ilp_client = c_questdb.questdb_client_new(url.ptr, url.len) catch |err| {
            std.log.warn("Failed to create QuestDB client: {any} - continuing in logging-only mode", .{err});
            logging_only = true;
            ilp_client = null;
        };

        // Create the client instance
        var client = Self{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .user = try allocator.dupe(u8, user),
            .password = try allocator.dupe(u8, password),
            .database = try allocator.dupe(u8, database),
            .ilp_client = ilp_client,
            .logging_only = logging_only,
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
        if (self.ilp_client) |client| {
            c_questdb.questdb_client_close(client);
        }
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
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping query: {s}", .{query});
            return;
        }

        if (self.ilp_client) |client| {
            // Execute the query using QuestDB's REST API
            const result = c_questdb.questdb_client_execute_query(client, query.ptr, query.len) catch |err| {
                std.log.err("Failed to execute query: {any}", .{err});
                return types.QuestDBError.QueryFailed;
            };
            defer c_questdb.questdb_result_free(result);

            // Check for errors
            if (c_questdb.questdb_result_has_error(result)) {
                const error_msg = c_questdb.questdb_result_get_error(result);
                std.log.err("Query failed: {s}", .{error_msg});
                return types.QuestDBError.QueryFailed;
            }
        } else {
            return types.QuestDBError.ConnectionFailed;
        }
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
        // First verify connection
        self.verifyConnection() catch |err| {
            std.log.warn("Failed to connect to QuestDB: {any} - continuing in logging-only mode", .{err});
            self.logging_only = true;
            return;
        };

        if (self.logging_only) return;

        // Create tables - these would be created by the schema application script
        // We'll just verify they exist here
        try self.executeQuery("SHOW TABLES");
    }

    fn insertTransactionBatchImpl(ptr: *anyopaque, transactions: []const std.json.Value, network_name: []const u8) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertTransactionBatch(transactions, network_name);
    }

    pub fn insertTransactionBatch(self: *Self, transactions: []const std.json.Value, network_name: []const u8) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping batch insert of {d} transactions for network {s}", .{transactions.len, network_name});
            return;
        }

        if (self.ilp_client == null) return types.QuestDBError.ConnectionFailed;

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
            try std.fmt.format(ilp_buffer.writer(), "{d}000000", .{tx.get("blockTime").?.integer});
            
            try ilp_buffer.appendSlice("\n");
        }

        // Send the ILP data to QuestDB
        if (self.ilp_client) |client| {
            _ = c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
                std.log.err("Failed to insert ILP data: {any}", .{err});
                return types.QuestDBError.QueryFailed;
            };
        }
    }

    fn getDatabaseSizeImpl(ptr: *anyopaque) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getDatabaseSize();
    }

    pub fn getDatabaseSize(self: *Self) !usize {
        if (self.logging_only) return 0;
        if (self.ilp_client == null) return 0;

        // Query to get database size
        const query = try std.fmt.allocPrint(self.allocator,
            \\SELECT sum(size) FROM sys.tables
        , .{});
        defer self.allocator.free(query);

        // Execute query and parse result
        if (self.ilp_client) |client| {
            const result = c_questdb.questdb_client_execute_query(client, query.ptr, query.len) catch |err| {
                std.log.warn("Failed to get database size: {any}", .{err});
                return 0;
            };
            defer c_questdb.questdb_result_free(result);

            if (c_questdb.questdb_result_has_error(result)) {
                std.log.warn("Failed to get database size: {s}", .{c_questdb.questdb_result_get_error(result)});
                return 0;
            }

            // Get the first row, first column as size
            if (c_questdb.questdb_result_row_count(result) > 0) {
                const size_str = c_questdb.questdb_result_get_value(result, 0, 0);
                return std.fmt.parseInt(usize, size_str, 10) catch 0;
            }
        }

        return 0;
    }

    fn getTableSizeImpl(ptr: *anyopaque, table_name: []const u8) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getTableSize(table_name);
    }

    pub fn getTableSize(self: *Self, table_name: []const u8) !usize {
        if (self.logging_only) return 0;
        if (self.ilp_client == null) return 0;

        // Query to get table size
        const query = try std.fmt.allocPrint(self.allocator,
            \\SELECT size FROM sys.tables WHERE name = '{s}'
        , .{table_name});
        defer self.allocator.free(query);

        // Execute query and parse result
        if (self.ilp_client) |client| {
            const result = c_questdb.questdb_client_execute_query(client, query.ptr, query.len) catch |err| {
                std.log.warn("Failed to get table size: {any}", .{err});
                return 0;
            };
            defer c_questdb.questdb_result_free(result);

            if (c_questdb.questdb_result_has_error(result)) {
                std.log.warn("Failed to get table size: {s}", .{c_questdb.questdb_result_get_error(result)});
                return 0;
            }

            // Get the first row, first column as size
            if (c_questdb.questdb_result_row_count(result) > 0) {
                const size_str = c_questdb.questdb_result_get_value(result, 0, 0);
                return std.fmt.parseInt(usize, size_str, 10) catch 0;
            }
        }

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
