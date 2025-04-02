CREATE TABLE IF NOT EXISTS nft_collections (
    collection_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    name SYMBOL,
    symbol SYMBOL,
    uri STRING,
    seller_fee_basis_points INT,
    creator_addresses SYMBOL,
    creator_shares SYMBOL,
    verified BOOLEAN,
    PRIMARY KEY(collection_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_mints (
    mint_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    collection_address SYMBOL,
    owner SYMBOL,
    name SYMBOL,
    uri STRING,
    seller_fee_basis_points INT,
    creator_addresses SYMBOL,
    creator_shares SYMBOL,
    PRIMARY KEY(mint_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_transfers (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint_address SYMBOL,
    from_owner SYMBOL,
    to_owner SYMBOL,
    program_id SYMBOL,
    PRIMARY KEY(signature, mint_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_sales (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint_address SYMBOL,
    collection_address SYMBOL,
    seller SYMBOL,
    buyer SYMBOL,
    price LONG,
    currency_mint SYMBOL,
    marketplace SYMBOL,
    PRIMARY KEY(signature, mint_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_listings (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint_address SYMBOL,
    collection_address SYMBOL,
    seller SYMBOL,
    price LONG,
    currency_mint SYMBOL,
    marketplace SYMBOL,
    expiry_time TIMESTAMP,
    PRIMARY KEY(signature, mint_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_cancellations (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint_address SYMBOL,
    collection_address SYMBOL,
    seller SYMBOL,
    marketplace SYMBOL,
    PRIMARY KEY(signature, mint_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS nft_offers (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint_address SYMBOL,
    collection_address SYMBOL,
    buyer SYMBOL,
    price LONG,
    currency_mint SYMBOL,
    marketplace SYMBOL,
    expiry_time TIMESTAMP,
    PRIMARY KEY(signature, mint_address)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS security_events (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    event_type SYMBOL,
    program_id SYMBOL,
    account_address SYMBOL,
    severity SYMBOL,
    description STRING,
    PRIMARY KEY(signature, event_type)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS suspicious_transactions (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    risk_score DOUBLE,
    risk_factors SYMBOL,
    program_ids SYMBOL,
    accounts_involved SYMBOL,
    PRIMARY KEY(signature)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS account_risk_scores (
    pubkey SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    risk_score DOUBLE,
    risk_factors SYMBOL,
    last_activity_slot LONG,
    last_activity_time TIMESTAMP,
    PRIMARY KEY(pubkey, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS program_risk_scores (
    program_id SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    risk_score DOUBLE,
    risk_factors SYMBOL,
    verified BOOLEAN,
    audit_status SYMBOL,
    PRIMARY KEY(program_id, slot)
) TIMESTAMP(block_time);