const std = @import("std");
const Allocator = std.mem.Allocator;
const time = std.time;
const process = std.process;
const fmt = std.fmt;

pub const Stats = struct {
    current_slot: u64,
    start_time: i64,
    total_slots: u64,
    memory_usage: usize,
    rpc_status: bool,
    db_status: bool,
};

pub const Tui = struct {
    stats: Stats,
    allocator: Allocator,
    last_update: i64,
    timer: std.time.Timer,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .stats = .{
                .current_slot = 0,
                .start_time = std.time.milliTimestamp(),
                .total_slots = 0,
                .memory_usage = 0,
                .rpc_status = false,
                .db_status = false,
            },
            .allocator = allocator,
            .last_update = std.time.milliTimestamp(),
            .timer = try std.time.Timer.start(),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn updateStats(self: *Self, new_stats: Stats) void {
        self.stats = new_stats;
    }

    pub fn render(self: *Self) !void {
        // Only update every 500ms to reduce output frequency
        const now = std.time.milliTimestamp();
        if (now - self.last_update < 500) {
            return;
        }
        self.last_update = now;

        // Calculate stats
        const elapsed_secs = @as(f64, @floatFromInt(now - self.stats.start_time)) / 1000.0;
        const slots_per_sec = if (elapsed_secs > 0)
            @as(f64, @floatFromInt(self.stats.total_slots)) / elapsed_secs
        else
            0;

        // Format memory usage
        var mem_str: []const u8 = undefined;
        const mb = @as(f64, @floatFromInt(self.stats.memory_usage)) / (1024.0 * 1024.0);
        mem_str = try fmt.allocPrint(self.allocator, "{d:.2} MB", .{mb});
        defer self.allocator.free(mem_str);

        // Simple ASCII output instead of Unicode box characters
        try std.io.getStdOut().writer().print(
            \\ 
            \\=== Solana Indexer Status ===
            \\Current Slot: {d}
            \\Slots/sec: {d:.2}/s
            \\Memory: {s}
            \\RPC Status: {s}
            \\DB Status: {s}
            \\
            \\
        , .{
            self.stats.current_slot,
            slots_per_sec,
            mem_str,
            if (self.stats.rpc_status) "Connected" else "Disconnected",
            if (self.stats.db_status) "Connected" else "Disconnected",
        });

        // Ensure output is flushed
        try std.io.getStdOut().writer().writeAll("\n");
    }

    pub fn onStatsUpdate(ctx: *anyopaque, current_slot: u64, total_slots: u64, rpc_ok: bool, db_ok: bool) void {
        const self = @as(*Self, @alignCast(@ptrCast(ctx)));
        self.updateStats(.{
            .current_slot = current_slot,
            .start_time = self.stats.start_time,
            .total_slots = total_slots,
            .memory_usage = 0, // TODO: Add memory tracking
            .rpc_status = rpc_ok,
            .db_status = db_ok,
        });
        self.render() catch |err| {
            std.log.err("Failed to render TUI: {}", .{err});
        };
    }
};
