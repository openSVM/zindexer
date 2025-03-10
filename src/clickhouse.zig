const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const json = std.json;

pub const ClickHouseError = error{
    QueryFailed,
    InvalidResponse,
    ConnectionFailed,
    DatabaseError,
    AuthenticationError,
    InvalidUrl,
} || std.Uri.ParseError || std.fmt.AllocPrintError || std.mem.Allocator.Error;

pub const Instruction = struct {
    signature: []const u8,
    slot: u64,
    block_time: i64,
    program_id: []const u8,
    instruction_index: u32,
    inner_instruction_index: ?u32,
    instruction_type: []const u8,
    parsed_data: []const u8,
    accounts: []const []const u8,
};

pub const Account = struct {
    pubkey: []const u8,
    slot: u64,
    block_time: i64,
    owner: []const u8,
    lamports: u64,
    executable: u8,
    rent_epoch: u64,
    data_len: u64,
    write_version: u64,
};

pub const AccountUpdate = struct {
    pubkey: []const u8,
    slot: u64,
    block_time: i64,
    owner: []const u8,
    lamports: u64,
    executable: u8,
    rent_epoch: u64,
    data_len: u64,
    write_version: u64,
};

pub const Transaction = struct {
    signature: []const u8,
    slot: u64,
    block_time: i64,
    success: bool,
    fee: u64,
    compute_units_consumed: u64,
    compute_units_price: u64,
    recent_blockhash: []const u8,
    program_ids: []const []const u8,
    signers: []const []const u8,
    account_keys: []const []const u8,
    pre_balances: []const json.Value,
    post_balances: []const json.Value,
    pre_token_balances: []const u8,
    post_token_balances: []const u8,
    log_messages: []const []const u8,
    error_msg: ?[]const u8,
};

pub const ProgramExecution = struct {
    program_id: []const u8,
    slot: u64,
    block_time: i64,
    execution_count: u32,
    total_cu_consumed: u64,
    total_fee: u64,
    success_count: u32,
    error_count: u32,
};

pub const AccountActivity = struct {
    network: []const u8,
    pubkey: []const u8,
    slot: u64,
    block_time: i64,
    program_id: []const u8,
    write_count: u32,
    cu_consumed: u64,
    fee_paid: u64,
};

pub const ClickHouseClient = @import("clickhouse/client.zig").ClickHouseClient;