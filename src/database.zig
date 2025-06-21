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
    network: []const u8,
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

pub const Block = struct {
    network: []const u8,
    slot: u64,
    block_time: i64,
    block_hash: []const u8,
    parent_slot: u64,
    parent_hash: []const u8,
    block_height: u64,
    transaction_count: u32,
    successful_transaction_count: u32,
    failed_transaction_count: u32,
    total_fee: u64,
    total_compute_units: u64,
    rewards: []const f64,
};

pub const BlockStats = struct {
    network: []const u8,
    slot: u64,
    successful_transaction_count: u32,
    failed_transaction_count: u32,
    total_fee: u64,
    total_compute_units: u64,
};

// Token-related structures
pub const TokenAccount = struct {
    account_address: []const u8,
    mint_address: []const u8,
    slot: u64,
    block_time: i64,
    owner: []const u8,
    amount: u64,
    delegate: ?[]const u8,
    delegated_amount: u64,
    is_initialized: u8,
    is_frozen: u8,
    is_native: u8,
    rent_exempt_reserve: ?u64,
    close_authority: ?[]const u8,
};

pub const TokenTransfer = struct {
    signature: []const u8,
    slot: u64,
    block_time: i64,
    mint_address: []const u8,
    from_account: []const u8,
    to_account: []const u8,
    amount: u64,
    decimals: u8,
    program_id: []const u8,
    instruction_type: []const u8,
};

pub const TokenHolder = struct {
    mint_address: []const u8,
    slot: u64,
    block_time: i64,
    owner: []const u8,
    balance: u64,
    balance_usd: f64,
};

pub const TokenAnalytics = struct {
    mint_address: []const u8,
    slot: u64,
    block_time: i64,
    transfer_count: u32,
    unique_holders: u32,
    active_accounts: u32,
    total_volume_usd: f64,
    avg_transaction_size: f64,
};

pub const TokenProgramActivity = struct {
    program_id: []const u8,
    slot: u64,
    block_time: i64,
    instruction_type: []const u8,
    execution_count: u32,
    error_count: u32,
    unique_users: u32,
    unique_tokens: u32,
};

// NFT-related structures
pub const NftCollection = struct {
    collection_address: []const u8,
    slot: u64,
    block_time: i64,
    name: []const u8,
    symbol: []const u8,
    creator_address: []const u8,
    verified: u8,
    total_supply: u32,
    holder_count: u32,
    floor_price_sol: f64,
    volume_24h_sol: f64,
    market_cap_sol: f64,
    royalty_bps: u16,
    metadata_uri: []const u8,
};

pub const NftMint = struct {
    mint_address: []const u8,
    slot: u64,
    block_time: i64,
    collection_address: []const u8,
    owner: []const u8,
    creator_address: []const u8,
    name: []const u8,
    symbol: []const u8,
    uri: []const u8,
    seller_fee_basis_points: u16,
    primary_sale_happened: u8,
    is_mutable: u8,
    edition_nonce: ?u8,
    token_standard: []const u8,
    uses: ?[]const u8,
};

pub const NftListing = struct {
    listing_address: []const u8,
    slot: u64,
    block_time: i64,
    marketplace: []const u8,
    mint_address: []const u8,
    collection_address: []const u8,
    seller: []const u8,
    price_sol: f64,
    expiry_time: i64,
    cancelled: u8,
};

pub const NftSale = struct {
    signature: []const u8,
    slot: u64,
    block_time: i64,
    marketplace: []const u8,
    mint_address: []const u8,
    collection_address: []const u8,
    seller: []const u8,
    buyer: []const u8,
    price_sol: f64,
    price_usd: f64,
    fee_amount: f64,
    royalty_amount: f64,
};

pub const NftBid = struct {
    bid_address: []const u8,
    slot: u64,
    block_time: i64,
    marketplace: []const u8,
    mint_address: []const u8,
    collection_address: []const u8,
    bidder: []const u8,
    price_sol: f64,
    expiry_time: i64,
    cancelled: u8,
};

// DeFi-related structures
pub const PoolSwap = struct {
    signature: []const u8,
    slot: u64,
    block_time: i64,
    pool_address: []const u8,
    user_account: []const u8,
    token_in_mint: []const u8,
    token_out_mint: []const u8,
    token_in_amount: u64,
    token_out_amount: u64,
    token_in_price_usd: f64,
    token_out_price_usd: f64,
    fee_amount: u64,
    program_id: []const u8,
};

