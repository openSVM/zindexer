const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

pub fn insertInstruction(self: anytype, data: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    
    // Convert accounts array to JSON
    const accounts_json = try types.arrayToJson(arena.allocator(), data.accounts);
    
    // Convert parsed data to JSON string
    var parsed_data = std.ArrayList(u8).init(arena.allocator());
    defer parsed_data.deinit();
    try std.json.stringify(data.parsed_data, .{}, parsed_data.writer());
    
    // Format inner instruction index
    var inner_idx_buf = std.ArrayList(u8).init(arena.allocator());
    defer inner_idx_buf.deinit();
    
    const writer = inner_idx_buf.writer();
    if (@TypeOf(data.inner_instruction_index) == ?u32) {
        if (data.inner_instruction_index) |idx| {
            try std.fmt.format(writer, "{}", .{idx});
        } else {
            try writer.writeAll("null");
        }
    } else {
        try std.fmt.format(writer, "{}", .{data.inner_instruction_index});
    }
    
    const query = try std.fmt.allocPrint(arena.allocator(),
        \\INSERT INTO instructions
        \\VALUES ('{s}', {}, {}, '{s}', {}, {s}, '{s}', '{s}', '{s}')
    , .{
        data.signature, data.slot, data.block_time,
        data.program_id, data.instruction_index,
        inner_idx_buf.items,
        data.instruction_type, parsed_data.items,
        accounts_json,
    });
    
    try self.executeQuery(query);
}
