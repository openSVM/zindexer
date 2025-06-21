const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const token = @import("token.zig");
const defi = @import("defi.zig");
const nft = @import("nft.zig");
const security = @import("security.zig");
const transaction = @import("transaction.zig");
const instruction = @import("instruction.zig");
const account = @import("account.zig");
const json = std.json;

pub const dependencies = struct {
    pub const rpc = @import("../rpc.zig");
    pub const database = @import("../database.zig");
    pub const clickhouse = @import("../clickhouse.zig");
    pub const questdb = @import("../questdb.zig");
};

pub const IndexerError = error{
    InitializationFailed,
    ProcessingFailed,
    DatabaseError,
};

pub const IndexerMode = enum {
    Historical,
    RealTime,
};

pub const IndexerConfig = struct {
    rpc_nodes_file: []const u8,
    ws_nodes_file: []const u8,
    database_type: dependencies.database.DatabaseType = .ClickHouse,
    database_url: []const u8,
    database_user: []const u8 = "default",
    database_password: []const u8 = "",
    database_name: []const u8 = "default",
    mode: IndexerMode = .Historical,
    batch_size: u32 = 20,
    max_retries: u32 = 3,
    retry_delay_ms: u32 = 1000,
    default_network: []const u8 = "mainnet",
};

pub const ProcessingStats = struct {
    total_transactions: u64 = 0,
    total_instructions: u64 = 0,
    total_accounts_updated: u64 = 0,
    successful_txs: u64 = 0,
    failed_txs: u64 = 0,
    total_compute_units: u64 = 0,
    total_fees: u64 = 0,
};

