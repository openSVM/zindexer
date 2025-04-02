const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const json = std.json;
const database = @import("database.zig");

pub const ClickHouseError = error{
    QueryFailed,
    InvalidResponse,
    ConnectionFailed,
    DatabaseError,
    AuthenticationError,
    InvalidUrl,
} || std.Uri.ParseError || std.fmt.AllocPrintError || std.mem.Allocator.Error;

// Re-export the common data structures from the database module
pub const Instruction = database.Instruction;
pub const Account = database.Account;
pub const AccountUpdate = database.AccountUpdate;
pub const Transaction = database.Transaction;
pub const ProgramExecution = database.ProgramExecution;
pub const AccountActivity = database.AccountActivity;

pub const ClickHouseClient = @import("clickhouse/client.zig").ClickHouseClient;
