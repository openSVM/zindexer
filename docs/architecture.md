# ZIndexer Architecture

## Overview

ZIndexer is designed to efficiently index and monitor multiple Solana Virtual Machine (SVM) networks simultaneously. The architecture follows a modular approach with clear separation of concerns between network connectivity, data processing, and storage.

## System Components

### 1. RPC Client Layer

The RPC client layer manages connections to multiple Solana networks through both HTTP RPC and WebSocket endpoints. It handles:

- Connection management
- Automatic reconnection with exponential backoff
- Load balancing across multiple nodes per network
- Subscription management for real-time data

### 2. Data Processing Layer

The data processing layer parses and processes blockchain data:

- Transaction parsing
- Instruction decoding
- Account state tracking
- Token transfer detection
- DeFi and NFT event recognition
- Security anomaly detection

### 3. Storage Layer

The storage layer persists processed data to ClickHouse:

- Efficient batch inserts
- Schema management
- Query optimization
- Data retention policies

## Data Flow

```
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│                           SOLANA BLOCKCHAIN NETWORKS                      │
│                                                                           │
├───────────────┬───────────────────────────────┬───────────────────────────┤
│   MAINNET     │            DEVNET             │          TESTNET          │
└───────┬───────┴─────────────┬─────────────────┴─────────────┬─────────────┘
        │                     │                               │
        ▼                     ▼                               ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│                              RPC CLIENT LAYER                             │
│                                                                           │
├───────────────┬───────────────────────────────┬───────────────────────────┤
│  HTTP Client  │       WebSocket Client        │    Connection Manager     │
└───────┬───────┴─────────────┬─────────────────┴─────────────┬─────────────┘
        │                     │                               │
        └─────────────────────┼───────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│                           DATA PROCESSING LAYER                           │
│                                                                           │
├───────────────┬───────────────────────────────┬───────────────────────────┤
│ Transaction   │      Instruction              │      Account              │
│ Processor     │      Processor                │      Processor            │
├───────────────┼───────────────────────────────┼───────────────────────────┤
│ Token         │      DeFi                     │      NFT                  │
│ Processor     │      Processor                │      Processor            │
├───────────────┴───────────────────────────────┴───────────────────────────┤
│                        Security Processor                                 │
└───────────────────────────────┬───────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│                              STORAGE LAYER                                │
│                                                                           │
├───────────────┬───────────────────────────────┬───────────────────────────┤
│ Database      │      Schema                   │      Query                │
│ Client        │      Manager                  │      Optimizer            │
├───────────────┴───────────────────────────────┴───────────────────────────┤
│       ClickHouse Client   |         QuestDB Client                        │
└───────────────────────────────────────────────────────────────────────────┘
```

## Multi-Network Processing

ZIndexer processes data from multiple networks in parallel:

```
                      ┌─────────────────┐
                      │                 │
                      │  Configuration  │
                      │                 │
                      └────────┬────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                      Network Registry                       │
│                                                             │
└───────┬─────────────────┬──────────────────┬───────────────┘
        │                 │                  │
        ▼                 ▼                  ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│               │ │               │ │               │
│    Mainnet    │ │    Devnet     │ │    Testnet    │
│    Indexer    │ │    Indexer    │ │    Indexer    │
│               │ │               │ │               │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        │                 │                 │
        ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                     ClickHouse Database                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Class Diagram

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  RpcClient    │     │  WebSocket    │     │  HttpClient   │
├───────────────┤     ├───────────────┤     ├───────────────┤
│ networks      │◄────┤ allocator     │     │ client        │
│ http_client   │     │ tcp_stream    │     │ allocator     │
│ ws_clients    │     │ thread        │     │ arena         │
├───────────────┤     │ subscription  │     │ retry_config  │
│ init()        │     ├───────────────┤     ├───────────────┤
│ deinit()      │     │ init()        │     │ init()        │
│ getNetwork()  │     │ deinit()      │     │ deinit()      │
│ subscribe()   │     │ connect()     │     │ sendRequest() │
└───────┬───────┘     │ subscribe()   │     └───────────────┘
        │             └───────────────┘
        │
        │
        ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  Indexer      │     │  BatchProc    │     │  ClickHouse   │
├───────────────┤     ├───────────────┤     ├───────────────┤
│ allocator     │     │ allocator     │     │ allocator     │
│ config        │     │ batch         │     │ url           │
│ rpc_client    │     │ network_name  │     │ user          │
│ db_client     │     │ db_client     │     │ password      │
├───────────────┤     ├───────────────┤     │ database      │
│ init()        │     │ init()        │     ├───────────────┤
│ deinit()      │     │ deinit()      │     │ init()        │
│ start()       │     │ addTx()       │     │ deinit()      │
│ processSlot() │     │ processBatch()│     │ executeQuery()│
└───────────────┘     └───────────────┘     │ createTables()│
                                            └───────────────┘
```

## Network Subscription Flow

1. The application loads network configurations from JSON files
2. For each network, a dedicated BatchProcessor is created
3. Each BatchProcessor subscribes to its network's transaction stream
4. Transactions are processed in batches of 100
5. Processed data is stored in ClickHouse with network identification
6. Statistics are tracked per network

## Error Handling

ZIndexer implements robust error handling:

1. **Connection Failures**: Automatic reconnection with exponential backoff
2. **Processing Errors**: Isolated to prevent cascading failures
3. **Database Errors**: Fallback to logging-only mode
4. **Rate Limiting**: Intelligent request throttling
5. **Timeout Protection**: Graceful handling of unresponsive nodes

## Performance Considerations

1. **Memory Efficiency**:
   - Arena allocators for batch processing
   - Zero-copy parsing where possible
   - Efficient buffer reuse

2. **CPU Optimization**:
   - Parallel processing across networks
   - Batch inserts to reduce database overhead
   - Efficient JSON parsing

3. **Network Optimization**:
   - Connection pooling
   - Load balancing across multiple nodes
   - Efficient binary protocols

## Scalability

ZIndexer can scale horizontally by:

1. Adding more RPC nodes per network
2. Distributing network processing across multiple instances
3. Scaling ClickHouse storage with sharding and replication
