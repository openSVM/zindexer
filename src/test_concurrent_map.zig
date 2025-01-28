const std = @import("std");
const testing = std.testing;
const time = std.time;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;
const expect = testing.expect;

pub fn ConcurrentMap(comptime Key: type, comptime Value: type) type {
    return struct {
        const Self = @This();
        const Bucket = struct {
            entries: std.ArrayList(struct {
                key: Key,
                value: Value,
            }),
            mutex: Thread.Mutex,

            fn init(allocator: std.mem.Allocator) Bucket {
                const entries = std.ArrayList(struct {
                    key: Key,
                    value: Value,
                }).init(allocator);
                return .{
                    .entries = entries,
                    .mutex = .{},
                };
            }

            fn deinit(self: *Bucket) void {
                self.entries.deinit();
            }
        };

        buckets: []Bucket,
        allocator: std.mem.Allocator,
        size: Atomic(usize),

        pub fn init(allocator: std.mem.Allocator, num_buckets: usize) !Self {
            const buckets = try allocator.alloc(Bucket, num_buckets);
            for (buckets) |*bucket| {
                bucket.* = Bucket.init(allocator);
            }
            return Self{
                .buckets = buckets,
                .allocator = allocator,
                .size = Atomic(usize).init(0),
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.buckets) |*bucket| {
                bucket.deinit();
            }
            self.allocator.free(self.buckets);
        }

        pub fn put(self: *Self, key: Key, value: Value) !void {
            const index = std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
            const bucket_index = index % self.buckets.len;
            var bucket = &self.buckets[bucket_index];

            bucket.mutex.lock();
            defer bucket.mutex.unlock();

            // Update existing entry if key exists
            for (bucket.entries.items) |*entry| {
                if (entry.key == key) {
                    entry.value = value;
                    return;
                }
            }

            // Add new entry
            try bucket.entries.append(.{ .key = key, .value = value });
            _ = self.size.fetchAdd(1, .Monotonic);
        }

        pub fn get(self: *Self, key: Key) ?Value {
            const index = std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
            const bucket_index = index % self.buckets.len;
            var bucket = &self.buckets[bucket_index];

            bucket.mutex.lock();
            defer bucket.mutex.unlock();

            for (bucket.entries.items) |entry| {
                if (entry.key == key) {
                    return entry.value;
                }
            }
            return null;
        }

        pub fn remove(self: *Self, key: Key) bool {
            const index = std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
            const bucket_index = index % self.buckets.len;
            var bucket = &self.buckets[bucket_index];

            bucket.mutex.lock();
            defer bucket.mutex.unlock();

            for (bucket.entries.items, 0..) |entry, i| {
                if (entry.key == key) {
                    _ = bucket.entries.orderedRemove(i);
                    _ = self.size.fetchSub(1, .Monotonic);
                    return true;
                }
            }
            return false;
        }

        pub fn len(self: *Self) usize {
            return self.size.load(.Monotonic);
        }
    };
}

const WriterContext = struct {
    map: *ConcurrentMap(i32, i32),
    thread_id: usize,
    success_counter: *Atomic(usize),
    ops_count: usize,
};

fn writerThreadFn(ctx: *WriterContext) void {
    var count: usize = 0;
    while (count < ctx.ops_count) : (count += 1) {
        const key = @intCast(i32, ctx.thread_id * ctx.ops_count + count);
        if (ctx.map.put(key, key * 2)) |_| {
            if (ctx.map.get(key)) |value| {
                if (value == key * 2) {
                    _ = ctx.success_counter.fetchAdd(1, .Monotonic);
                }
            }
        } else |_| {}
    }
}

const ReaderContext = struct {
    map: *ConcurrentMap(i32, i32),
    ops_count: usize,
};

fn readerThreadFn(ctx: *ReaderContext) void {
    var count: usize = 0;
    while (count < ctx.ops_count) : (count += 1) {
        _ = ctx.map.get(1);
    }
}

test "ConcurrentMap - basic operations" {
    var map = try ConcurrentMap(i32, i32).init(testing.allocator, 8);
    defer map.deinit();

    // Test empty map
    try expect(map.len() == 0);
    try expect(map.get(1) == null);

    // Test put and get
    try map.put(1, 10);
    try expect(map.len() == 1);
    try expect(map.get(1).? == 10);

    // Test update
    try map.put(1, 20);
    try expect(map.len() == 1);
    try expect(map.get(1).? == 20);

    // Test remove
    try expect(map.remove(1));
    try expect(map.len() == 0);
    try expect(map.get(1) == null);
    try expect(!map.remove(1));
}

test "ConcurrentMap - concurrent reads and writes" {
    var map = try ConcurrentMap(i32, i32).init(testing.allocator, 8);
    defer map.deinit();

    const num_threads = 4;
    const ops_per_thread = 10000;
    var threads: [num_threads]Thread = undefined;
    var success_count = Atomic(usize).init(0);
    var contexts: [num_threads]WriterContext = undefined;

    // Spawn writer threads
    for (0..num_threads) |i| {
        contexts[i] = .{
            .map = &map,
            .thread_id = i,
            .success_counter = &success_count,
            .ops_count = ops_per_thread,
        };
        threads[i] = try Thread.spawn(writerThreadFn, contexts[i]);
    }

    // Wait for all threads
    for (threads) |thread| {
        thread.join();
    }

    // Verify results
    const total_ops = num_threads * ops_per_thread;
    try expect(success_count.load(.Monotonic) == total_ops);
    try expect(map.len() == total_ops);

    // Verify all values are correct
    var count: usize = 0;
    while (count < total_ops) : (count += 1) {
        const key = @intCast(i32, count);
        try expect(map.get(key).? == key * 2);
    }
}

test "ConcurrentMap - RPS benchmark" {
    var map = try ConcurrentMap(i32, i32).init(testing.allocator, 8);
    defer map.deinit();

    try map.put(1, 1);

    const num_threads = 4;
    const ops_per_thread = 100_000;
    var threads: [num_threads]Thread = undefined;
    var contexts: [num_threads]ReaderContext = undefined;

    const start = time.milliTimestamp();

    // Spawn reader threads
    for (0..num_threads) |i| {
        contexts[i] = .{
            .map = &map,
            .ops_count = ops_per_thread,
        };
        threads[i] = try Thread.spawn(readerThreadFn, contexts[i]);
    }

    // Wait for all threads
    for (threads) |thread| {
        thread.join();
    }

    const elapsed = time.milliTimestamp() - start;
    const total_ops = @as(f64, @floatFromInt(num_threads * ops_per_thread));
    const rps = total_ops / (@as(f64, @floatFromInt(elapsed)) / 1000.0);

    // Expect at least 1M operations per second
    try expect(rps > 1_000_000);
}
