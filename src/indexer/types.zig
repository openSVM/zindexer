const std = @import("std");

// Token program constants
pub const TOKEN_PROGRAM_ID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
pub const ASSOCIATED_TOKEN_PROGRAM_ID = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL";

// NFT program constants
pub const METADATA_PROGRAM_ID = "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s";
pub const CANDY_MACHINE_PROGRAM_ID = "cndy3Z4yapfJBmL3ShUp5exZKqR3z33thTzeNMm2gRZ";
pub const AUCTION_HOUSE_PROGRAM_ID = "hausS13jsjafwWwGqZTUQRmWyvyxn9EQpqMwV1PBBmk";
pub const MAGIC_EDEN_PROGRAM_ID = "M2mx93ekt1fmXSVkTrUL9xVFHkmME8HTUi5Cyc5aF7K";

// DeFi protocol constants
pub const ORCA_PROGRAM_ID = "9W959DqEETiGZocYWCQPaJ6sBmUzgfxXfqGeTEdp3aQP";
pub const RAYDIUM_PROGRAM_ID = "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8";
pub const MARINADE_PROGRAM_ID = "MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD";
pub const SOLEND_PROGRAM_ID = "So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo";
pub const MANGO_PROGRAM_ID = "mv3ekLzLbnVPNxjSKvqBpU3ZeZXPQdEC3bp5MDEBG68";
pub const DRIFT_PROGRAM_ID = "dRiftyHA39MWEi3m9aunc5MzRF1JYuBsbn6VPcn33UH";

// DeFi instruction types
pub const DefiProtocol = enum {
    Orca,
    Raydium,
    Marinade,
    Solend,
    Mango,
    Drift,
    Unknown,
    
    pub fn fromProgramId(program_id: []const u8) DefiProtocol {
        if (std.mem.eql(u8, program_id, ORCA_PROGRAM_ID)) return .Orca;
        if (std.mem.eql(u8, program_id, RAYDIUM_PROGRAM_ID)) return .Raydium;
        if (std.mem.eql(u8, program_id, MARINADE_PROGRAM_ID)) return .Marinade;
        if (std.mem.eql(u8, program_id, SOLEND_PROGRAM_ID)) return .Solend;
        if (std.mem.eql(u8, program_id, MANGO_PROGRAM_ID)) return .Mango;
        if (std.mem.eql(u8, program_id, DRIFT_PROGRAM_ID)) return .Drift;
        return .Unknown;
    }
};

// NFT instruction types
pub const NftInstruction = enum {
    // Metadata program instructions
    CreateMetadataAccount,
    UpdateMetadataAccount,
    CreateMasterEdition,
    UpdatePrimarySaleHappened,
    VerifyCollection,
    SetAndVerifyCollection,
    // Candy Machine instructions
    InitializeCandyMachine,
    MintNFT,
    UpdateCandyMachine,
    // Auction House instructions
    CreateAuctionHouse,
    CreateListing,
    CancelListing,
    ExecuteSale,
    CreateBid,
    CancelBid,
    Unknown,
    
    pub fn fromInstruction(program_id: []const u8, data: []const u8) NftInstruction {
        if (std.mem.eql(u8, program_id, METADATA_PROGRAM_ID)) {
            if (data.len == 0) return .Unknown;
            return switch (data[0]) {
                0 => .CreateMetadataAccount,
                1 => .UpdateMetadataAccount,
                2 => .CreateMasterEdition,
                3 => .UpdatePrimarySaleHappened,
                4 => .VerifyCollection,
                5 => .SetAndVerifyCollection,
                else => .Unknown,
            };
        } else if (std.mem.eql(u8, program_id, CANDY_MACHINE_PROGRAM_ID)) {
            if (data.len == 0) return .Unknown;
            return switch (data[0]) {
                0 => .InitializeCandyMachine,
                1 => .MintNFT,
                2 => .UpdateCandyMachine,
                else => .Unknown,
            };
        } else if (std.mem.eql(u8, program_id, AUCTION_HOUSE_PROGRAM_ID)) {
            if (data.len == 0) return .Unknown;
            return switch (data[0]) {
                0 => .CreateAuctionHouse,
                1 => .CreateListing,
                2 => .CancelListing,
                3 => .ExecuteSale,
                4 => .CreateBid,
                5 => .CancelBid,
                else => .Unknown,
            };
        }
        return .Unknown;
    }
};

// Security event types
pub const SecurityEventType = enum {
    // Exploit types
    FlashLoanAttack,
    PriceManipulation,
    ReentrancyAttack,
    LogicBug,
    // Suspicious activity
    LargeTransfer,
    RapidLiquidation,
    UnusualTrading,
    ContractUpgrade,
    // Access control
    UnauthorizedAccess,
    PrivilegeEscalation,
    AccountCompromise,
    // Protocol specific
    InvalidOracle,
    PoolImbalance,
    ExcessiveSlippage,
    Unknown,
};

// Token instruction types
pub const TokenInstruction = enum {
    InitializeMint,
    InitializeAccount,
    Transfer,
    Approve,
    Revoke,
    SetAuthority,
    MintTo,
    Burn,
    CloseAccount,
    FreezeAccount,
    ThawAccount,
    TransferChecked,
    ApproveChecked,
    MintToChecked,
    BurnChecked,
    InitializeMultisig,
    SyncNative,
    CreateAssociatedAccount,
    Unknown,
    
    pub fn fromInstruction(program_id: []const u8, data: []const u8) TokenInstruction {
        if (!std.mem.eql(u8, program_id, TOKEN_PROGRAM_ID) and 
            !std.mem.eql(u8, program_id, ASSOCIATED_TOKEN_PROGRAM_ID)) {
            return .Unknown;
        }
        
        if (data.len == 0) return .Unknown;
        
        return switch (data[0]) {
            0 => .InitializeMint,
            1 => .InitializeAccount,
            2 => .InitializeMultisig,
            3 => .Transfer,
            4 => .Approve,
            5 => .Revoke,
            6 => .SetAuthority,
            7 => .MintTo,
            8 => .Burn,
            9 => .CloseAccount,
            10 => .FreezeAccount,
            11 => .ThawAccount,
            12 => .TransferChecked,
            13 => .ApproveChecked,
            14 => .MintToChecked,
            15 => .BurnChecked,
            17 => .SyncNative,
            else => .Unknown,
        };
    }
};