pub const LiquidityPool = struct {
    pool_address: []const u8,
    slot: u64,
    block_time: i64,
    amm_id: []const u8,
    token_a_mint: []const u8,
    token_b_mint: []const u8,
    token_a_amount: u64,
    token_b_amount: u64,
    token_a_price_usd: f64,
    token_b_price_usd: f64,
    tvl_usd: f64,
    fee_rate: f64,
    volume_24h_usd: f64,
    apy_24h: f64,
};

pub const DefiEvent = struct {
    signature: []const u8,
    slot: u64,
    block_time: i64,
    protocol_id: []const u8,
    event_type: []const u8,
    user_account: []const u8,
    market_address: []const u8,
    token_a_mint: []const u8,
    token_b_mint: []const u8,
    token_a_amount: u64,
    token_b_amount: u64,
    token_a_price_usd: f64,
    token_b_price_usd: f64,
    fee_amount: u64,
};

pub const LendingMarket = struct {
    market_address: []const u8,
    slot: u64,
    block_time: i64,
    protocol_id: []const u8,
    asset_mint: []const u8,
    c_token_mint: []const u8,
    total_deposits: u64,
    total_borrows: u64,
    deposit_rate: f64,
    borrow_rate: f64,
    utilization_rate: f64,
    liquidation_threshold: f64,
    ltv_ratio: f64,
    asset_price_usd: f64,
    tvl_usd: f64,
};

pub const LendingPosition = struct {
    position_address: []const u8,
    slot: u64,
    block_time: i64,
    market_address: []const u8,
    owner: []const u8,
    deposit_amount: u64,
    borrow_amount: u64,
    collateral_amount: u64,
    liquidation_threshold: f64,
    health_factor: f64,
};

pub const PerpetualMarket = struct {
    market_address: []const u8,
    slot: u64,
    block_time: i64,
    protocol_id: []const u8,
    base_token_mint: []const u8,
    quote_token_mint: []const u8,
    base_price_usd: f64,
    mark_price_usd: f64,
    index_price_usd: f64,
    funding_rate: f64,
    open_interest: u64,
    volume_24h_usd: f64,
    base_deposit_total: u64,
    quote_deposit_total: u64,
};

pub const PerpetualPosition = struct {
    position_address: []const u8,
    slot: u64,
    block_time: i64,
    market_address: []const u8,
    owner: []const u8,
    position_size: i64,
    entry_price: f64,
    liquidation_price: f64,
    unrealized_pnl: f64,
    realized_pnl: f64,
    collateral_amount: u64,
    leverage: f64,
};

// Security-related structures
pub const SecurityEvent = struct {
    event_id: []const u8,
    slot: u64,
    block_time: i64,
    event_type: []const u8,
    severity: []const u8,
    program_id: []const u8,
    affected_accounts: []const []const u8,
    affected_tokens: []const []const u8,
    loss_amount_usd: f64,
    description: []const u8,
};

pub const SuspiciousAccount = struct {
    account_address: []const u8,
    slot: u64,
    block_time: i64,
    risk_score: f64,
    risk_factors: []const []const u8,
    associated_events: []const []const u8,
    last_activity_slot: u64,
    total_volume_usd: f64,
    linked_accounts: []const []const u8,
};

pub const ProgramSecurityMetrics = struct {
    program_id: []const u8,
    slot: u64,
    block_time: i64,
    audit_status: []const u8,
    vulnerability_count: u32,
    critical_vulnerabilities: u32,
    high_vulnerabilities: u32,
    medium_vulnerabilities: u32,
    low_vulnerabilities: u32,
    last_audit_date: i64,
    auditor: []const u8,
    tvl_at_risk_usd: f64,
};

