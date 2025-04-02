CREATE TABLE IF NOT EXISTS liquidity_pools (
    pool_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    protocol SYMBOL,
    token_a_mint SYMBOL,
    token_b_mint SYMBOL,
    token_a_amount LONG,
    token_b_amount LONG,
    lp_token_mint SYMBOL,
    lp_token_supply LONG,
    PRIMARY KEY(pool_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS pool_swaps (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    pool_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_in_mint SYMBOL,
    token_out_mint SYMBOL,
    token_in_amount LONG,
    token_out_amount LONG,
    fee_amount LONG,
    PRIMARY KEY(signature, pool_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS liquidity_deposits (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    pool_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_a_mint SYMBOL,
    token_b_mint SYMBOL,
    token_a_amount LONG,
    token_b_amount LONG,
    lp_token_amount LONG,
    PRIMARY KEY(signature, pool_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS liquidity_withdrawals (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    pool_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_a_mint SYMBOL,
    token_b_mint SYMBOL,
    token_a_amount LONG,
    token_b_amount LONG,
    lp_token_amount LONG,
    PRIMARY KEY(signature, pool_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS lending_markets (
    market_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    protocol SYMBOL,
    token_mint SYMBOL,
    total_deposits LONG,
    total_borrows LONG,
    utilization_rate DOUBLE,
    borrow_rate DOUBLE,
    supply_rate DOUBLE,
    PRIMARY KEY(market_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS lending_deposits (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    market_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_mint SYMBOL,
    amount LONG,
    PRIMARY KEY(signature, market_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS lending_withdrawals (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    market_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_mint SYMBOL,
    amount LONG,
    PRIMARY KEY(signature, market_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS lending_borrows (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    market_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_mint SYMBOL,
    amount LONG,
    PRIMARY KEY(signature, market_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS lending_repayments (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    market_address SYMBOL,
    protocol SYMBOL,
    user SYMBOL,
    token_mint SYMBOL,
    amount LONG,
    PRIMARY KEY(signature, market_address)
) TIMESTAMP(block_time);