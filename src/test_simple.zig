const std = @import("std");
const testing = std.testing;

// A simple test that will always pass in CI
test "simple test passes in CI" {
    try testing.expect(true);
}

// A simple computation test
test "basic arithmetic" {
    const x: i32 = 42;
    const y: i32 = 27;
    try testing.expectEqual(x + y, 69);
    try testing.expectEqual(x - y, 15);
    try testing.expectEqual(x * y, 1134);
}

// Memory management test
test "memory operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    try list.append(10);
    try list.append(20);
    try list.append(30);

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqual(@as(u8, 10), list.items[0]);
    try testing.expectEqual(@as(u8, 20), list.items[1]);
    try testing.expectEqual(@as(u8, 30), list.items[2]);
}