pub const SecurityAnalytics = struct {
    slot: u64,
    block_time: i64,
    category: []const u8,
    total_events_24h: u32,
    critical_events_24h: u32,
    affected_users_24h: u32,
    total_loss_usd: f64,
    average_risk_score: f64,
    unique_attack_vectors: u32,
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
        insertBlockFn: *const fn (self: *anyopaque, block: Block) DatabaseError!void,
        updateBlockStatsFn: *const fn (self: *anyopaque, stats: BlockStats) DatabaseError!void,
        // Token-related methods
        insertTokenAccountFn: *const fn (self: *anyopaque, token_account: TokenAccount) DatabaseError!void,
        insertTokenTransferFn: *const fn (self: *anyopaque, transfer: TokenTransfer) DatabaseError!void,
        insertTokenHolderFn: *const fn (self: *anyopaque, holder: TokenHolder) DatabaseError!void,
        insertTokenAnalyticsFn: *const fn (self: *anyopaque, analytics: TokenAnalytics) DatabaseError!void,
        insertTokenProgramActivityFn: *const fn (self: *anyopaque, activity: TokenProgramActivity) DatabaseError!void,
        // NFT-related methods
        insertNftCollectionFn: *const fn (self: *anyopaque, collection: NftCollection) DatabaseError!void,
        insertNftMintFn: *const fn (self: *anyopaque, mint: NftMint) DatabaseError!void,
        insertNftListingFn: *const fn (self: *anyopaque, listing: NftListing) DatabaseError!void,
        insertNftSaleFn: *const fn (self: *anyopaque, sale: NftSale) DatabaseError!void,
        insertNftBidFn: *const fn (self: *anyopaque, bid: NftBid) DatabaseError!void,
        // DeFi-related methods
        insertPoolSwapFn: *const fn (self: *anyopaque, swap: PoolSwap) DatabaseError!void,
        insertLiquidityPoolFn: *const fn (self: *anyopaque, pool: LiquidityPool) DatabaseError!void,
        insertDefiEventFn: *const fn (self: *anyopaque, event: DefiEvent) DatabaseError!void,
        insertLendingMarketFn: *const fn (self: *anyopaque, market: LendingMarket) DatabaseError!void,
        insertLendingPositionFn: *const fn (self: *anyopaque, position: LendingPosition) DatabaseError!void,
        insertPerpetualMarketFn: *const fn (self: *anyopaque, market: PerpetualMarket) DatabaseError!void,
        insertPerpetualPositionFn: *const fn (self: *anyopaque, position: PerpetualPosition) DatabaseError!void,
        // Security-related methods
        insertSecurityEventFn: *const fn (self: *anyopaque, event: SecurityEvent) DatabaseError!void,
        insertSuspiciousAccountFn: *const fn (self: *anyopaque, account: SuspiciousAccount) DatabaseError!void,
        insertProgramSecurityMetricsFn: *const fn (self: *anyopaque, metrics: ProgramSecurityMetrics) DatabaseError!void,
        insertSecurityAnalyticsFn: *const fn (self: *anyopaque, analytics: SecurityAnalytics) DatabaseError!void,
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
    
    /// Insert block data
    pub fn insertBlock(self: *DatabaseClient, block: Block) DatabaseError!void {
        return self.vtable.insertBlockFn(self.toAnyopaque(), block);
    }
    
    /// Update block statistics
    pub fn updateBlockStats(self: *DatabaseClient, stats: BlockStats) DatabaseError!void {
        return self.vtable.updateBlockStatsFn(self.toAnyopaque(), stats);
    }
    
    // Token-related methods
    /// Insert token account data
    pub fn insertTokenAccount(self: *DatabaseClient, token_account: TokenAccount) DatabaseError!void {
        return self.vtable.insertTokenAccountFn(self.toAnyopaque(), token_account);
    }
    
    /// Insert token transfer data
    pub fn insertTokenTransfer(self: *DatabaseClient, transfer: TokenTransfer) DatabaseError!void {
        return self.vtable.insertTokenTransferFn(self.toAnyopaque(), transfer);
    }
    
    /// Insert token holder data
    pub fn insertTokenHolder(self: *DatabaseClient, holder: TokenHolder) DatabaseError!void {
        return self.vtable.insertTokenHolderFn(self.toAnyopaque(), holder);
    }
    
    /// Insert token analytics data
    pub fn insertTokenAnalytics(self: *DatabaseClient, analytics: TokenAnalytics) DatabaseError!void {
        return self.vtable.insertTokenAnalyticsFn(self.toAnyopaque(), analytics);
    }
    
    /// Insert token program activity data
    pub fn insertTokenProgramActivity(self: *DatabaseClient, activity: TokenProgramActivity) DatabaseError!void {
        return self.vtable.insertTokenProgramActivityFn(self.toAnyopaque(), activity);
    }
    
    // NFT-related methods
    /// Insert NFT collection data
    pub fn insertNftCollection(self: *DatabaseClient, collection: NftCollection) DatabaseError!void {
        return self.vtable.insertNftCollectionFn(self.toAnyopaque(), collection);
    }
    
    /// Insert NFT mint data
    pub fn insertNftMint(self: *DatabaseClient, mint: NftMint) DatabaseError!void {
        return self.vtable.insertNftMintFn(self.toAnyopaque(), mint);
    }
    
    /// Insert NFT listing data
    pub fn insertNftListing(self: *DatabaseClient, listing: NftListing) DatabaseError!void {
        return self.vtable.insertNftListingFn(self.toAnyopaque(), listing);
    }
    
    /// Insert NFT sale data
    pub fn insertNftSale(self: *DatabaseClient, sale: NftSale) DatabaseError!void {
        return self.vtable.insertNftSaleFn(self.toAnyopaque(), sale);
    }
    
    /// Insert NFT bid data
    pub fn insertNftBid(self: *DatabaseClient, bid: NftBid) DatabaseError!void {
        return self.vtable.insertNftBidFn(self.toAnyopaque(), bid);
    }
    
    // DeFi-related methods
    /// Insert pool swap data
    pub fn insertPoolSwap(self: *DatabaseClient, swap: PoolSwap) DatabaseError!void {
        return self.vtable.insertPoolSwapFn(self.toAnyopaque(), swap);
    }
    
    /// Insert liquidity pool data
    pub fn insertLiquidityPool(self: *DatabaseClient, pool: LiquidityPool) DatabaseError!void {
        return self.vtable.insertLiquidityPoolFn(self.toAnyopaque(), pool);
    }
    
    /// Insert DeFi event data
    pub fn insertDefiEvent(self: *DatabaseClient, event: DefiEvent) DatabaseError!void {
        return self.vtable.insertDefiEventFn(self.toAnyopaque(), event);
    }
    
    /// Insert lending market data
    pub fn insertLendingMarket(self: *DatabaseClient, market: LendingMarket) DatabaseError!void {
        return self.vtable.insertLendingMarketFn(self.toAnyopaque(), market);
    }
    
    /// Insert lending position data
    pub fn insertLendingPosition(self: *DatabaseClient, position: LendingPosition) DatabaseError!void {
        return self.vtable.insertLendingPositionFn(self.toAnyopaque(), position);
    }
    
    /// Insert perpetual market data
    pub fn insertPerpetualMarket(self: *DatabaseClient, market: PerpetualMarket) DatabaseError!void {
        return self.vtable.insertPerpetualMarketFn(self.toAnyopaque(), market);
    }
    
    /// Insert perpetual position data
    pub fn insertPerpetualPosition(self: *DatabaseClient, position: PerpetualPosition) DatabaseError!void {
        return self.vtable.insertPerpetualPositionFn(self.toAnyopaque(), position);
    }
    
    // Security-related methods
    /// Insert security event data
    pub fn insertSecurityEvent(self: *DatabaseClient, event: SecurityEvent) DatabaseError!void {
        return self.vtable.insertSecurityEventFn(self.toAnyopaque(), event);
    }
    
    /// Insert suspicious account data
    pub fn insertSuspiciousAccount(self: *DatabaseClient, account: SuspiciousAccount) DatabaseError!void {
        return self.vtable.insertSuspiciousAccountFn(self.toAnyopaque(), account);
    }
    
    /// Insert program security metrics data
    pub fn insertProgramSecurityMetrics(self: *DatabaseClient, metrics: ProgramSecurityMetrics) DatabaseError!void {
        return self.vtable.insertProgramSecurityMetricsFn(self.toAnyopaque(), metrics);
    }
    
    /// Insert security analytics data
    pub fn insertSecurityAnalytics(self: *DatabaseClient, analytics: SecurityAnalytics) DatabaseError!void {
        return self.vtable.insertSecurityAnalyticsFn(self.toAnyopaque(), analytics);
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
            
            client.* = ch.ClickHouseClient.init(allocator, url, user, password, database) catch |err| {
                std.log.warn("Failed to initialize ClickHouse client: {any}", .{err});
                return error.DatabaseError;
            };
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