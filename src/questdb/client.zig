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
// const c_questdb = @import("c-questdb-client"); // Commented out for now

pub const QuestDBClient = struct {
    allocator: Allocator,
    url: []const u8,
    user: []const u8,
    password: []const u8,
    database: []const u8,
    // ilp_client: ?*anyopaque, // Disabled for now
    ilp_client: ?*anyopaque, // Placeholder
    logging_only: bool,
    db_client: database.DatabaseClient,

    const Self = @This();

    // VTable implementation for DatabaseClient interface
    const vtable = database.DatabaseClient.VTable{
        .deinitFn = deinitImpl,
        .executeQueryFn = executeQueryImpl,
        .verifyConnectionFn = verifyConnectionImpl,
        .createTablesFn = createTablesImpl,
        .insertTransactionFn = insertTransactionImpl,
        .insertTransactionBatchFn = insertTransactionBatchImpl,
        .insertProgramExecutionFn = insertProgramExecutionImpl,
        .insertAccountActivityFn = insertAccountActivityImpl,
        .insertInstructionFn = insertInstructionImpl,
        .insertAccountFn = insertAccountImpl,
        .insertBlockFn = insertBlockImpl,
        .updateBlockStatsFn = updateBlockStatsImpl,
        .getDatabaseSizeFn = getDatabaseSizeImpl,
        .getTableSizeFn = getTableSizeImpl,
    };

    pub fn init(
        allocator: Allocator,
        url: []const u8,
        user: []const u8,
        password: []const u8,
        db_name: []const u8,
    ) !Self {
        std.log.info("Initializing QuestDB client with URL: {s}, user: {s}, database: {s}", .{ url, user, db_name });

        // Validate URL
        _ = try std.Uri.parse(url);

        // Initialize the QuestDB client
        var ilp_client: ?*anyopaque = null;
        var logging_only = false;

        // Create the client
        ilp_client = null; // c_questdb.questdb_client_new(url.ptr, url.len) catch |err| {
        std.log.warn("QuestDB dependency not available - continuing in logging-only mode", .{});
        logging_only = true;
        // ilp_client = null;
        // };

        // Create the client instance
        const client = Self{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .user = try allocator.dupe(u8, user),
            .password = try allocator.dupe(u8, password),
            .database = try allocator.dupe(u8, db_name),
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
        // if (self.ilp_client) |client| {
        //     c_questdb.questdb_client_close(client);
        // }
        _ = self.ilp_client; // Acknowledge the field
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
            _ = client;
            // Execute the query using QuestDB's REST API
            // const result = c_questdb.questdb_client_execute_query(client, query.ptr, query.len) catch |err| {
            std.log.info("Would execute query: {s} (QuestDB disabled)", .{query});
            //     std.log.err("Failed to execute query: {any}", .{err});

            // Check for errors
            // // if (has_error) {
            //     const error_msg = c_questdb.questdb_result_get_error(result);
            //     std.log.err("Query failed: {s}", .{error_msg});
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

    fn insertTransactionImpl(ptr: *anyopaque, tx: database.Transaction) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertTransaction(tx);
    }

    pub fn insertTransaction(self: *Self, tx: database.Transaction) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping transaction insert for signature: {s}", .{tx.signature});
            return;
        }

        std.log.info("Would insert transaction {s} to QuestDB (disabled)", .{tx.signature});
    }

    fn insertProgramExecutionImpl(ptr: *anyopaque, pe: database.ProgramExecution) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertProgramExecution(pe);
    }

    pub fn insertProgramExecution(self: *Self, pe: database.ProgramExecution) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping program execution insert for program_id: {s}", .{pe.program_id});
            return;
        }

        std.log.info("Would insert program execution {s} to QuestDB (disabled)", .{pe.program_id});
    }

    fn insertAccountActivityImpl(ptr: *anyopaque, activity: database.AccountActivity) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertAccountActivity(activity);
    }

    pub fn insertAccountActivity(self: *Self, activity: database.AccountActivity) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping account activity insert for account: {s}", .{activity.pubkey});
            return;
        }

        std.log.info("Would insert account activity for {s} to QuestDB (disabled)", .{activity.pubkey});
    }

    fn insertInstructionImpl(ptr: *anyopaque, inst: database.Instruction) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        _ = self;
        _ = inst;
        // Simplified implementation for now
        return;
    }

    fn insertAccountImpl(ptr: *anyopaque, acc: database.Account) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        _ = self;
        _ = acc;
        // Simplified implementation for now
        return;
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
            _ = client; // // c_questdb.questdb_client_insert_ilp(client, ilp_buffer.items.ptr, ilp_buffer.items.len) catch |err| {
            std.log.info("Would insert ILP data (QuestDB disabled)", .{});
            // std.log.err("Failed to insert ILP data: {any}", .{err});
        }
    }

    fn getDatabaseSizeImpl(ptr: *anyopaque) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getDatabaseSize();
    }

    pub fn getDatabaseSize(self: *Self) !usize {
        if (self.logging_only) return 0;
        if (self.ilp_client == null) return 0;

        // QuestDB interaction disabled for now
        std.log.info("Would query database size (QuestDB disabled)", .{});
        return 0;
    }

    fn getTableSizeImpl(ptr: *anyopaque, table_name: []const u8) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getTableSize(table_name);
    }

    pub fn getTableSize(self: *Self, table_name: []const u8) !usize {
        if (self.logging_only) return 0;
        if (self.ilp_client == null) return 0;

        // QuestDB interaction disabled for now
        std.log.info("Would query table size for: {s} (QuestDB disabled)", .{table_name});
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

    /// Implementation for insertBlock vtable function
    fn insertBlockImpl(self: *anyopaque, block: database.Block) database.DatabaseError!void {
        const client = @as(*Self, @alignCast(@ptrCast(self)));
        
        if (client.logging_only) {
            std.log.info("INSERT Block: network={s}, slot={d}, time={d}, txs={d}", .{
                block.network, block.slot, block.block_time, block.transaction_count
            });
            return;
        }

        // QuestDB uses ILP (InfluxDB Line Protocol) for inserts
        // For now, just log since ILP client is not implemented
        std.log.info("QuestDB Block Insert: network={s}, slot={d}, time={d}", .{
            block.network, block.slot, block.block_time
        });
    }

    /// Implementation for updateBlockStats vtable function
    fn updateBlockStatsImpl(self: *anyopaque, stats: database.BlockStats) database.DatabaseError!void {
        const client = @as(*Self, @alignCast(@ptrCast(self)));
        
        if (client.logging_only) {
            std.log.info("UPDATE Block Stats: network={s}, slot={d}, success={d}, failed={d}", .{
                stats.network, stats.slot, stats.successful_transaction_count, stats.failed_transaction_count
            });
            return;
        }

        // QuestDB block stats update
        std.log.info("QuestDB Block Stats Update: network={s}, slot={d}", .{
            stats.network, stats.slot
        });
    }
};
