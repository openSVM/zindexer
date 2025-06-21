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

pub const ClickHouseClient = struct {
    allocator: Allocator,
    url: []const u8,
    user: []const u8,
    password: []const u8,
    database: []const u8,
    stream: ?net.Stream,
    logging_only: bool,
    db_client: database.DatabaseClient,
    
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
        .getDatabaseSizeFn = getDatabaseSizeImpl,
        .getTableSizeFn = getTableSizeImpl,
    };

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        url: []const u8,
        user: []const u8,
        password: []const u8,
        db_name: []const u8,
    ) !Self {
        std.log.info("Initializing ClickHouse client with URL: {s}, user: {s}, database: {s}", .{ url, user, db_name });

        // Validate URL
        _ = try std.Uri.parse(url);

        return Self{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .user = try allocator.dupe(u8, user),
            .password = try allocator.dupe(u8, password),
            .database = try allocator.dupe(u8, db_name),
            .stream = null,
            .logging_only = false,
            .db_client = database.DatabaseClient{
                .vtable = &vtable,
            },
        };
    }

    // Implementation of DatabaseClient interface methods
    fn deinitImpl(ptr: *anyopaque) void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        self.deinit();
    }
    
    pub fn deinit(self: *Self) void {
        if (self.stream) |*stream| {
            stream.close();
        }
        self.allocator.free(self.url);
        self.allocator.free(self.user);
        self.allocator.free(self.password);
        self.allocator.free(self.database);
    }

    fn connect(self: *Self) !void {
        if (self.stream != null) return;

        // Parse host and port directly since we're using raw IP:port format
        const sep_index = std.mem.indexOf(u8, self.url, ":") orelse return error.InvalidUrl;
        const host = self.url[0..sep_index];
        const port_str = self.url[sep_index + 1 ..];
        const port = try std.fmt.parseInt(u16, port_str, 10);

        const address = try net.Address.parseIp(host, port);
        self.stream = net.tcpConnectToAddress(address) catch |err| {
            std.log.warn("Failed to connect to ClickHouse: {any} - continuing in logging-only mode", .{err});
            self.logging_only = true;
            return;
        };
        errdefer if (self.stream) |*s| s.close();

        // Send client hello packet
        var hello_packet = std.ArrayList(u8).init(self.allocator);
        defer hello_packet.deinit();

        // Protocol version
        try hello_packet.append(0x01); // Version 1
        try hello_packet.append(0x00);
        try hello_packet.append(0x00);
        try hello_packet.append(0x00);

        // Client name
        try hello_packet.appendSlice("zig-client");
        try hello_packet.append(0x00);

        // Client version
        try hello_packet.appendSlice("1.0.0");
        try hello_packet.append(0x00);

        // Client revision
        var revision_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &revision_bytes, 54442, .little); // DBMS_MIN_REVISION_WITH_CLIENT_INFO
        try hello_packet.appendSlice(&revision_bytes);

        // Database
        try hello_packet.appendSlice(self.database);
        try hello_packet.append(0x00);

        // Username
        try hello_packet.appendSlice(self.user);
        try hello_packet.append(0x00);

        // Password
        try hello_packet.appendSlice(self.password);
        try hello_packet.append(0x00);

        // Send the complete packet
        try self.stream.?.writeAll(hello_packet.items);

        // Read server hello response
        var response_header: [9]u8 = undefined;
        const n = try self.stream.?.read(&response_header);
        if (n != 9) return error.ConnectionClosed;

        // Check response code (0x00 = success)
        if (response_header[0] != 0x00) {
            // Read error message length
            var error_len_bytes: [4]u8 = undefined;
            _ = try self.stream.?.read(&error_len_bytes);
            const error_len = std.mem.readInt(u32, &error_len_bytes, .little);

            // Read error message
            const error_msg = try self.allocator.alloc(u8, error_len);
            defer self.allocator.free(error_msg);
            _ = try self.stream.?.read(error_msg);

            std.log.err("Authentication failed: {s}", .{error_msg});
            std.log.err("Connection details: host={s}, user={s}, database={s}", .{ self.url, self.user, self.database });
            return error.AuthenticationFailed;
        }
    }

    fn executeQueryImpl(ptr: *anyopaque, query: []const u8) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.executeQuery(query) catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }
    
    pub fn executeQuery(self: *Self, query: []const u8) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping query: {s}", .{query});
            return;
        }

        try self.connect();

        // Send query packet
        var query_packet = [_]u8{
            0x01, // Query packet type
            0x00, // Query flags
            0x00, 0x00, 0x00, 0x00, // Query ID
        };
        try self.stream.?.writeAll(&query_packet);

        // Send query string length (little endian)
        const query_len = @as(u32, @intCast(query.len));
        var len_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &len_bytes, query_len, .little);
        try self.stream.?.writeAll(&len_bytes);

        // Send query string
        try self.stream.?.writeAll(query);

        // Read response header
        var response_header: [8]u8 = undefined;
        const n = try self.stream.?.read(&response_header);
        if (n != 8) return error.ConnectionClosed;

        // Check response type (0x02 = Data packet)
        if (response_header[0] != 0x02) {
            // Read error message length
            var error_len_bytes: [4]u8 = undefined;
            _ = try self.stream.?.read(&error_len_bytes);
            const error_len = std.mem.readInt(u32, &error_len_bytes, .little);

            // Read error message
            const error_msg = try self.allocator.alloc(u8, error_len);
            defer self.allocator.free(error_msg);
            _ = try self.stream.?.read(error_msg);

            std.log.err("Query failed: {s}", .{error_msg});
            return types.ClickHouseError.QueryFailed;
        }
    }

    fn verifyConnectionImpl(ptr: *anyopaque) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.verifyConnection() catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }
    
    pub fn verifyConnection(self: *Self) !void {
        // Try a simple query to verify connection
        try self.executeQuery("SELECT 1");
        std.log.info("ClickHouse connection verified", .{});
    }

    fn createTablesImpl(ptr: *anyopaque) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.createTables() catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }
    
    pub fn createTables(self: *Self) !void {
        // First verify connection
        self.verifyConnection() catch |err| {
            std.log.warn("Failed to connect to ClickHouse: {any} - continuing in logging-only mode", .{err});
            self.logging_only = true;
            return;
        };

        if (self.logging_only) return;

        // Create database if not exists
        try self.executeQuery(try std.fmt.allocPrint(self.allocator,
            \\CREATE DATABASE IF NOT EXISTS {s}
        , .{self.database}));

        // Create tables
        try self.executeQuery(
            \\CREATE TABLE IF NOT EXISTS transactions (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time Int64,
            \\    success UInt8,
            \\    fee UInt64,
            \\    compute_units_consumed UInt64,
            \\    compute_units_price UInt64,
            \\    recent_blockhash String
            \\) ENGINE = MergeTree()
            \\ORDER BY (network, slot, signature)
        );

        try self.executeQuery(
            \\CREATE TABLE IF NOT EXISTS program_executions (
            \\    network String,
            \\    program_id String,
            \\    slot UInt64,
            \\    block_time Int64,
            \\    execution_count UInt32,
            \\    total_cu_consumed UInt64,
            \\    total_fee UInt64,
            \\    success_count UInt32,
            \\    error_count UInt32
            \\) ENGINE = MergeTree()
            \\ORDER BY (network, slot, program_id)
        );

        try self.executeQuery(
            \\CREATE TABLE IF NOT EXISTS account_activity (
            \\    network String,
            \\    pubkey String,
            \\    slot UInt64,
            \\    block_time Int64,
            \\    program_id String,
            \\    write_count UInt32,
            \\    cu_consumed UInt64,
            \\    fee_paid UInt64
            \\) ENGINE = MergeTree()
            \\ORDER BY (network, slot, pubkey)
        );

        try self.executeQuery(
            \\CREATE TABLE IF NOT EXISTS instructions (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time Int64,
            \\    program_id String,
            \\    instruction_index UInt32,
            \\    inner_instruction_index Nullable(UInt32),
            \\    instruction_type String,
            \\    parsed_data String
            \\) ENGINE = MergeTree()
            \\ORDER BY (network, slot, signature, instruction_index)
        );

        try self.executeQuery(
            \\CREATE TABLE IF NOT EXISTS accounts (
            \\    network String,
            \\    pubkey String,
            \\    slot UInt64,
            \\    block_time Int64,
            \\    owner String,
            \\    lamports UInt64,
            \\    executable UInt8,
            \\    rent_epoch UInt64,
            \\    data_len UInt64,
            \\    write_version UInt64
            \\) ENGINE = MergeTree()
            \\ORDER BY (network, slot, pubkey)
        );

        try self.executeQuery(
            \\CREATE TABLE IF NOT EXISTS account_updates (
            \\    network String,
            \\    pubkey String,
            \\    slot UInt64,
            \\    block_time Int64,
            \\    owner String,
            \\    lamports UInt64,
            \\    executable UInt8,
            \\    rent_epoch UInt64,
            \\    data_len UInt64,
            \\    write_version UInt64
            \\) ENGINE = MergeTree()
            \\ORDER BY (network, slot, pubkey)
        );
    }

    fn insertTransactionImpl(ptr: *anyopaque, tx: database.Transaction) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertSingleTransaction(tx) catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }

    pub fn insertSingleTransaction(self: *Self, tx: database.Transaction) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping transaction insert for signature: {s}", .{tx.signature});
            return;
        }

        // Create a simple insert query for the transaction
        const query = try std.fmt.allocPrint(self.allocator, 
            \\INSERT INTO transactions VALUES ('{s}', '{s}', {d}, {d}, {any}, {d}, {d}, {d}, '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', '{s}', '{s}')
        , .{
            tx.network,
            tx.signature, 
            tx.slot, 
            tx.block_time, 
            tx.success, 
            tx.fee, 
            tx.compute_units_consumed, 
            tx.compute_units_price, 
            tx.recent_blockhash,
            "", // program_ids placeholder
            "", // signers placeholder  
            "", // account_keys placeholder
            "", // pre_balances placeholder
            "", // post_balances placeholder
            "", // pre_token_balances placeholder
            "", // post_token_balances placeholder
            tx.error_msg orelse ""
        });
        defer self.allocator.free(query);
        
        try self.executeQuery(query);
    }

    fn insertProgramExecutionImpl(ptr: *anyopaque, pe: database.ProgramExecution) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertProgramExecutionSingle(pe) catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }

    pub fn insertProgramExecutionSingle(self: *Self, pe: database.ProgramExecution) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping program execution insert for program_id: {s}", .{pe.program_id});
            return;
        }

        // Create a simple insert query for the program execution
        const query = try std.fmt.allocPrint(self.allocator, 
            \\INSERT INTO program_executions VALUES ('{s}', '{s}', {d}, {d}, {d}, {d}, {d}, {d}, {d})
        , .{
            pe.network,
            pe.program_id, 
            pe.slot, 
            pe.block_time, 
            pe.execution_count,
            pe.total_cu_consumed, 
            pe.total_fee,
            pe.success_count,
            pe.error_count
        });
        defer self.allocator.free(query);
        
        try self.executeQuery(query);
    }

    fn insertAccountActivityImpl(ptr: *anyopaque, activity: database.AccountActivity) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertAccountActivitySingle(activity) catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }

    pub fn insertAccountActivitySingle(self: *Self, activity: database.AccountActivity) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping account activity insert for account: {s}", .{activity.pubkey});
            return;
        }

        const query = try std.fmt.allocPrint(self.allocator, 
            \\INSERT INTO account_activity VALUES ('{s}', '{s}', {d}, {d}, '{s}', {d}, {d}, {d})
        , .{
            activity.network, 
            activity.pubkey, 
            activity.slot, 
            activity.block_time, 
            activity.program_id,
            activity.write_count, 
            activity.cu_consumed,
            activity.fee_paid
        });
        defer self.allocator.free(query);
        
        try self.executeQuery(query);
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

    // Size tracking operations
    fn getDatabaseSizeImpl(ptr: *anyopaque) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getDatabaseSize() catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }
    
    pub fn getDatabaseSize(self: *Self) !usize {
        if (self.logging_only) return 0;

        self.connect() catch |err| {
            std.log.warn("Failed to connect to ClickHouse: {any}", .{err});
            return 0;
        };

        if (self.stream) |stream| {
            // Query to get database size in bytes
            const query = try std.fmt.allocPrint(self.allocator,
                \\SELECT total_bytes
                \\FROM system.databases
                \\WHERE name = '{s}'
            , .{self.database});
            defer self.allocator.free(query);

            try self.executeQuery(query);

            // Read response (assuming single row with single column)
            var size_bytes: [8]u8 = undefined;
            const n = try stream.read(&size_bytes);
            if (n != 8) return error.InvalidResponse;

            return std.mem.readInt(u64, &size_bytes, .little);
        }

        return 0;
    }

    fn getTableSizeImpl(ptr: *anyopaque, table_name: []const u8) database.DatabaseError!usize {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.getTableSize(table_name) catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }
    
    pub fn getTableSize(self: *Self, table_name: []const u8) !usize {
        if (self.logging_only) return 0;

        self.connect() catch |err| {
            std.log.warn("Failed to connect to ClickHouse: {any}", .{err});
            return 0;
        };

        if (self.stream) |stream| {
            // Query to get table size in bytes
            const query = try std.fmt.allocPrint(self.allocator,
                \\SELECT total_bytes
                \\FROM system.tables
                \\WHERE database = '{s}' AND name = '{s}'
            , .{ self.database, table_name });
            defer self.allocator.free(query);

            try self.executeQuery(query);

            // Read response (assuming single row with single column)
            var size_bytes: [8]u8 = undefined;
            const n = try stream.read(&size_bytes);
            if (n != 8) return error.InvalidResponse;

            return std.mem.readInt(u64, &size_bytes, .little);
        }

        return 0;
    }

    fn insertTransactionBatchImpl(ptr: *anyopaque, transactions: []const std.json.Value, network_name: []const u8) database.DatabaseError!void {
        const self = @as(*Self, @ptrCast(@alignCast(ptr)));
        return self.insertTransactionBatch(transactions, network_name) catch |err| switch (err) {
            error.OutOfMemory => error.DatabaseError,
            else => error.DatabaseError,
        };
    }
    
    pub fn insertTransactionBatch(self: *Self, transactions: []const std.json.Value, network_name: []const u8) !void {
        if (self.logging_only) {
            std.log.info("Logging-only mode, skipping batch insert of {d} transactions for network {s}", .{transactions.len, network_name});
            return;
        }

        try self.connect();

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        // Build batch insert query
        var query = std.ArrayList(u8).init(arena.allocator());
        try query.appendSlice("INSERT INTO transactions (network, signature, slot, block_time, success, fee, compute_units_consumed, compute_units_price, recent_blockhash) VALUES ");

        for (transactions, 0..) |tx_json, i| {
            const tx = tx_json.object;
            const meta = tx.get("meta").?.object;
            const message = tx.get("transaction").?.object.get("message").?.object;

            if (i > 0) try query.appendSlice(",");
            try query.appendSlice("('");
            try query.appendSlice(network_name);
            try query.appendSlice("','");
            try query.appendSlice(tx.get("transaction").?.object.get("signatures").?.array.items[0].string);
            try query.appendSlice("',");
            try std.fmt.format(query.writer(), "{d},", .{tx.get("slot").?.integer});
            try std.fmt.format(query.writer(), "{d},", .{tx.get("blockTime").?.integer});
            const success: u8 = if (meta.get("err") == null) 1 else 0;
            try std.fmt.format(query.writer(), "{d},", .{success});
            try std.fmt.format(query.writer(), "{d},", .{meta.get("fee").?.integer});
            try std.fmt.format(query.writer(), "{d},", .{if (meta.get("computeUnitsConsumed")) |cu| cu.integer else 0});
            try std.fmt.format(query.writer(), "{d},'", .{0}); // compute_units_price
            try query.appendSlice(message.get("recentBlockhash").?.string);
            try query.appendSlice("')");
        }

        try self.executeQuery(query.items);
    }
};
