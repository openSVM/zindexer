const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const json = std.json;

pub const QuestDBError = error{
    QueryFailed,
    InvalidResponse,
    ConnectionFailed,
    DatabaseError,
    AuthenticationError,
    InvalidUrl,
} || std.Uri.ParseError || std.fmt.AllocPrintError || std.mem.Allocator.Error;

// Re-export the same data structures as in clickhouse.zig for compatibility
pub const Instruction = @import("database.zig").Instruction;
pub const Account = @import("database.zig").Account;
pub const AccountUpdate = @import("database.zig").AccountUpdate;
pub const Transaction = @import("database.zig").Transaction;
pub const ProgramExecution = @import("database.zig").ProgramExecution;
pub const AccountActivity = @import("database.zig").AccountActivity;

// Re-export the QuestDB client implementation
pub const QuestDBClient = @import("questdb/client.zig").QuestDBClient;