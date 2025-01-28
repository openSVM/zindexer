CREATE TABLE IF NOT EXISTS chain_statistics (slot UInt64,block_time DateTime64(3),transaction_count UInt32,successful_transaction_count UInt32,failed_transaction_count UInt32,total_fees UInt64,average_fee Float64,compute_units_consumed UInt64,average_compute_units Float64,active_accounts UInt32,new_accounts UInt32,program_executions UInt32,average_block_time Float64,tps Float64) ENGINE = ReplacingMergeTree PRIMARY KEY (slot);

CREATE TABLE IF NOT EXISTS fee_analytics (slot UInt64,block_time DateTime64(3),program_id String,total_fees UInt64,average_fee Float64,total_compute_units UInt64,average_compute_units Float64,transaction_count UInt32,unique_users UInt32) ENGINE = SummingMergeTree PRIMARY KEY (slot,program_id);

CREATE TABLE IF NOT EXISTS account_analytics (slot UInt64,block_time DateTime64(3),account_type String,total_accounts UInt32,active_accounts UInt32,new_accounts UInt32,total_balance UInt64,average_balance Float64,transaction_count UInt32) ENGINE = SummingMergeTree PRIMARY KEY (slot,account_type);

CREATE TABLE IF NOT EXISTS program_analytics (slot UInt64,block_time DateTime64(3),program_id String,category String,execution_count UInt32,unique_users UInt32,success_rate Float64,total_fees UInt64,total_compute_units UInt64,average_compute_units Float64) ENGINE = SummingMergeTree PRIMARY KEY (slot,program_id);

CREATE TABLE IF NOT EXISTS user_analytics (slot UInt64,block_time DateTime64(3),user_bucket String,user_count UInt32,transaction_count UInt32,total_volume_usd Float64,average_transaction_size Float64,total_fees UInt64,programs_interacted Array(String)) ENGINE = SummingMergeTree PRIMARY KEY (slot,user_bucket);

CREATE TABLE IF NOT EXISTS volume_analytics (slot UInt64,block_time DateTime64(3),category String,volume_usd Float64,transaction_count UInt32,unique_users UInt32,average_size_usd Float64,success_rate Float64) ENGINE = SummingMergeTree PRIMARY KEY (slot,category);

CREATE TABLE IF NOT EXISTS network_health (slot UInt64,block_time DateTime64(3),validator_count UInt32,active_stake UInt64,total_supply UInt64,inflation_rate Float64,rent_exempt_minimum UInt64,average_block_time Float64,block_height UInt64,epoch UInt64,epoch_progress Float64) ENGINE = ReplacingMergeTree PRIMARY KEY (slot);

CREATE TABLE IF NOT EXISTS validator_performance (slot UInt64,block_time DateTime64(3),validator_identity String,vote_account String,stake_amount UInt64,commission UInt8,blocks_produced UInt32,blocks_skipped UInt32,uptime_percentage Float64,apy Float64,delegator_count UInt32) ENGINE = ReplacingMergeTree PRIMARY KEY (slot,validator_identity);

CREATE TABLE IF NOT EXISTS error_analytics (slot UInt64,block_time DateTime64(3),program_id String,error_type String,error_count UInt32,affected_users UInt32,total_failed_amount_usd Float64) ENGINE = SummingMergeTree PRIMARY KEY (slot,program_id,error_type);
