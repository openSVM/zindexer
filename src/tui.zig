const std = @import("std");
const Allocator = std.mem.Allocator;

pub const IndexerUI = struct {
    allocator: Allocator,
    network_stats: std.StringHashMap(NetworkStats),
    should_stop: bool,
    mutex: std.Thread.Mutex,

    pub const NetworkStats = struct {
        network_name: []const u8,
        current_slot: u64,
        total_slots_processed: u64,
        rpc_ok: bool,
        db_ok: bool,
        last_update: i64,
    };

    pub fn init(allocator: Allocator) !*IndexerUI {
        const ui = try allocator.create(IndexerUI);
        ui.* = .{
            .allocator = allocator,
            .network_stats = std.StringHashMap(NetworkStats).init(allocator),
            .should_stop = false,
            .mutex = std.Thread.Mutex{},
        };
        return ui;
    }

    pub fn deinit(self: *IndexerUI) void {
        var it = self.network_stats.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.network_name);
        }
        self.network_stats.deinit();
        self.allocator.destroy(self);
    }

    pub fn updateStats(self: *IndexerUI, network_name: []const u8, current_slot: u64, total_slots: u64, rpc_ok: bool, db_ok: bool) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if network exists in map
        if (self.network_stats.get(network_name)) |*stats| {
            // Update existing stats
            stats.*.current_slot = current_slot;
            stats.*.total_slots_processed = total_slots;
            stats.*.rpc_ok = rpc_ok;
            stats.*.db_ok = db_ok;
            stats.*.last_update = std.time.timestamp();
        } else {
            // Create new stats entry
            const name_copy = self.allocator.dupe(u8, network_name) catch return;
            const new_stats = NetworkStats{
                .network_name = name_copy,
                .current_slot = current_slot,
                .total_slots_processed = total_slots,
                .rpc_ok = rpc_ok,
                .db_ok = db_ok,
                .last_update = std.time.timestamp(),
            };
            self.network_stats.put(network_name, new_stats) catch {
                self.allocator.free(name_copy);
                return;
            };
        }
    }

    pub fn run(self: *IndexerUI) !void {
        // Clear screen
        try std.io.getStdOut().writer().writeAll("\x1B[2J\x1B[H");

        while (!self.should_stop) {
            // Lock mutex to safely access stats
            self.mutex.lock();
            
            // Clear screen and move cursor to top
            try std.io.getStdOut().writer().writeAll("\x1B[2J\x1B[H");
            
            // Print header
            try std.io.getStdOut().writer().writeAll(
                \\╔════════════════════════════════════════════════════════════════════════════════╗
                \\║                                 ZINDEXER STATUS                                 ║
                \\╚════════════════════════════════════════════════════════════════════════════════╝
                \\
            );
            
            // Print network stats
            var it = self.network_stats.iterator();
            var network_count: usize = 0;
            
            while (it.next()) |entry| {
                const stats = entry.value_ptr.*;
                network_count += 1;
                
                // Format status indicators
                const rpc_status = if (stats.rpc_ok) "\x1B[32m✓\x1B[0m" else "\x1B[31m✗\x1B[0m";
                const db_status = if (stats.db_ok) "\x1B[32m✓\x1B[0m" else "\x1B[31m✗\x1B[0m";
                
                // Calculate time since last update
                const now = std.time.timestamp();
                const seconds_since_update = now - stats.last_update;
                
                try std.io.getStdOut().writer().print(
                    \\Network: {s}
                    \\  Current Slot: {d}
                    \\  Processed Slots: {d}
                    \\  RPC Status: {s}  DB Status: {s}
                    \\  Last Update: {d} seconds ago
                    \\
                , .{
                    stats.network_name,
                    stats.current_slot,
                    stats.total_slots_processed,
                    rpc_status,
                    db_status,
                    seconds_since_update,
                });
            }
            
            if (network_count == 0) {
                try std.io.getStdOut().writer().writeAll("No networks connected yet...\n");
            }
            
            // Print footer
            try std.io.getStdOut().writer().writeAll(
                \\╔════════════════════════════════════════════════════════════════════════════════╗
                \\║ Press Ctrl+C to exit                                                           ║
                \\╚════════════════════════════════════════════════════════════════════════════════╝
                \\
            );
            
            // Unlock mutex
            self.mutex.unlock();
            
            // Sleep for a short time
            std.time.sleep(500 * std.time.ns_per_ms);
        }
    }

    pub fn stop(self: *IndexerUI) void {
        self.should_stop = true;
    }
};