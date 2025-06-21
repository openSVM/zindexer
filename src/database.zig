const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;

/// Enum representing the supported database types
pub const DatabaseType = enum {
    ClickHouse,
    QuestDB,
};

/// Common error type for database operations
pub const DatabaseError = error{
    QueryFailed,
    InvalidResponse,
    ConnectionFailed,
    DatabaseError,
    AuthenticationError,
    InvalidUrl,
    UnsupportedDatabaseType,
} || std.Uri.ParseError || std.fmt.AllocPrintError || std.mem.Allocator.Error;

/// Common data structures used by database clients
pub const Instruction = struct {
    network: []const u8,
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
    network: []const u8,
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
    network: []const u8,
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

/// Database client interface that all database implementations must follow
pub const DatabaseClient = struct {
    /// Pointer to the implementation's vtable
    vtable: *const VTable,
    
    /// Virtual method table for database operations
    pub const VTable = struct {
        deinitFn: *const fn (self: *anyopaque) void,
        executeQueryFn: *const fn (self: *anyopaque, query: []const u8) DatabaseError!void,
        verifyConnectionFn: *const fn (self: *anyopaque) DatabaseError!void,
        createTablesFn: *const fn (self: *anyopaque) DatabaseError!void,
        insertTransactionFn: *const fn (self: *anyopaque, tx: Transaction) DatabaseError!void,
        insertTransactionBatchFn: *const fn (self: *anyopaque, transactions: []const json.Value, network_name: []const u8) DatabaseError!void,
        insertProgramExecutionFn: *const fn (self: *anyopaque, pe: ProgramExecution) DatabaseError!void,
        insertAccountActivityFn: *const fn (self: *anyopaque, activity: AccountActivity) DatabaseError!void,
        insertInstructionFn: *const fn (self: *anyopaque, instruction: Instruction) DatabaseError!void,
        insertAccountFn: *const fn (self: *anyopaque, account: Account) DatabaseError!void,
        getDatabaseSizeFn: *const fn (self: *anyopaque) DatabaseError!usize,
        getTableSizeFn: *const fn (self: *anyopaque, table_name: []const u8) DatabaseError!usize,
    };
    
    /// Clean up resources
    pub fn deinit(self: *DatabaseClient) void {
        self.vtable.deinitFn(self.toAnyopaque());
    }
    
    /// Execute a query
    pub fn executeQuery(self: *DatabaseClient, query: []const u8) DatabaseError!void {
        return self.vtable.executeQueryFn(self.toAnyopaque(), query);
    }
    
    /// Verify connection to the database
    pub fn verifyConnection(self: *DatabaseClient) DatabaseError!void {
        return self.vtable.verifyConnectionFn(self.toAnyopaque());
    }
    
    /// Create database tables
    pub fn createTables(self: *DatabaseClient) DatabaseError!void {
        return self.vtable.createTablesFn(self.toAnyopaque());
    }
    
    /// Insert a single transaction
    pub fn insertTransaction(self: *DatabaseClient, tx: Transaction) DatabaseError!void {
        return self.vtable.insertTransactionFn(self.toAnyopaque(), tx);
    }
    
    /// Insert a batch of transactions
    pub fn insertTransactionBatch(self: *DatabaseClient, transactions: []const json.Value, network_name: []const u8) DatabaseError!void {
        return self.vtable.insertTransactionBatchFn(self.toAnyopaque(), transactions, network_name);
    }
    
    /// Insert a program execution record
    pub fn insertProgramExecution(self: *DatabaseClient, pe: ProgramExecution) DatabaseError!void {
        return self.vtable.insertProgramExecutionFn(self.toAnyopaque(), pe);
    }
    
    /// Insert an account activity record
    pub fn insertAccountActivity(self: *DatabaseClient, activity: AccountActivity) DatabaseError!void {
        return self.vtable.insertAccountActivityFn(self.toAnyopaque(), activity);
    }
    
    /// Insert an instruction record
    pub fn insertInstruction(self: *DatabaseClient, instruction: Instruction) DatabaseError!void {
        return self.vtable.insertInstructionFn(self.toAnyopaque(), instruction);
    }
    
    /// Insert an account record
    pub fn insertAccount(self: *DatabaseClient, account: Account) DatabaseError!void {
        return self.vtable.insertAccountFn(self.toAnyopaque(), account);
    }
    
    /// Get database size
    pub fn getDatabaseSize(self: *DatabaseClient) DatabaseError!usize {
        return self.vtable.getDatabaseSizeFn(self.toAnyopaque());
    }
    
    /// Get table size
    pub fn getTableSize(self: *DatabaseClient, table_name: []const u8) DatabaseError!usize {
        return self.vtable.getTableSizeFn(self.toAnyopaque(), table_name);
    }
    
    /// Convert to opaque pointer for vtable calls
    fn toAnyopaque(self: *DatabaseClient) *anyopaque {
        return @ptrCast(self);
    }
};

/// Factory function to create a database client based on the type
pub fn createDatabaseClient(
    allocator: Allocator,
    db_type: DatabaseType,
    url: []const u8,
    user: []const u8,
    password: []const u8,
    database: []const u8,
) DatabaseError!*DatabaseClient {
    switch (db_type) {
        .ClickHouse => {
            const ch = @import("clickhouse.zig");
            const client = try allocator.create(ch.ClickHouseClient);
            errdefer allocator.destroy(client);
            
            client.* = try ch.ClickHouseClient.init(allocator, url, user, password, database);
            return @ptrCast(client);
        },
        .QuestDB => {
            const qdb = @import("questdb.zig");
            const client = try allocator.create(qdb.QuestDBClient);
            errdefer allocator.destroy(client);
            
            client.* = try qdb.QuestDBClient.init(allocator, url, user, password, database);
            return @ptrCast(client);
        },
    }
}

/// Re-export the database clients
pub const clickhouse = @import("clickhouse.zig");
pub const questdb = @import("questdb.zig");