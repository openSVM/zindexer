CREATE TABLE IF NOT EXISTS blocks (
    slot LONG,
    blockhash SYMBOL,
    previous_blockhash SYMBOL,
    parent_slot LONG,
    block_time TIMESTAMP,
    block_height LONG,
    leader_identity SYMBOL,
    rewards DOUBLE,
    transaction_count INT,
    successful_transaction_count INT,
    failed_transaction_count INT,
    PRIMARY KEY(slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS transactions (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    success BOOLEAN,
    fee LONG,
    compute_units_consumed LONG,
    compute_units_price LONG,
    recent_blockhash SYMBOL,
    program_ids SYMBOL,
    signers SYMBOL,
    account_keys SYMBOL,
    pre_balances SYMBOL,
    post_balances SYMBOL,
    pre_token_balances STRING,
    post_token_balances STRING,
    log_messages SYMBOL,
    error STRING,
    PRIMARY KEY(signature)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS accounts (
    pubkey SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    owner SYMBOL,
    lamports LONG,
    executable BOOLEAN,
    rent_epoch LONG,
    data_len LONG,
    write_version LONG,
    PRIMARY KEY(pubkey, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS instructions (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    program_id SYMBOL,
    instruction_index INT,
    inner_instruction_index INT,
    instruction_type SYMBOL,
    parsed_data STRING,
    accounts SYMBOL,
    PRIMARY KEY(signature, instruction_index)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS program_executions (
    slot LONG,
    block_time TIMESTAMP,
    program_id SYMBOL,
    execution_count INT,
    total_cu_consumed LONG,
    total_fee LONG,
    success_count INT,
    error_count INT,
    PRIMARY KEY(slot, program_id)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS account_activity (
    slot LONG,
    block_time TIMESTAMP,
    pubkey SYMBOL,
    program_id SYMBOL,
    write_count INT,
    cu_consumed LONG,
    fee_paid LONG,
    PRIMARY KEY(slot, pubkey, program_id)
) TIMESTAMP(block_time);