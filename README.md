# ZIndexer - Multi-Network SVM Indexer

ZIndexer is a high-performance indexer for Solana Virtual Machine (SVM) networks, capable of subscribing to and indexing data from multiple networks simultaneously.

## Features

- **Multi-Network Support**: Index multiple SVM networks (mainnet, devnet, testnet, localnet) simultaneously
- **Comprehensive Indexing**:
  - Automated Market Makers (AMMs)
  - Metaplex NFTs and marketplaces
  - Token transfers and balances
  - Account balance changes
  - Transactions and instructions
  - Blocks and slots
  - Account activity
- **Real-time and Historical Modes**: Choose between real-time indexing or historical backfilling
- **Database Integration**: High-performance storage and querying of indexed data with support for ClickHouse and QuestDB
- **Interactive TUI**: Monitor indexing progress across all networks in real-time

## Requirements

- Zig 0.14.0 or later
- ClickHouse server or QuestDB server
- Internet connection to access SVM networks

## Building

```bash
zig build
```

## Configuration

The indexer uses two configuration files:

- `src/rpc_nodes.json`: HTTP RPC endpoints for each network
- `src/ws_nodes.json`: WebSocket endpoints for each network

You can customize these files to add or remove networks, or to use different RPC providers.

## Usage

```bash
# Run in real-time mode (default)
./zig-out/bin/zindexer

# Run in historical mode
./zig-out/bin/zindexer --mode historical

# Customize ClickHouse connection
./zig-out/bin/zindexer --database-type clickhouse --database-url localhost:9000 --database-user default --database-password "" --database-name solana

# Use QuestDB instead
./zig-out/bin/zindexer --database-type questdb --database-url localhost:9000 --database-user admin --database-password "quest" --database-name solana

# Show help
./zig-out/bin/zindexer --help
```

### Command Line Options

- `-m, --mode <mode>`: Indexer mode (historical or realtime)
- `-r, --rpc-nodes <file>`: RPC nodes configuration file
- `-w, --ws-nodes <file>`: WebSocket nodes configuration file
- `-t, --database-type <type>`: Database type (clickhouse or questdb)
- `-c, --database-url <url>`: Database server URL
- `-u, --database-user <user>`: Database username
- `-p, --database-password <pass>`: Database password
- `-d, --database-name <db>`: Database name
- `-b, --batch-size <size>`: Batch size for historical indexing
- `--max-retries <count>`: Maximum retry attempts
- `--retry-delay <ms>`: Delay between retries in milliseconds

#### Legacy ClickHouse Options (for backward compatibility)

- `--clickhouse-url <url>`: ClickHouse server URL
- `--clickhouse-user <user>`: ClickHouse username
- `--clickhouse-password <pass>`: ClickHouse password
- `--clickhouse-database <db>`: ClickHouse database name

#### QuestDB Options

- `--questdb-url <url>`: QuestDB server URL
- `--questdb-user <user>`: QuestDB username
- `--questdb-password <pass>`: QuestDB password
- `--questdb-database <db>`: QuestDB database name
- `-h, --help`: Show help message

## Schema Setup

The schema can be automatically applied to your database instance using the included script:

### For ClickHouse

```bash
DB_TYPE=clickhouse CLICKHOUSE_URL="http://localhost:8123" ./scripts/apply_schema.sh
```

### For QuestDB

```bash
DB_TYPE=questdb QUESTDB_URL="http://localhost:9000" ./scripts/apply_schema.sh
```

## Architecture

ZIndexer is built with a modular architecture:

- **Core Indexer**: Manages connections to multiple networks and coordinates indexing
- **RPC Client**: Handles communication with SVM networks via HTTP and WebSocket
- **Database Abstraction Layer**: Provides a common interface for different database backends
  - **ClickHouse Client**: Manages data storage and retrieval in ClickHouse
  - **QuestDB Client**: Manages data storage and retrieval in QuestDB
- **Indexing Modules**:
  - Transaction Indexer: Processes transaction data
  - Instruction Indexer: Processes instruction data
  - Account Indexer: Tracks account changes
  - Token Indexer: Tracks token transfers and balances
  - DeFi Indexer: Tracks AMM and DeFi protocol activity
  - NFT Indexer: Tracks NFT mints, sales, and marketplace activity
  - Security Indexer: Monitors for suspicious activity

## Database Schema

ZIndexer creates several tables in ClickHouse:

- `transactions`: Basic transaction data
- `instructions`: Instruction data with program IDs
- `accounts`: Account state changes
- `account_activity`: Account usage statistics
- `token_transfers`: Token transfer events
- `token_accounts`: Token account balances
- `token_holders`: Token holder information
- `nft_mints`: NFT mint events
- `nft_sales`: NFT sale events
- `pool_swaps`: AMM swap events
- `liquidity_pools`: AMM pool information

## Continuous Integration & Deployment

ZIndexer uses GitHub Actions for CI/CD:

- **CI Workflow**: Automatically builds and tests the code on Ubuntu and macOS
- **Lint Workflow**: Checks code formatting using `zig fmt`
- **Release Workflow**: Creates binary releases when a new tag is pushed

Status badges:

![Build Status](https://github.com/openSVM/zindexer/workflows/ZIndexer%20CI/badge.svg)
![Lint Status](https://github.com/openSVM/zindexer/workflows/ZIndexer%20Lint/badge.svg)
![Release Status](https://github.com/openSVM/zindexer/workflows/ZIndexer%20Release/badge.svg)

## License

[MIT License](LICENSE)