pub const Indexer = struct {
    allocator: Allocator,
    config: IndexerConfig,
    rpc_client: dependencies.rpc.RpcClient,
    db_client: *dependencies.database.DatabaseClient,
    current_slot: u64,
    target_slot: u64,
    running: bool,
    total_slots_processed: u64,
    stats: ProcessingStats = .{},
    stats_callback: ?*const fn (*anyopaque, []const u8, u64, u64, bool, bool) void,
    stats_ctx: ?*anyopaque,
    logging_only: bool = false,
    current_network: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, config: IndexerConfig) !Self {
        // Initialize database client based on the configured type
        var db_client = try dependencies.database.createDatabaseClient(
            allocator,
            config.database_type,
            config.database_url,
            config.database_user,
            config.database_password,
            config.database_name
        );
        errdefer db_client.deinit();

        var logging_only = false;

        // Create database tables - this will verify connection
        std.log.info("Verifying database connection and creating tables...", .{});
        db_client.createTables() catch |err| {
            std.log.warn("Failed to connect to database: {any} - continuing in logging-only mode", .{err});
            logging_only = true;
        };

        if (!logging_only) {
            std.log.info("Successfully connected to database", .{});
        }

        // Now initialize RPC client
        var rpc_client = try dependencies.rpc.RpcClient.initFromFiles(allocator, config.rpc_nodes_file, config.ws_nodes_file);
        errdefer rpc_client.deinit();

        // Get current slot from RPC
        const current_slot = try rpc_client.getSlot(config.default_network);

        return Self{
            .allocator = allocator,
            .config = config,
            .rpc_client = rpc_client,
            .db_client = db_client,
            .current_slot = current_slot,
            .target_slot = 0, // Start from genesis
            .running = false,
            .total_slots_processed = 0,
            .stats = .{},
            .stats_callback = null,
            .stats_ctx = null,
            .logging_only = logging_only,
            .current_network = try allocator.dupe(u8, config.default_network),
        };
    }

    pub fn deinit(self: *Self) void {
        self.running = false;
        self.rpc_client.deinit();
        self.db_client.deinit();
        self.allocator.free(self.current_network);

        // Stats callback context is cleaned up by the caller
        self.stats_ctx = null;
        self.stats_callback = null;
    }

    pub fn setStatsCallback(self: *Self, callback: *const fn (*anyopaque, []const u8, u64, u64, bool, bool) void, ctx: anytype) void {
        const T = @TypeOf(ctx);
        const ptr = self.allocator.create(T) catch return;
        ptr.* = ctx;
        self.stats_callback = callback;
        self.stats_ctx = @ptrCast(ptr);
    }

    fn updateStats(self: *Self) void {
        if (self.stats_callback) |callback| {
            if (self.stats_ctx) |ctx| {
                const rpc_ok = true; // TODO: Add proper status checks
                const db_ok = !self.logging_only;
                callback(ctx, self.current_network, self.current_slot, self.total_slots_processed, rpc_ok, db_ok);
            }
        }
    }

    pub fn start(self: *Self) !void {
        self.running = true;

        switch (self.config.mode) {
            .Historical => try self.startHistorical(),
            .RealTime => try self.startRealTime(),
        }
    }

    fn startHistorical(self: *Self) !void {
        std.log.info("Starting historical indexer from slot {d} to {d} ({s})", .{ self.current_slot, self.target_slot, if (self.logging_only) "logging-only mode" else "full indexing mode" });

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const batch_size = self.config.batch_size;
        var current_batch = try self.allocator.alloc(u64, batch_size);
        defer self.allocator.free(current_batch);

        while (self.running and self.current_slot > self.target_slot) {
            // Fill batch with slot numbers
            var i: usize = 0;
            while (i < batch_size and self.current_slot > self.target_slot) : (i += 1) {
                current_batch[i] = self.current_slot;
                self.current_slot -= 1;
            }

            try self.processBatch(current_batch[0..i]);
            self.total_slots_processed += i;
            self.updateStats();

            // Log batch processing stats
            std.log.info("Batch Stats: {d} slots, {d} txs ({d} success, {d} fail), {d} instructions, {d} accounts, {d} CU, {d} SOL fees", .{ i, self.stats.total_transactions, self.stats.successful_txs, self.stats.failed_txs, self.stats.total_instructions, self.stats.total_accounts_updated, self.stats.total_compute_units, @as(f64, @floatFromInt(self.stats.total_fees)) / 1000000000.0 });
        }
    }

    fn startRealTime(self: *Self) !void {
        std.log.info("Starting real-time indexer using WebSocket ({s})", .{if (self.logging_only) "logging-only mode" else "full indexing mode"});

        const Context = struct {
            indexer: *Self,
            last_slot: u64,
            arena: std.heap.ArenaAllocator,
            allocator: Allocator,

            pub fn init(allocator: Allocator, indexer: *Self) !*@This() {
                const ctx = try allocator.create(@This());
                errdefer allocator.destroy(ctx);

                ctx.* = .{
                    .indexer = indexer,
                    .last_slot = 0, // Will be set after creation
                    .arena = std.heap.ArenaAllocator.init(allocator),
                    .allocator = allocator,
                };

                // Get initial slot after struct is fully initialized
                ctx.last_slot = indexer.rpc_client.getSlot(indexer.current_network) catch |err| {
                    std.log.err("Failed to get initial slot: {any}", .{err});
                    return err;
                };
                std.log.info("Got initial slot: {d}", .{ctx.last_slot});
                return ctx;
            }

            pub fn deinit(ctx: *@This()) void {
                ctx.arena.deinit();
                ctx.allocator.destroy(ctx);
            }
        };

        var ctx = Context.init(self.allocator, self) catch |err| {
            std.log.err("Failed to initialize realtime context: {any}", .{err});
            return err;
        };
        errdefer ctx.deinit();

        std.log.info("Starting from slot {d}", .{ctx.last_slot});

        // Subscribe to slot updates
        self.rpc_client.subscribeSlots(self.current_network, ctx, struct {
            fn callback(ctx_ptr: *anyopaque, _: *dependencies.rpc.WebSocketClient, value: json.Value) void {
                const context = @as(*Context, @alignCast(@ptrCast(ctx_ptr)));
                const indexer = context.indexer;

                // Early return if indexer is stopped
                if (!indexer.running) return;

                // Reset arena allocator for this callback
                context.arena.deinit();
                context.arena = std.heap.ArenaAllocator.init(context.allocator);

                // Extract slot from params safely
                const params = value.object.get("params") orelse {
                    std.log.err("Missing params in WebSocket message", .{});
                    return;
                };
                if (params.array.items.len == 0) {
                    std.log.err("Empty params array in WebSocket message", .{});
                    return;
                }

                const slot_obj = params.array.items[0].object.get("slot") orelse {
                    std.log.err("Missing slot in WebSocket message", .{});
                    return;
                };
                const slot = @as(u64, @intCast(slot_obj.integer));

                // Only process newer slots
                if (slot <= context.last_slot) {
                    std.log.info("Skipping old slot {d} (current: {d})", .{ slot, context.last_slot });
                    return;
                }

                std.log.info("Processing slot {d}", .{slot});

                // Process slot with error handling
                indexer.processSlot(slot) catch |err| {
                    std.log.err("Failed to process slot {d}: {any}", .{ slot, err });
                    return;
                };

                indexer.total_slots_processed += 1;
                indexer.current_slot = slot;
                indexer.updateStats();
                context.last_slot = slot;
            }
        }.callback) catch |err| {
            std.log.err("Failed to subscribe to slots: {any}", .{err});
            return err;
        };

        std.log.info("Subscribed to slot updates", .{});

        // Keep running until stopped
        while (self.running) {
            std.time.sleep(1 * std.time.ns_per_s);
            // Log detailed stats every second
            std.log.info("Indexer Stats: {d} slots, {d} txs ({d} success, {d} fail), {d} instructions, {d} accounts, {d} CU, {d} SOL fees", .{ self.total_slots_processed, self.stats.total_transactions, self.stats.successful_txs, self.stats.failed_txs, self.stats.total_instructions, self.stats.total_accounts_updated, self.stats.total_compute_units, @as(f64, @floatFromInt(self.stats.total_fees)) / 1000000000.0 });
        }

        // Cleanup
        ctx.deinit();
        std.log.info("Realtime indexer stopped", .{});
    }

    fn processSlot(self: *Self, slot: u64) !void {
        std.log.info("Processing slot {d}", .{slot});

        // Verify ClickHouse connection periodically (every 100 slots)
        if (!self.logging_only and slot % 100 == 0) {
            self.db_client.verifyConnection() catch |err| {
                std.log.err("Lost connection to ClickHouse: {any}", .{err});
                return IndexerError.DatabaseError;
            };
        }

        // Create arena for this slot processing
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        // Fetch block with retries
        var retries: u32 = 0;
        var block_json: json.Value = undefined;
        var fetch_success = false;

        while (retries < self.config.max_retries) : (retries += 1) {
            block_json = self.rpc_client.getBlock(self.current_network, slot) catch |err| {
                std.log.warn("Failed to fetch block {d} (attempt {d}/{d}): {any}", .{ slot, retries + 1, self.config.max_retries, err });
                if (retries + 1 < self.config.max_retries) {
                    std.time.sleep(self.config.retry_delay_ms * std.time.ns_per_ms);
                    continue;
                }
                return err;
            };
            fetch_success = true;
            break;
        }

        if (!fetch_success) {
            return error.BlockFetchFailed;
        }

        // Parse block info
        const block = try dependencies.rpc.BlockInfo.fromJson(arena.allocator(), block_json);
        defer block.deinit(arena.allocator());

        // Track slot-level stats
        var slot_stats = ProcessingStats{};

        // Process transactions with error handling
        for (block.transactions) |tx_json| {
            const tx = tx_json.object;
            const meta = tx.get("meta").?.object;
            const message = tx.get("transaction").?.object.get("message").?.object;

            slot_stats.total_transactions += 1;
            slot_stats.total_instructions += message.get("instructions").?.array.items.len;
            slot_stats.total_accounts_updated += message.get("accountKeys").?.array.items.len;

            if (meta.get("err") == null) {
                slot_stats.successful_txs += 1;
            } else {
                slot_stats.failed_txs += 1;
            }

            if (meta.get("computeUnitsConsumed")) |cu| {
                slot_stats.total_compute_units += @as(u64, @intCast(cu.integer));
            }
            slot_stats.total_fees += @as(u64, @intCast(meta.get("fee").?.integer));

            // Only process database operations if not in logging-only mode
            if (!self.logging_only) {
                transaction.processTransaction(self, slot, block.block_time orelse 0, tx_json, self.current_network) catch |err| {
                    std.log.err("Failed to process transaction in slot {d}: {any}", .{ slot, err });
                    continue;
                };

                instruction.processInstructions(self, slot, block.block_time orelse 0, tx_json, self.current_network) catch |err| {
                    std.log.err("Failed to process instructions in slot {d}: {any}", .{ slot, err });
                    continue;
                };

                account.processAccountUpdates(self, slot, block.block_time orelse 0, tx_json, self.current_network) catch |err| {
                    std.log.err("Failed to process account updates in slot {d}: {any}", .{ slot, err });
                    continue;
                };
            }
        }

        // Update global stats
        self.stats.total_transactions += slot_stats.total_transactions;
        self.stats.total_instructions += slot_stats.total_instructions;
        self.stats.total_accounts_updated += slot_stats.total_accounts_updated;
        self.stats.successful_txs += slot_stats.successful_txs;
        self.stats.failed_txs += slot_stats.failed_txs;
        self.stats.total_compute_units += slot_stats.total_compute_units;
        self.stats.total_fees += slot_stats.total_fees;

        std.log.info("Processed slot {d} - Stats: {d} txs ({d} success, {d} fail), {d} instructions, {d} accounts, {d} CU, {d} SOL fees", .{ slot, slot_stats.total_transactions, slot_stats.successful_txs, slot_stats.failed_txs, slot_stats.total_instructions, slot_stats.total_accounts_updated, slot_stats.total_compute_units, @as(f64, @floatFromInt(slot_stats.total_fees)) / 1000000000.0 });
    }

    fn processBatch(self: *Self, slots: []const u64) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        // Process blocks sequentially for now to avoid memory issues
        // TODO: Implement proper parallel processing with resource limits
        for (slots) |slot| {
            self.processSlot(slot) catch |err| {
                std.log.err("Failed to process slot {d}: {any}", .{ slot, err });
                continue;
            };
        }
    }
};
