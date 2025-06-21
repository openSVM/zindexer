const std = @import("std");
const Allocator = std.mem.Allocator;
const http_client = @import("http_client.zig");
const database = @import("../database.zig");

/// High-performance bulk insert manager for ClickHouse
pub const BulkInsertManager = struct {
    allocator: Allocator,
    client: *http_client.ClickHouseHttpClient,
    buffers: std.StringHashMap(BatchBuffer),
    flush_threshold: usize,
    auto_flush: bool,
    compression_enabled: bool,

    const Self = @This();

    const BatchBuffer = struct {
        table_name: []const u8,
        columns: []const []const u8,
        data: std.ArrayList([]const u8),
        csv_mode: bool,
        
        fn init(allocator: Allocator, table_name: []const u8, columns: []const []const u8, csv_mode: bool) BatchBuffer {
            return BatchBuffer{
                .table_name = table_name,
                .columns = columns,
                .data = std.ArrayList([]const u8).init(allocator),
                .csv_mode = csv_mode,
            };
        }
        
        fn deinit(self: *BatchBuffer, allocator: Allocator) void {
            for (self.data.items) |item| {
                allocator.free(item);
            }
            self.data.deinit();
            allocator.free(self.table_name);
            for (self.columns) |col| {
                allocator.free(col);
            }
            allocator.free(self.columns);
        }
    };

    pub fn init(
        allocator: Allocator, 
        client: *http_client.ClickHouseHttpClient,
        flush_threshold: usize,
        auto_flush: bool
    ) Self {
        return Self{
            .allocator = allocator,
            .client = client,
            .buffers = std.StringHashMap(BatchBuffer).init(allocator),
            .flush_threshold = flush_threshold,
            .auto_flush = auto_flush,
            .compression_enabled = true,
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.buffers.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.buffers.deinit();
    }

    /// Add a transaction to the batch
    pub fn addTransaction(self: *Self, tx: database.Transaction) !void {
        const table_name = "transactions";
        
        // Prepare CSV row for maximum performance
        const csv_row = try std.fmt.allocPrint(self.allocator,
            \\"{s}","{s}",{d},{d},{d},{d},{d},{d},"{s}","{s}","{s}","{s}","{s}","{s}","{s}","{s}","{s}"
        , .{
            tx.network, tx.signature, tx.slot, tx.block_time, 
            @as(u8, if (tx.success) 1 else 0), tx.fee, 
            tx.compute_units_consumed, tx.compute_units_price,
            tx.recent_blockhash,
            "", // program_ids (JSON array)
            "", // signers (JSON array) 
            "", // account_keys (JSON array)
            "", // pre_balances (JSON array)
            "", // post_balances (JSON array)
            "", // pre_token_balances (JSON)
            "", // post_token_balances (JSON)
            tx.error_msg orelse ""
        });

        try self.addToBuffer(table_name, csv_row, true);
    }

    /// Add a block to the batch
    pub fn addBlock(self: *Self, block: database.Block) !void {
        const table_name = "blocks";
        
        const csv_row = try std.fmt.allocPrint(self.allocator,
            \\"{s}",{d},{d},"{s}",{d},"{s}",{d},{d},{d},{d},{d},{d}
        , .{
            block.network, block.slot, block.block_time, block.block_hash,
            block.parent_slot, block.parent_hash, block.block_height,
            block.transaction_count, block.successful_transaction_count,
            block.failed_transaction_count, block.total_fee, block.total_compute_units
        });

        try self.addToBuffer(table_name, csv_row, true);
    }

    /// Add token transfer to batch
    pub fn addTokenTransfer(self: *Self, transfer: database.TokenTransfer) !void {
        const table_name = "token_transfers";
        
        const csv_row = try std.fmt.allocPrint(self.allocator,
            \\"{s}",{d},{d},"{s}","{s}","{s}",{d},{d},"{s}","{s}"
        , .{
            transfer.signature, transfer.slot, transfer.block_time,
            transfer.mint_address, transfer.from_account, transfer.to_account,
            transfer.amount, 0, // decimals placeholder
            "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA", // program_id placeholder
            transfer.instruction_type
        });

        try self.addToBuffer(table_name, csv_row, true);
    }

    /// Add pool swap to batch
    pub fn addPoolSwap(self: *Self, swap: database.PoolSwap) !void {
        const table_name = "pool_swaps";
        
        const csv_row = try std.fmt.allocPrint(self.allocator,
            \\"{s}",{d},{d},"{s}","{s}","{s}","{s}",{d},{d},{d},{d},{d},"{s}"
        , .{
            "", // signature placeholder
            0, // slot placeholder  
            0, // block_time placeholder
            swap.pool_address, swap.user_account,
            swap.token_in_mint, swap.token_out_mint,
            swap.token_in_amount, swap.token_out_amount,
            0, // token_in_price_usd placeholder
            0, // token_out_price_usd placeholder  
            0, // fee_amount placeholder
            "" // program_id placeholder
        });

        try self.addToBuffer(table_name, csv_row, true);
    }

    /// Add NFT mint to batch
    pub fn addNftMint(self: *Self, mint: database.NftMint) !void {
        const table_name = "nft_mints";
        
        const csv_row = try std.fmt.allocPrint(self.allocator,
            \\"{s}",{d},{d},"{s}","{s}","{s}","{s}","{s}","{s}","{s}",{d}
        , .{
            mint.mint_address, 0, 0, // slot, block_time placeholders
            mint.collection_address orelse "",
            mint.owner, mint.creator orelse "",
            mint.name orelse "", mint.symbol orelse "", 
            mint.uri orelse "", mint.metadata_uri orelse "",
            @as(u8, if (mint.verified) 1 else 0)
        });

        try self.addToBuffer(table_name, csv_row, true);
    }

    /// Add security event to batch  
    pub fn addSecurityEvent(self: *Self, event: database.SecurityEvent) !void {
        const table_name = "security_events";
        
        const csv_row = try std.fmt.allocPrint(self.allocator,
            \\"{s}",{d},{d},"{s}","{s}","{s}","{s}","{s}",{d}
        , .{
            "", // signature placeholder
            0, 0, // slot, block_time placeholders
            event.event_type, event.account_address orelse "",
            event.program_id orelse "", event.severity,
            event.description orelse "", 
            @as(u8, if (event.verified) 1 else 0)
        });

        try self.addToBuffer(table_name, csv_row, true);
    }

    /// Generic method to add data to buffer
    fn addToBuffer(self: *Self, table_name: []const u8, data: []const u8, csv_mode: bool) !void {
        const result = try self.buffers.getOrPut(table_name);
        
        if (!result.found_existing) {
            // Initialize new buffer
            const columns = try self.getTableColumns(table_name);
            const table_name_copy = try self.allocator.dupe(u8, table_name);
            result.value_ptr.* = BatchBuffer.init(self.allocator, table_name_copy, columns, csv_mode);
        }

        try result.value_ptr.data.append(try self.allocator.dupe(u8, data));

        // Auto-flush if threshold reached
        if (self.auto_flush and result.value_ptr.data.items.len >= self.flush_threshold) {
            try self.flushTable(table_name);
        }
    }

    /// Flush a specific table's buffer
    pub fn flushTable(self: *Self, table_name: []const u8) !void {
        if (self.buffers.get(table_name)) |buffer| {
            if (buffer.data.items.len == 0) return;

            if (buffer.csv_mode) {
                // Use CSV format for maximum performance
                var csv_data = std.ArrayList(u8).init(self.allocator);
                defer csv_data.deinit();

                for (buffer.data.items) |row| {
                    try csv_data.appendSlice(row);
                    try csv_data.append('\n');
                }

                try self.client.bulkInsertCSV(table_name, csv_data.items);
            } else {
                // Use regular bulk insert
                var rows = std.ArrayList([]const []const u8).init(self.allocator);
                defer {
                    for (rows.items) |row| {
                        self.allocator.free(row);
                    }
                    rows.deinit();
                }

                for (buffer.data.items) |_| {
                    // Parse row_data into columns (simplified)
                    const row = try self.allocator.alloc([]const u8, buffer.columns.len);
                    // TODO: Implement proper parsing
                    try rows.append(row);
                }

                try self.client.bulkInsert(table_name, buffer.columns, rows.items);
            }

            // Clear buffer after successful flush
            var buf_ptr = self.buffers.getPtr(table_name).?;
            for (buf_ptr.data.items) |item| {
                self.allocator.free(item);
            }
            buf_ptr.data.clearRetainingCapacity();

            std.log.info("Flushed {d} rows to table {s}", .{ buffer.data.items.len, table_name });
        }
    }

    /// Flush all buffers
    pub fn flushAll(self: *Self) !void {
        var iterator = self.buffers.iterator();
        while (iterator.next()) |entry| {
            try self.flushTable(entry.key_ptr.*);
        }
    }

    /// Get column definitions for a table
    fn getTableColumns(self: *Self, table_name: []const u8) ![]const []const u8 {
        // Table column mappings - could be moved to config
        if (std.mem.eql(u8, table_name, "transactions")) {
            const columns = try self.allocator.alloc([]const u8, 17);
            columns[0] = try self.allocator.dupe(u8, "network");
            columns[1] = try self.allocator.dupe(u8, "signature");
            columns[2] = try self.allocator.dupe(u8, "slot");
            columns[3] = try self.allocator.dupe(u8, "block_time");
            columns[4] = try self.allocator.dupe(u8, "success");
            columns[5] = try self.allocator.dupe(u8, "fee");
            columns[6] = try self.allocator.dupe(u8, "compute_units_consumed");
            columns[7] = try self.allocator.dupe(u8, "compute_units_price");
            columns[8] = try self.allocator.dupe(u8, "recent_blockhash");
            columns[9] = try self.allocator.dupe(u8, "program_ids");
            columns[10] = try self.allocator.dupe(u8, "signers");
            columns[11] = try self.allocator.dupe(u8, "account_keys");
            columns[12] = try self.allocator.dupe(u8, "pre_balances");
            columns[13] = try self.allocator.dupe(u8, "post_balances");
            columns[14] = try self.allocator.dupe(u8, "pre_token_balances");
            columns[15] = try self.allocator.dupe(u8, "post_token_balances");
            columns[16] = try self.allocator.dupe(u8, "error");
            return columns;
        } else if (std.mem.eql(u8, table_name, "blocks")) {
            const columns = try self.allocator.alloc([]const u8, 12);
            columns[0] = try self.allocator.dupe(u8, "network");
            columns[1] = try self.allocator.dupe(u8, "slot");
            columns[2] = try self.allocator.dupe(u8, "block_time");
            columns[3] = try self.allocator.dupe(u8, "block_hash");
            columns[4] = try self.allocator.dupe(u8, "parent_slot");
            columns[5] = try self.allocator.dupe(u8, "parent_hash");
            columns[6] = try self.allocator.dupe(u8, "block_height");
            columns[7] = try self.allocator.dupe(u8, "transaction_count");
            columns[8] = try self.allocator.dupe(u8, "successful_transaction_count");
            columns[9] = try self.allocator.dupe(u8, "failed_transaction_count");
            columns[10] = try self.allocator.dupe(u8, "total_fee");
            columns[11] = try self.allocator.dupe(u8, "total_compute_units");
            return columns;
        }
        // Add more table mappings as needed
        
        return try self.allocator.alloc([]const u8, 0);
    }

    /// Get buffer statistics
    pub fn getBufferStats(self: *Self) BufferStats {
        var total_rows: usize = 0;
        var table_count: u32 = 0;
        
        var iterator = self.buffers.iterator();
        while (iterator.next()) |entry| {
            total_rows += entry.value_ptr.data.items.len;
            table_count += 1;
        }
        
        return BufferStats{
            .total_buffered_rows = total_rows,
            .table_count = table_count,
        };
    }
};

pub const BufferStats = struct {
    total_buffered_rows: usize,
    table_count: u32,
};