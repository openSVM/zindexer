CREATE TABLE IF NOT EXISTS token_mints (
    mint_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    owner SYMBOL,
    supply LONG,
    decimals INT,
    is_nft BOOLEAN,
    metadata_address SYMBOL,
    metadata_uri STRING,
    metadata_name SYMBOL,
    metadata_symbol SYMBOL,
    PRIMARY KEY(mint_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS token_accounts (
    account_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    owner SYMBOL,
    mint SYMBOL,
    amount LONG,
    delegate SYMBOL,
    state SYMBOL,
    is_native BOOLEAN,
    PRIMARY KEY(account_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS token_transfers (
    signature SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    mint SYMBOL,
    from_account SYMBOL,
    to_account SYMBOL,
    from_owner SYMBOL,
    to_owner SYMBOL,
    amount LONG,
    program_id SYMBOL,
    PRIMARY KEY(signature, mint, from_account, to_account)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS token_balances (
    account_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    owner SYMBOL,
    mint SYMBOL,
    amount LONG,
    PRIMARY KEY(account_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS token_metadata (
    mint_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    metadata_address SYMBOL,
    update_authority SYMBOL,
    name SYMBOL,
    symbol SYMBOL,
    uri STRING,
    seller_fee_basis_points INT,
    creators SYMBOL,
    PRIMARY KEY(mint_address, slot)
) TIMESTAMP(block_time);

CREATE TABLE IF NOT EXISTS token_supply_changes (
    mint_address SYMBOL,
    slot LONG,
    block_time TIMESTAMP,
    previous_supply LONG,
    new_supply LONG,
    change_amount LONG,
    authority SYMBOL,
    PRIMARY KEY(mint_address, slot)
) TIMESTAMP(block_time);