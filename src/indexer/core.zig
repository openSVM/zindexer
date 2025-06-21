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
    token_transfers: u32 = 0,
    token_mints: u32 = 0,
    token_burns: u32 = 0,
    nft_mints: u32 = 0,
    nft_sales: u32 = 0,
    amm_swaps: u32 = 0,
    defi_events: u32 = 0,
    security_events: u32 = 0,
    blocks_processed: u64 = 0,
};

pub const NetworkIndexer = struct {
    network_name: []const u8,
    current_slot: u64,
    target_slot: u64,
    stats: ProcessingStats = .{},
    last_processed_time: i64 = 0,
    is_connected: bool = false,
    subscription_id: ?[]const u8 = null,
};

pub const Indexer = struct {
    allocator: Allocator,
    config: IndexerConfig,
    rpc_client: dependencies.rpc.RpcClient,
    db_client: *dependencies.database.DatabaseClient,
    running: bool,
    networks: std.HashMap([]const u8, *NetworkIndexer, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    global_stats: ProcessingStats = .{},
    stats_callback: ?*const fn (*anyopaque, []const u8, u64, u64, bool, bool) void,
    stats_ctx: ?*anyopaque,
    logging_only: bool = false,

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

        // Initialize RPC client
        var rpc_client = try dependencies.rpc.RpcClient.initFromFiles(allocator, config.rpc_nodes_file, config.ws_nodes_file);
        errdefer rpc_client.deinit();

        // Initialize networks hashmap
        var networks = std.HashMap([]const u8, *NetworkIndexer, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator);
        errdefer {
            var iterator = networks.iterator();
            while (iterator.next()) |entry| {
                allocator.destroy(entry.value_ptr.*);
            }
            networks.deinit();
        }

        // Get available networks from RPC client and initialize them
        const available_networks = rpc_client.getAvailableNetworks();
        for (available_networks) |network_name| {
            const network_indexer = try allocator.create(NetworkIndexer);
            errdefer allocator.destroy(network_indexer);

            // Get current slot for this network
            const current_slot = rpc_client.getSlot(network_name) catch |err| {
                std.log.warn("Failed to get slot for network {s}: {any}", .{ network_name, err });
                continue;
            };

            network_indexer.* = .{
                .network_name = try allocator.dupe(u8, network_name),
                .current_slot = current_slot,
                .target_slot = 0,
                .stats = .{},
                .last_processed_time = std.time.timestamp(),
                .is_connected = current_slot > 0,
            };

            try networks.put(network_indexer.network_name, network_indexer);
            std.log.info("Initialized network {s} at slot {d}", .{ network_name, current_slot });
        }

        return Self{
            .allocator = allocator,
            .config = config,
            .rpc_client = rpc_client,
            .db_client = db_client,
            .running = false,
            .networks = networks,
            .global_stats = .{},
            .stats_callback = null,
            .stats_ctx = null,
            .logging_only = logging_only,
        };
    }

    pub fn deinit(self: *Self) void {
        self.running = false;
        self.rpc_client.deinit();
        self.db_client.deinit();
        
        // Cleanup networks
        var iterator = self.networks.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.network_name);
            if (entry.value_ptr.*.subscription_id) |sub_id| {
                self.allocator.free(sub_id);
            }
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.networks.deinit();

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
                
                // Update stats for each network
                var iterator = self.networks.iterator();
                while (iterator.next()) |entry| {
                    const network = entry.value_ptr.*;
                    callback(ctx, network.network_name, network.current_slot, network.stats.blocks_processed, rpc_ok, db_ok);
                }
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
        std.log.info("Starting historical indexer for {d} networks ({s})", .{ self.networks.count(), if (self.logging_only) "logging-only mode" else "full indexing mode" });

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const batch_size = self.config.batch_size;

        // Process each network concurrently
        var threads = std.ArrayList(std.Thread).init(self.allocator);
        defer {
            for (threads.items) |thread| {
                thread.join();
            }
            threads.deinit();
        }

        var iterator = self.networks.iterator();
        while (iterator.next()) |entry| {
            const network = entry.value_ptr.*;
            
            const thread = try std.Thread.spawn(.{}, struct {
                fn processNetwork(indexer: *Self, net: *NetworkIndexer, batch_sz: u32) !void {
                    var current_batch = indexer.allocator.alloc(u64, batch_sz) catch return;
                    defer indexer.allocator.free(current_batch);

                    while (indexer.running and net.current_slot > net.target_slot) {
                        // Fill batch with slot numbers
                        var i: usize = 0;
                        while (i < batch_sz and net.current_slot > net.target_slot) : (i += 1) {
                            current_batch[i] = net.current_slot;
                            net.current_slot -= 1;
                        }

                        indexer.processBatchForNetwork(net.network_name, current_batch[0..i]) catch |err| {
                            std.log.err("Failed to process batch for network {s}: {any}", .{ net.network_name, err });
                            continue;
                        };
                        
                        net.stats.blocks_processed += i;
                        indexer.updateGlobalStats();

                        // Log network-specific stats
                        std.log.info("Network {s} - Batch Stats: {d} slots, {d} txs ({d} success, {d} fail)", .{ 
                            net.network_name, i, net.stats.total_transactions, net.stats.successful_txs, net.stats.failed_txs });
                    }
                }
            }.processNetwork, .{ self, network, batch_size });
            
            try threads.append(thread);
        }

        // Wait for all threads to complete
        for (threads.items) |thread| {
            thread.join();
        }
    }

    fn updateGlobalStats(self: *Self) void {
        // Reset global stats
        self.global_stats = .{};
        
        // Sum up stats from all networks
        var iterator = self.networks.iterator();
        while (iterator.next()) |entry| {
            const network = entry.value_ptr.*;
            self.global_stats.total_transactions += network.stats.total_transactions;
            self.global_stats.total_instructions += network.stats.total_instructions;
            self.global_stats.total_accounts_updated += network.stats.total_accounts_updated;
            self.global_stats.successful_txs += network.stats.successful_txs;
            self.global_stats.failed_txs += network.stats.failed_txs;
            self.global_stats.total_compute_units += network.stats.total_compute_units;
            self.global_stats.total_fees += network.stats.total_fees;
            self.global_stats.token_transfers += network.stats.token_transfers;
            self.global_stats.token_mints += network.stats.token_mints;
            self.global_stats.token_burns += network.stats.token_burns;
            self.global_stats.nft_mints += network.stats.nft_mints;
            self.global_stats.nft_sales += network.stats.nft_sales;
            self.global_stats.amm_swaps += network.stats.amm_swaps;
            self.global_stats.defi_events += network.stats.defi_events;
            self.global_stats.security_events += network.stats.security_events;
            self.global_stats.blocks_processed += network.stats.blocks_processed;
        }
        
        self.updateStats();
    }

    fn processBatchForNetwork(self: *Self, network_name: []const u8, slots: []const u64) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        // Process blocks sequentially for now to avoid memory issues
        for (slots) |slot| {
            self.processSlotForNetwork(network_name, slot) catch |err| {
                std.log.err("Failed to process slot {d} for network {s}: {any}", .{ slot, network_name, err });
                continue;
            };
        }
    }

    fn processSlotForNetwork(self: *Self, network_name: []const u8, slot: u64) !void {
        // Get network
        const network = self.networks.get(network_name) orelse return error.NetworkNotFound;
        
        std.log.info("Processing slot {d} for network {s}", .{ slot, network_name });

        // Verify database connection periodically (every 100 slots)
        if (!self.logging_only and slot % 100 == 0) {
            self.db_client.verifyConnection() catch |err| {
                std.log.err("Lost connection to database: {any}", .{err});
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
            block_json = self.rpc_client.getBlock(network_name, slot) catch |err| {
                std.log.warn("Failed to fetch block {d} for network {s} (attempt {d}/{d}): {any}", .{ slot, network_name, retries + 1, self.config.max_retries, err });
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

        // Process block-level data (NEW: Full block indexing)
        if (!self.logging_only) {
            try self.processBlockData(network_name, slot, block);
        }

        // Track slot-level stats
        var slot_stats = ProcessingStats{};

        // Process transactions with full analysis
        for (block.transactions) |tx_json| {
            try self.processTransactionFull(network_name, slot, block.block_time orelse 0, tx_json, &slot_stats);
        }

        // Update network stats
        network.stats.total_transactions += slot_stats.total_transactions;
        network.stats.total_instructions += slot_stats.total_instructions;
        network.stats.total_accounts_updated += slot_stats.total_accounts_updated;
        network.stats.successful_txs += slot_stats.successful_txs;
        network.stats.failed_txs += slot_stats.failed_txs;
        network.stats.total_compute_units += slot_stats.total_compute_units;
        network.stats.total_fees += slot_stats.total_fees;
        network.stats.token_transfers += slot_stats.token_transfers;
        network.stats.token_mints += slot_stats.token_mints;
        network.stats.token_burns += slot_stats.token_burns;
        network.stats.nft_mints += slot_stats.nft_mints;
        network.stats.nft_sales += slot_stats.nft_sales;
        network.stats.amm_swaps += slot_stats.amm_swaps;
        network.stats.defi_events += slot_stats.defi_events;
        network.stats.security_events += slot_stats.security_events;

        network.current_slot = slot;
        network.last_processed_time = std.time.timestamp();

        std.log.info("Processed slot {d} for network {s} - Stats: {d} txs ({d} success, {d} fail), {d} tokens, {d} NFTs, {d} swaps", .{ 
            slot, network_name, slot_stats.total_transactions, slot_stats.successful_txs, slot_stats.failed_txs, 
            slot_stats.token_transfers, slot_stats.nft_mints, slot_stats.amm_swaps });
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

                // Get initial slot after struct is fully initialized (use default network)
                ctx.last_slot = indexer.rpc_client.getSlot(indexer.config.default_network) catch |err| {
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

        // Subscribe to slot updates for all networks
        var network_iterator = self.networks.iterator();
        while (network_iterator.next()) |entry| {
            const network_name = entry.key_ptr.*;
            self.rpc_client.subscribeSlots(network_name, ctx, struct {
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

                // Process slot with error handling - use default network for now
                indexer.processSlotForNetwork(indexer.config.default_network, slot) catch |err| {
                    std.log.err("Failed to process slot {d}: {any}", .{ slot, err });
                    return;
                };

                // Update global stats
                indexer.updateGlobalStats();
                context.last_slot = slot;
            }
        }.callback) catch |err| {
            std.log.err("Failed to subscribe to slots for network {s}: {any}", .{ network_name, err });
            continue;
        };
        }

        std.log.info("Subscribed to slot updates for all networks", .{});

        // Keep running until stopped
        while (self.running) {
            std.time.sleep(1 * std.time.ns_per_s);
            // Log detailed stats every second using global stats
            std.log.info("Indexer Stats: {d} blocks, {d} txs ({d} success, {d} fail), {d} tokens, {d} NFTs, {d} swaps", .{ 
                self.global_stats.blocks_processed, self.global_stats.total_transactions, self.global_stats.successful_txs, 
                self.global_stats.failed_txs, self.global_stats.token_transfers, self.global_stats.nft_mints, self.global_stats.amm_swaps });
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

    // NEW: Full block processing including block-level data
    fn processBlockData(self: *Self, network_name: []const u8, slot: u64, block: dependencies.rpc.BlockInfo) !void {
        if (self.logging_only) return;

        // Insert block data
        try self.db_client.insertBlock(.{
            .network = network_name,
            .slot = slot,
            .block_time = block.block_time orelse 0,
            .block_hash = block.blockhash,
            .parent_slot = block.parent_slot,
            .parent_hash = block.previous_blockhash,
            .block_height = block.block_height orelse 0,
            .transaction_count = @as(u32, @intCast(block.transactions.len)),
            .successful_transaction_count = 0, // Will be calculated
            .failed_transaction_count = 0, // Will be calculated
            .total_fee = 0, // Will be calculated
            .total_compute_units = 0, // Will be calculated
            .rewards = &[_]f64{}, // TODO: Extract rewards if available
        });

        // Calculate and update block statistics
        var successful_txs: u32 = 0;
        var failed_txs: u32 = 0;
        var total_fee: u64 = 0;
        var total_cu: u64 = 0;

        for (block.transactions) |tx_json| {
            const tx = tx_json.object;
            const meta = tx.get("meta").?.object;
            
            if (meta.get("err") == null) {
                successful_txs += 1;
            } else {
                failed_txs += 1;
            }
            
            total_fee += @as(u64, @intCast(meta.get("fee").?.integer));
            if (meta.get("computeUnitsConsumed")) |cu| {
                total_cu += @as(u64, @intCast(cu.integer));
            }
        }

        // Update block with calculated statistics
        try self.db_client.updateBlockStats(.{
            .network = network_name,
            .slot = slot,
            .successful_transaction_count = successful_txs,
            .failed_transaction_count = failed_txs,
            .total_fee = total_fee,
            .total_compute_units = total_cu,
        });
    }

    // NEW: Full transaction processing with complete data extraction
    fn processTransactionFull(self: *Self, network_name: []const u8, slot: u64, block_time: i64, tx_json: json.Value, slot_stats: *ProcessingStats) !void {
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
            // Process basic transaction data
            transaction.processTransaction(self, slot, block_time, tx_json, network_name) catch |err| {
                std.log.err("Failed to process transaction in slot {d}: {any}", .{ slot, err });
            };

            // Process instructions
            instruction.processInstructions(self, slot, block_time, tx_json, network_name) catch |err| {
                std.log.err("Failed to process instructions in slot {d}: {any}", .{ slot, err });
            };

            // Process account updates
            account.processAccountUpdates(self, slot, block_time, tx_json, network_name) catch |err| {
                std.log.err("Failed to process account updates in slot {d}: {any}", .{ slot, err });
            };

            // NEW: Process token operations with full data extraction
            var token_account_count: u32 = 0;
            token.processTokenOperations(self, slot, block_time, tx_json, &slot_stats.token_transfers, &slot_stats.token_mints, &slot_stats.token_burns, &token_account_count) catch |err| {
                std.log.err("Failed to process token operations in slot {d}: {any}", .{ slot, err });
            };
            slot_stats.total_accounts_updated += token_account_count;

            // NEW: Process DeFi operations with real instruction parsing
            defi.processDefiOperations(self, slot, block_time, tx_json, &slot_stats.amm_swaps, &slot_stats.defi_events, &slot_stats.defi_events, &slot_stats.defi_events, &slot_stats.defi_events, &slot_stats.defi_events) catch |err| {
                std.log.err("Failed to process DeFi operations in slot {d}: {any}", .{ slot, err });
            };

            // NEW: Process NFT operations with metadata extraction
            nft.processNftOperations(self, slot, block_time, tx_json, &slot_stats.nft_mints, &slot_stats.nft_sales, &slot_stats.nft_sales, &slot_stats.nft_sales) catch |err| {
                std.log.err("Failed to process NFT operations in slot {d}: {any}", .{ slot, err });
            };

            // NEW: Process security events with enhanced detection
            security.processSecurityEvents(self, slot, block_time, tx_json, &slot_stats.security_events, &slot_stats.security_events, &slot_stats.total_accounts_updated) catch |err| {
                std.log.err("Failed to process security events in slot {d}: {any}", .{ slot, err });
            };
        }
    }
};
