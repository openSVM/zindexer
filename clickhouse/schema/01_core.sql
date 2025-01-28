CREATE TABLE IF NOT EXISTS blocks (slot UInt64,blockhash String,previous_blockhash String,parent_slot UInt64,block_time DateTime64(3),block_height Nullable(UInt64),leader_identity String,rewards Float64,transaction_count UInt32,successful_transaction_count UInt32,failed_transaction_count UInt32) ENGINE = ReplacingMergeTree PRIMARY KEY (slot);

CREATE TABLE IF NOT EXISTS transactions (signature String,slot UInt64,block_time DateTime64(3),success UInt8,fee UInt64,compute_units_consumed UInt64,compute_units_price UInt64,recent_blockhash String,program_ids Array(String),signers Array(String),account_keys Array(String),pre_balances Array(UInt64),post_balances Array(UInt64),pre_token_balances String CODEC(ZSTD(1)),post_token_balances String CODEC(ZSTD(1)),log_messages Array(String),error String) ENGINE = ReplacingMergeTree PRIMARY KEY (signature);

CREATE TABLE IF NOT EXISTS accounts (pubkey String,slot UInt64,block_time DateTime64(3),owner String,lamports UInt64,executable UInt8,rent_epoch UInt64,data_len UInt64,write_version UInt64) ENGINE = ReplacingMergeTree PRIMARY KEY (pubkey,slot);

CREATE TABLE IF NOT EXISTS instructions (signature String,slot UInt64,block_time DateTime64(3),program_id String,instruction_index UInt32,inner_instruction_index Nullable(UInt32),instruction_type String,parsed_data String CODEC(ZSTD(1)),accounts Array(String)) ENGINE = ReplacingMergeTree PRIMARY KEY (signature,instruction_index) SETTINGS allow_nullable_key=1;

CREATE TABLE IF NOT EXISTS program_executions (slot UInt64,block_time DateTime64(3),program_id String,execution_count UInt32,total_cu_consumed UInt64,total_fee UInt64,success_count UInt32,error_count UInt32) ENGINE = SummingMergeTree PRIMARY KEY (slot,program_id);

CREATE TABLE IF NOT EXISTS account_activity (slot UInt64,block_time DateTime64(3),pubkey String,program_id String,write_count UInt32,cu_consumed UInt64,fee_paid UInt64) ENGINE = SummingMergeTree PRIMARY KEY (slot,pubkey,program_id);
