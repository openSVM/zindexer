CREATE TABLE IF NOT EXISTS chain_statistics (
    slot LONG,
    block_time TIMESTAMP,
    transaction_count INT,
    successful_transaction_count INT,
    failed_transaction_count INT,
    total_compute_units LONG,
    total_fees LONG,
    average_compute_units DOUBLE,
    average_fee DOUBLE,
    PRIMARY KEY(slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS fee_analytics (
    slot LONG,
    block_time TIMESTAMP,
    total_fees LONG,
    average_fee DOUBLE,
    median_fee DOUBLE,
    max_fee LONG,
    min_fee LONG,
    fee_percentile_10 DOUBLE,
    fee_percentile_25 DOUBLE,
    fee_percentile_75 DOUBLE,
    fee_percentile_90 DOUBLE,
    PRIMARY KEY(slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS compute_unit_analytics (
    slot LONG,
    block_time TIMESTAMP,
    total_compute_units LONG,
    average_compute_units DOUBLE,
    median_compute_units DOUBLE,
    max_compute_units LONG,
    min_compute_units LONG,
    cu_percentile_10 DOUBLE,
    cu_percentile_25 DOUBLE,
    cu_percentile_75 DOUBLE,
    cu_percentile_90 DOUBLE,
    PRIMARY KEY(slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS program_analytics (
    program_id SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    execution_count INT,
    total_cu_consumed LONG,
    total_fee LONG,
    success_count INT,
    error_count INT,
    average_cu_per_execution DOUBLE,
    average_fee_per_execution DOUBLE,
    PRIMARY KEY(program_id, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS account_analytics (
    pubkey SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    transaction_count INT,
    total_cu_consumed LONG,
    total_fee_paid LONG,
    programs_interacted_with SYMBOL,
    PRIMARY KEY(pubkey, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS token_analytics (
    mint_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    transfer_count INT,
    total_transfer_amount LONG,
    unique_senders INT,
    unique_receivers INT,
    active_accounts INT,
    PRIMARY KEY(mint_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS defi_analytics (
    protocol SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    swap_count INT,
    deposit_count INT,
    withdrawal_count INT,
    total_swap_volume LONG,
    total_deposit_volume LONG,
    total_withdrawal_volume LONG,
    unique_users INT,
    PRIMARY KEY(protocol, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_analytics (
    collection_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint_count INT,
    sale_count INT,
    total_sale_volume LONG,
    average_sale_price DOUBLE,
    floor_price LONG,
    unique_owners INT,
    PRIMARY KEY(collection_address, slot)
) TIMESTAMP(block_time);