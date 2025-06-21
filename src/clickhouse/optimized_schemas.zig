const std = @import("std");

/// Optimized ClickHouse table schemas with proper engines, compression, and partitioning
pub const OptimizedSchemas = struct {
    /// Core blockchain tables with optimized settings
    pub const CORE_TABLES = struct {
        // Optimized blocks table with partitioning by date
        pub const BLOCKS =
            \\CREATE TABLE IF NOT EXISTS blocks (
            \\    network String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    block_hash String,
            \\    parent_slot UInt64,
            \\    parent_hash String,
            \\    block_height UInt64,
            \\    transaction_count UInt32,
            \\    successful_transaction_count UInt32,
            \\    failed_transaction_count UInt32,
            \\    total_fee UInt64,
            \\    total_compute_units UInt64,
            \\    leader_identity String,
            \\    rewards Array(Tuple(String, UInt64)) CODEC(ZSTD(1))
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot)
            \\PRIMARY KEY (network, slot)
            \\SETTINGS index_granularity = 8192
        ;

        // Optimized transactions table with compression
        pub const TRANSACTIONS =
            \\CREATE TABLE IF NOT EXISTS transactions (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    success UInt8,
            \\    fee UInt64,
            \\    compute_units_consumed UInt64,
            \\    compute_units_price UInt64,
            \\    recent_blockhash String,
            \\    program_ids Array(String) CODEC(ZSTD(1)),
            \\    signers Array(String) CODEC(ZSTD(1)),
            \\    account_keys Array(String) CODEC(ZSTD(1)),
            \\    pre_balances Array(UInt64) CODEC(ZSTD(1)),
            \\    post_balances Array(UInt64) CODEC(ZSTD(1)),
            \\    pre_token_balances String CODEC(ZSTD(1)),
            \\    post_token_balances String CODEC(ZSTD(1)),
            \\    log_messages Array(String) CODEC(ZSTD(1)),
            \\    error Nullable(String),
            \\    INDEX idx_program_ids program_ids TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_signers signers TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot, signature)
            \\PRIMARY KEY (network, slot)
            \\SETTINGS index_granularity = 8192
        ;

        // Optimized instructions table
        pub const INSTRUCTIONS =
            \\CREATE TABLE IF NOT EXISTS instructions (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    program_id String,
            \\    instruction_index UInt32,
            \\    inner_instruction_index Nullable(UInt32),
            \\    instruction_type String,
            \\    parsed_data String CODEC(ZSTD(1)),
            \\    accounts Array(String) CODEC(ZSTD(1)),
            \\    INDEX idx_program_id program_id TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_instruction_type instruction_type TYPE set(100) GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot, signature, instruction_index)
            \\PRIMARY KEY (network, slot, signature)
            \\SETTINGS index_granularity = 8192, allow_nullable_key = 1
        ;

        // Optimized accounts table
        pub const ACCOUNTS =
            \\CREATE TABLE IF NOT EXISTS accounts (
            \\    network String,
            \\    pubkey String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    owner String,
            \\    lamports UInt64,
            \\    executable UInt8,
            \\    rent_epoch UInt64,
            \\    data_len UInt64,
            \\    write_version UInt64,
            \\    INDEX idx_owner owner TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree(write_version)
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, pubkey, slot)
            \\PRIMARY KEY (network, pubkey)
            \\SETTINGS index_granularity = 8192
        ;
    };

    /// Token-related tables with optimized settings
    pub const TOKEN_TABLES = struct {
        pub const TOKEN_ACCOUNTS =
            \\CREATE TABLE IF NOT EXISTS token_accounts (
            \\    network String,
            \\    account_address String,
            \\    mint_address String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    owner String,
            \\    amount UInt64,
            \\    delegate Nullable(String),
            \\    delegated_amount UInt64,
            \\    is_initialized UInt8,
            \\    is_frozen UInt8,
            \\    is_native UInt8,
            \\    rent_exempt_reserve Nullable(UInt64),
            \\    close_authority Nullable(String),
            \\    INDEX idx_mint mint_address TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_owner owner TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, account_address, slot)
            \\PRIMARY KEY (network, account_address)
            \\SETTINGS index_granularity = 8192
        ;

        pub const TOKEN_TRANSFERS =
            \\CREATE TABLE IF NOT EXISTS token_transfers (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    mint_address String,
            \\    from_account String,
            \\    to_account String,
            \\    amount UInt64,
            \\    decimals UInt8,
            \\    program_id String,
            \\    instruction_type String,
            \\    INDEX idx_mint mint_address TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_from from_account TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_to to_account TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot, signature, mint_address)
            \\PRIMARY KEY (network, slot, signature)
            \\SETTINGS index_granularity = 8192
        ;

        pub const TOKEN_PRICES =
            \\CREATE TABLE IF NOT EXISTS token_prices (
            \\    network String,
            \\    mint_address String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    price_usd Float64,
            \\    volume_usd Float64,
            \\    liquidity_usd Float64,
            \\    source String,
            \\    INDEX idx_source source TYPE set(50) GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, mint_address, slot)
            \\PRIMARY KEY (network, mint_address)
            \\SETTINGS index_granularity = 8192
        ;
    };

    /// DeFi tables with optimized settings
    pub const DEFI_TABLES = struct {
        pub const POOL_SWAPS =
            \\CREATE TABLE IF NOT EXISTS pool_swaps (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    pool_address String,
            \\    user_account String,
            \\    token_in_mint String,
            \\    token_out_mint String,
            \\    token_in_amount UInt64,
            \\    token_out_amount UInt64,
            \\    token_in_price_usd Float64,
            \\    token_out_price_usd Float64,
            \\    fee_amount UInt64,
            \\    program_id String,
            \\    INDEX idx_pool pool_address TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_user user_account TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_token_in token_in_mint TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_token_out token_out_mint TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot, signature, pool_address)
            \\PRIMARY KEY (network, slot, signature)
            \\SETTINGS index_granularity = 8192
        ;

        pub const LIQUIDITY_POOLS =
            \\CREATE TABLE IF NOT EXISTS liquidity_pools (
            \\    network String,
            \\    pool_address String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    amm_id String,
            \\    token_a_mint String,
            \\    token_b_mint String,
            \\    token_a_amount UInt64,
            \\    token_b_amount UInt64,
            \\    token_a_price_usd Float64,
            \\    token_b_price_usd Float64,
            \\    tvl_usd Float64,
            \\    fee_rate Float64,
            \\    volume_24h_usd Float64,
            \\    apy_24h Float64,
            \\    INDEX idx_amm amm_id TYPE set(20) GRANULARITY 1,
            \\    INDEX idx_token_a token_a_mint TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_token_b token_b_mint TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, pool_address, slot)
            \\PRIMARY KEY (network, pool_address)
            \\SETTINGS index_granularity = 8192
        ;
    };

    /// NFT tables with optimized settings
    pub const NFT_TABLES = struct {
        pub const NFT_MINTS =
            \\CREATE TABLE IF NOT EXISTS nft_mints (
            \\    network String,
            \\    mint_address String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    collection_address Nullable(String),
            \\    owner String,
            \\    creator Nullable(String),
            \\    name Nullable(String),
            \\    symbol Nullable(String),
            \\    uri Nullable(String) CODEC(ZSTD(1)),
            \\    metadata_uri Nullable(String) CODEC(ZSTD(1)),
            \\    verified UInt8,
            \\    INDEX idx_collection collection_address TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_owner owner TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_creator creator TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, mint_address, slot)
            \\PRIMARY KEY (network, mint_address)
            \\SETTINGS index_granularity = 8192
        ;

        pub const NFT_TRANSFERS =
            \\CREATE TABLE IF NOT EXISTS nft_transfers (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    mint_address String,
            \\    from_account String,
            \\    to_account String,
            \\    program_id String,
            \\    instruction_type String,
            \\    INDEX idx_mint mint_address TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_from from_account TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_to to_account TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot, signature, mint_address)
            \\PRIMARY KEY (network, slot, signature)
            \\SETTINGS index_granularity = 8192
        ;
    };

    /// Security tables with optimized settings
    pub const SECURITY_TABLES = struct {
        pub const SECURITY_EVENTS =
            \\CREATE TABLE IF NOT EXISTS security_events (
            \\    network String,
            \\    signature String,
            \\    slot UInt64,
            \\    block_time DateTime64(3),
            \\    event_type String,
            \\    account_address Nullable(String),
            \\    program_id Nullable(String),
            \\    severity String,
            \\    description Nullable(String) CODEC(ZSTD(1)),
            \\    verified UInt8,
            \\    INDEX idx_event_type event_type TYPE set(50) GRANULARITY 1,
            \\    INDEX idx_severity severity TYPE set(10) GRANULARITY 1,
            \\    INDEX idx_account account_address TYPE bloom_filter GRANULARITY 1,
            \\    INDEX idx_program program_id TYPE bloom_filter GRANULARITY 1
            \\) ENGINE = ReplacingMergeTree()
            \\PARTITION BY (network, toYYYYMM(block_time))
            \\ORDER BY (network, slot, signature, event_type)
            \\PRIMARY KEY (network, slot, signature)
            \\SETTINGS index_granularity = 8192
        ;
    };

    /// Analytics materialized views for common queries
    pub const MATERIALIZED_VIEWS = struct {
        pub const HOURLY_METRICS =
            \\CREATE MATERIALIZED VIEW IF NOT EXISTS hourly_metrics
            \\ENGINE = SummingMergeTree()
            \\PARTITION BY (network, toYYYYMM(hour))
            \\ORDER BY (network, hour)
            \\AS SELECT
            \\    network,
            \\    toStartOfHour(block_time) as hour,
            \\    count() as transaction_count,
            \\    sum(fee) as total_fees,
            \\    sum(compute_units_consumed) as total_compute_units,
            \\    avg(compute_units_consumed) as avg_compute_units,
            \\    countIf(success = 1) as successful_transactions,
            \\    countIf(success = 0) as failed_transactions
            \\FROM transactions
            \\GROUP BY network, hour
        ;

        pub const DAILY_TOKEN_METRICS =
            \\CREATE MATERIALIZED VIEW IF NOT EXISTS daily_token_metrics
            \\ENGINE = SummingMergeTree()
            \\PARTITION BY (network, toYYYYMM(day))
            \\ORDER BY (network, mint_address, day)
            \\AS SELECT
            \\    network,
            \\    mint_address,
            \\    toDate(block_time) as day,
            \\    count() as transfer_count,
            \\    sum(amount) as total_volume,
            \\    uniqExact(from_account) as unique_senders,
            \\    uniqExact(to_account) as unique_receivers,
            \\    max(amount) as max_transfer,
            \\    avg(amount) as avg_transfer
            \\FROM token_transfers
            \\GROUP BY network, mint_address, day
        ;

        pub const PROGRAM_ANALYTICS =
            \\CREATE MATERIALIZED VIEW IF NOT EXISTS program_analytics
            \\ENGINE = SummingMergeTree()
            \\PARTITION BY (network, toYYYYMM(hour))
            \\ORDER BY (network, program_id, hour)
            \\AS SELECT
            \\    network,
            \\    program_id,
            \\    toStartOfHour(block_time) as hour,
            \\    count() as execution_count,
            \\    uniqExact(arrayJoin(signers)) as unique_users,
            \\    sum(compute_units_consumed) as total_compute_units,
            \\    sum(fee) as total_fees,
            \\    countIf(success = 1) as successful_executions,
            \\    countIf(success = 0) as failed_executions
            \\FROM transactions
            \\ARRAY JOIN program_ids as program_id
            \\GROUP BY network, program_id, hour
        ;
    };

    /// Get all table creation statements
    pub fn getAllTableStatements(allocator: std.mem.Allocator) ![]const []const u8 {
        var statements = std.ArrayList([]const u8).init(allocator);
        
        // Core tables
        try statements.append(CORE_TABLES.BLOCKS);
        try statements.append(CORE_TABLES.TRANSACTIONS);
        try statements.append(CORE_TABLES.INSTRUCTIONS);
        try statements.append(CORE_TABLES.ACCOUNTS);
        
        // Token tables
        try statements.append(TOKEN_TABLES.TOKEN_ACCOUNTS);
        try statements.append(TOKEN_TABLES.TOKEN_TRANSFERS);
        try statements.append(TOKEN_TABLES.TOKEN_PRICES);
        
        // DeFi tables
        try statements.append(DEFI_TABLES.POOL_SWAPS);
        try statements.append(DEFI_TABLES.LIQUIDITY_POOLS);
        
        // NFT tables
        try statements.append(NFT_TABLES.NFT_MINTS);
        try statements.append(NFT_TABLES.NFT_TRANSFERS);
        
        // Security tables
        try statements.append(SECURITY_TABLES.SECURITY_EVENTS);
        
        return statements.toOwnedSlice();
    }

    /// Get all materialized view statements
    pub fn getAllViewStatements(allocator: std.mem.Allocator) ![]const []const u8 {
        var statements = std.ArrayList([]const u8).init(allocator);
        
        try statements.append(MATERIALIZED_VIEWS.HOURLY_METRICS);
        try statements.append(MATERIALIZED_VIEWS.DAILY_TOKEN_METRICS);
        try statements.append(MATERIALIZED_VIEWS.PROGRAM_ANALYTICS);
        
        return statements.toOwnedSlice();
    }
};