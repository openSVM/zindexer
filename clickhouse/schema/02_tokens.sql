CREATE TABLE IF NOT EXISTS token_mints (mint_address String,slot UInt64,block_time DateTime64(3),decimals UInt8,supply UInt64,authority String,freeze_authority Nullable(String),is_initialized UInt8,name String,symbol String,uri String,verified UInt8) ENGINE = ReplacingMergeTree PRIMARY KEY (mint_address,slot);

CREATE TABLE IF NOT EXISTS token_accounts (account_address String,mint_address String,slot UInt64,block_time DateTime64(3),owner String,amount UInt64,delegate Nullable(String),delegated_amount UInt64,is_initialized UInt8,is_frozen UInt8,is_native UInt8,rent_exempt_reserve Nullable(UInt64),close_authority Nullable(String)) ENGINE = ReplacingMergeTree PRIMARY KEY (account_address,slot);

CREATE TABLE IF NOT EXISTS token_transfers (signature String,slot UInt64,block_time DateTime64(3),mint_address String,from_account String,to_account String,amount UInt64,decimals UInt8,program_id String,instruction_type String) ENGINE = ReplacingMergeTree PRIMARY KEY (signature,mint_address,from_account,to_account);

CREATE TABLE IF NOT EXISTS token_prices (mint_address String,slot UInt64,block_time DateTime64(3),price_usd Float64,volume_usd Float64,liquidity_usd Float64,source String) ENGINE = ReplacingMergeTree PRIMARY KEY (mint_address,slot);

CREATE TABLE IF NOT EXISTS token_holders (mint_address String,slot UInt64,block_time DateTime64(3),owner String,balance UInt64,balance_usd Float64) ENGINE = ReplacingMergeTree PRIMARY KEY (mint_address,owner,slot);

CREATE TABLE IF NOT EXISTS token_supply_history (mint_address String,slot UInt64,block_time DateTime64(3),total_supply UInt64,circulating_supply UInt64,holder_count UInt32) ENGINE = ReplacingMergeTree PRIMARY KEY (mint_address,slot);

CREATE TABLE IF NOT EXISTS token_analytics (mint_address String,slot UInt64,block_time DateTime64(3),transfer_count UInt32,unique_holders UInt32,active_accounts UInt32,total_volume_usd Float64,avg_transaction_size Float64) ENGINE = SummingMergeTree PRIMARY KEY (mint_address,slot);

CREATE TABLE IF NOT EXISTS token_program_activity (program_id String,slot UInt64,block_time DateTime64(3),instruction_type String,execution_count UInt32,error_count UInt32,unique_users UInt32,unique_tokens UInt32) ENGINE = SummingMergeTree PRIMARY KEY (program_id,slot,instruction_type);
