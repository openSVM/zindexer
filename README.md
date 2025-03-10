# Zindexer: Multi-Network Solana Validator Monitor

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Language](https://img.shields.io/badge/language-Zig-orange.svg)

A high-performance, memory-efficient Solana validator monitoring system written in Zig. Designed for high-throughput, low-latency block ingestion and real-time analytics across multiple Solana Virtual Machine (SVM) networks simultaneously.

## Features

- 🌐 **Multi-Network Support**: Simultaneously index and monitor multiple Solana networks (Mainnet, Devnet, Testnet)
- 🔄 **Real-time Data Processing**: Stream transactions, blocks, and account updates in real-time
- 📊 **Comprehensive Indexing**: Track transactions, instructions, account changes, token transfers, and more
- 💾 **ClickHouse Integration**: Store and analyze data using the high-performance ClickHouse database
- 🔍 **DeFi & NFT Tracking**: Specialized indexing for DeFi protocols and NFT marketplaces
- 🛡️ **Security Monitoring**: Detect suspicious activities and potential security threats
- ⚡ **High Performance**: Zero-copy parsing and efficient memory management for blazing-fast indexing

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Solana Network │     │  Solana Network │     │  Solana Network │
│    (Mainnet)    │     │    (Devnet)     │     │    (Testnet)    │
│                 │     │                 │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                        WebSocket Clients                        │
│                                                                 │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                         Parser Engine                           │
│                                                                 │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                       ClickHouse Storage                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Model

Zindexer stores the following data types:

1. **Blocks**: Basic block information including slot, blockhash, leader, etc.
2. **Transactions**: Transaction details including signatures, status, fees, etc.
3. **Instructions**: Program instructions with program IDs and parsed data
4. **Accounts**: Account state changes and balance updates
5. **Tokens**: Token transfers, mints, burns, and balance changes
6. **NFTs**: NFT mints, transfers, sales, and metadata
7. **DeFi**: Protocol-specific events for various DeFi platforms
8. **Security**: Suspicious activities and potential security threats

## Getting Started

### Prerequisites

- Zig 0.11.0 or later
- ClickHouse server (local or remote)
- Access to Solana RPC nodes

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/zindexer.git
   cd zindexer
   ```

2. Build the project:
   ```bash
   zig build -Drelease-fast
   ```

3. Configure your RPC nodes:
   - Edit `src/rpc_nodes.json` to add your RPC endpoints
   - Edit `src/ws_nodes.json` to add your WebSocket endpoints

4. Set up ClickHouse:
   ```bash
   ./scripts/apply_schema.sh
   ```

### Running the Indexer

```bash
# Set environment variables (optional)
export CLICKHOUSE_URL="http://localhost:8123"
export CLICKHOUSE_USER="default"
export CLICKHOUSE_PASS=""
export CLICKHOUSE_DB="solana"

# Run the indexer
./zig-out/bin/zindexer
```

## Configuration

### RPC Nodes Configuration

The `rpc_nodes.json` file defines the HTTP RPC endpoints for each network:

```json
{
  "networks": [
    {
      "name": "mainnet",
      "nodes": [
        "https://api.mainnet-beta.solana.com",
        "https://solana-api.projectserum.com"
      ]
    },
    {
      "name": "devnet",
      "nodes": [
        "https://api.devnet.solana.com"
      ]
    }
  ]
}
```

### WebSocket Nodes Configuration

The `ws_nodes.json` file defines the WebSocket endpoints for each network:

```json
{
  "networks": [
    {
      "name": "mainnet",
      "nodes": [
        "wss://api.mainnet-beta.solana.com",
        "wss://solana-api.projectserum.com"
      ]
    },
    {
      "name": "devnet",
      "nodes": [
        "wss://api.devnet.solana.com"
      ]
    }
  ]
}
```

## Database Schema

Zindexer creates the following tables in ClickHouse:

- `blocks`: Block-level information
- `transactions`: Transaction details
- `instructions`: Program instructions
- `accounts`: Account state changes
- `program_executions`: Program execution statistics
- `account_activity`: Account activity metrics
- Various token, NFT, and DeFi-specific tables

## Use Cases

1. **Validator Monitoring**
   - Track validator performance across multiple networks
   - Monitor block production and transaction processing
   - Analyze network health and performance

2. **DeFi Analytics**
   - Track liquidity and volume across DEXes
   - Monitor lending protocols and yield farms
   - Analyze token flows and price movements

3. **NFT Market Analysis**
   - Track NFT sales and transfers
   - Monitor marketplace activity
   - Analyze collection performance

4. **Security Monitoring**
   - Detect suspicious transactions
   - Monitor for potential exploits
   - Track large fund movements

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.