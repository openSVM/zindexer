CREATE TABLE IF NOT EXISTS nft_collections (collection_address String,slot UInt64,block_time DateTime64(3),name String,symbol String,creator_address String,verified UInt8,total_supply UInt32,holder_count UInt32,floor_price_sol Float64,volume_24h_sol Float64,market_cap_sol Float64,royalty_bps UInt16,metadata_uri String) ENGINE = ReplacingMergeTree PRIMARY KEY (collection_address,slot);

CREATE TABLE IF NOT EXISTS nft_mints (mint_address String,slot UInt64,block_time DateTime64(3),collection_address String,owner String,creator_address String,name String,symbol String,uri String,seller_fee_basis_points UInt16,primary_sale_happened UInt8,is_mutable UInt8,edition_nonce Nullable(UInt8),token_standard String,uses Nullable(UInt64)) ENGINE = ReplacingMergeTree PRIMARY KEY (mint_address,slot);

CREATE TABLE IF NOT EXISTS nft_sales (signature String,slot UInt64,block_time DateTime64(3),marketplace String,mint_address String,collection_address String,seller String,buyer String,price_sol Float64,price_usd Float64,fee_amount Float64,royalty_amount Float64) ENGINE = ReplacingMergeTree PRIMARY KEY (signature,mint_address);

CREATE TABLE IF NOT EXISTS nft_listings (listing_address String,slot UInt64,block_time DateTime64(3),marketplace String,mint_address String,collection_address String,seller String,price_sol Float64,expiry_time DateTime64(3),cancelled UInt8) ENGINE = ReplacingMergeTree PRIMARY KEY (listing_address,slot);

CREATE TABLE IF NOT EXISTS nft_bids (bid_address String,slot UInt64,block_time DateTime64(3),marketplace String,mint_address String,collection_address String,bidder String,price_sol Float64,expiry_time DateTime64(3),cancelled UInt8) ENGINE = ReplacingMergeTree PRIMARY KEY (bid_address,slot);

CREATE TABLE IF NOT EXISTS nft_analytics (collection_address String,slot UInt64,block_time DateTime64(3),floor_price_sol Float64,listed_count UInt32,volume_24h_sol Float64,sales_count_24h UInt32,unique_buyers_24h UInt32,unique_sellers_24h UInt32,average_price_24h Float64,market_cap_sol Float64,holder_count UInt32) ENGINE = ReplacingMergeTree PRIMARY KEY (collection_address,slot);

CREATE TABLE IF NOT EXISTS security_events (event_id String,slot UInt64,block_time DateTime64(3),event_type String,severity String,program_id String,affected_accounts Array(String),affected_tokens Array(String),loss_amount_usd Float64,description String) ENGINE = ReplacingMergeTree PRIMARY KEY (event_id);

CREATE TABLE IF NOT EXISTS suspicious_accounts (account_address String,slot UInt64,block_time DateTime64(3),risk_score Float64,risk_factors Array(String),associated_events Array(String),last_activity_slot UInt64,total_volume_usd Float64,linked_accounts Array(String)) ENGINE = ReplacingMergeTree PRIMARY KEY (account_address,slot);

CREATE TABLE IF NOT EXISTS program_security_metrics (program_id String,slot UInt64,block_time DateTime64(3),audit_status String,vulnerability_count UInt32,critical_vulnerabilities UInt32,high_vulnerabilities UInt32,medium_vulnerabilities UInt32,low_vulnerabilities UInt32,last_audit_date DateTime64(3),auditor String,tvl_at_risk_usd Float64) ENGINE = ReplacingMergeTree PRIMARY KEY (program_id,slot);

CREATE TABLE IF NOT EXISTS security_analytics (slot UInt64,block_time DateTime64(3),category String,total_events_24h UInt32,critical_events_24h UInt32,affected_users_24h UInt32,total_loss_usd Float64,average_risk_score Float64,unique_attack_vectors UInt32) ENGINE = SummingMergeTree PRIMARY KEY (slot,category);
