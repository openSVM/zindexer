const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const Uri = std.Uri;
const net = std.net;
const base64 = std.base64;
const crypto = std.crypto;
const mem = std.mem;
const fs = std.fs;
const tls = std.crypto.tls;
const json = std.json;

pub const RpcError = error{
    RequestFailed,
    InvalidResponse,
    ParseError,
    SlotNotFound,
    BlockNotFound,
    WebSocketError,
    SubscriptionError,
    NodesNotFound,
    InvalidWebSocketFrame,
    ConnectionClosed,
    TlsError,
    RateLimitExceeded,
    AuthenticationError,
    NetworkNotFound,
};

const NodeConfig = struct {
    uri: Uri,
    host: []const u8,
    path: []const u8,
    is_secure: bool,

    pub fn init(endpoint: []const u8) !NodeConfig {
        const uri = try Uri.parse(endpoint);
        const host = switch (uri.host.?) {
            .raw => |r| r,
            .percent_encoded => |p| p,
        };
        const path = switch (uri.path) {
            .raw => |r| r,
            .percent_encoded => |p| p,
        };
        return NodeConfig{
            .uri = uri,
            .host = host,
            .path = path,
            .is_secure = std.mem.eql(u8, uri.scheme, "https") or std.mem.eql(u8, uri.scheme, "wss"),
        };
    }
};

pub const Network = struct {
    name: []const u8,
    rpc_nodes: []NodeConfig,
    wss_nodes: []NodeConfig,
    current_rpc_index: usize,
    current_wss_index: usize,
    
    pub fn init(allocator: Allocator, name: []const u8, rpc_nodes: []NodeConfig, wss_nodes: []NodeConfig) !*Network {
        const network = try allocator.create(Network);
        network.* = .{
            .name = try allocator.dupe(u8, name),
            .rpc_nodes = rpc_nodes,
            .wss_nodes = wss_nodes,
            .current_rpc_index = 0,
            .current_wss_index = 0,
        };
        return network;
    }
    
    pub fn deinit(self: *Network, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.destroy(self);
    }
    
    pub fn getNextRpcNode(self: *Network) !NodeConfig {
        if (self.rpc_nodes.len == 0) return RpcError.NodesNotFound;
        const node = self.rpc_nodes[self.current_rpc_index];
        self.current_rpc_index = (self.current_rpc_index + 1) % self.rpc_nodes.len;
        return node;
    }
    
    pub fn getNextWsNode(self: *Network) !NodeConfig {
        if (self.wss_nodes.len == 0) return RpcError.NodesNotFound;
        const node = self.wss_nodes[self.current_wss_index];
        self.current_wss_index = (self.current_wss_index + 1) % self.wss_nodes.len;
        return node;
    }
};

pub const RpcClient = struct {
    allocator: Allocator,
    networks: std.StringHashMap(*Network),
    http_client: HttpClient,
    ws_clients: std.StringHashMap(*WebSocketClient),

    pub fn initFromFiles(allocator: Allocator, rpc_nodes_file: []const u8, wss_nodes_file: []const u8) !Self {
        // Load RPC nodes
        const rpc_file = try fs.cwd().openFile(rpc_nodes_file, .{});
        defer rpc_file.close();
        const rpc_content = try rpc_file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(rpc_content);
        var rpc_parsed = try json.parseFromSlice(json.Value, allocator, rpc_content, .{});
        defer rpc_parsed.deinit();
        
        // Load WebSocket nodes
        const wss_file = try fs.cwd().openFile(wss_nodes_file, .{});
        defer wss_file.close();
        const wss_content = try wss_file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(wss_content);
        var wss_parsed = try json.parseFromSlice(json.Value, allocator, wss_content, .{});
        defer wss_parsed.deinit();
        
        // Initialize HTTP client
        var http_client = try HttpClient.init(allocator, .{});
        errdefer http_client.deinit();
        
        // Initialize networks map
        var networks = std.StringHashMap(*Network).init(allocator);
        errdefer {
            var it = networks.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.*.deinit(allocator);
            }
            networks.deinit();
        }
        
        // Initialize WebSocket clients map
        var ws_clients = std.StringHashMap(*WebSocketClient).init(allocator);
        errdefer {
            var it = ws_clients.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.*.deinit();
                allocator.destroy(entry.value_ptr.*);
            }
            ws_clients.deinit();
        }
        
        // Process each network
        const rpc_networks = rpc_parsed.value.object.get("networks").?.array;
        const wss_networks = wss_parsed.value.object.get("networks").?.array;
        
        for (rpc_networks.items) |rpc_network| {
            const network_name = rpc_network.object.get("name").?.string;
            const rpc_nodes_json = rpc_network.object.get("nodes").?.array;
            
            // Find matching WebSocket network
            var wss_nodes_json: ?json.Array = null;
            for (wss_networks.items) |wss_network| {
                if (std.mem.eql(u8, wss_network.object.get("name").?.string, network_name)) {
                    wss_nodes_json = wss_network.object.get("nodes").?.array;
                    break;
                }
            }
            
            if (wss_nodes_json == null) {
                std.log.warn("No WebSocket nodes found for network: {s}", .{network_name});
                continue;
            }
            
            // Create node configs
            var rpc_nodes = try allocator.alloc(NodeConfig, rpc_nodes_json.items.len);
            errdefer allocator.free(rpc_nodes);
            
            var wss_nodes = try allocator.alloc(NodeConfig, wss_nodes_json.?.items.len);
            errdefer allocator.free(wss_nodes);
            
            for (rpc_nodes_json.items, 0..) |node, i| {
                rpc_nodes[i] = try NodeConfig.init(node.string);
            }
            
            for (wss_nodes_json.?.items, 0..) |node, i| {
                wss_nodes[i] = try NodeConfig.init(node.string);
            }
            
            // Create network
            const network = try Network.init(allocator, network_name, rpc_nodes, wss_nodes);
            try networks.put(network_name, network);
            
            // Create WebSocket client for this network
            var ws_client = try allocator.create(WebSocketClient);
            ws_client.* = WebSocketClient.init(allocator);
            try ws_clients.put(network_name, ws_client);
        }
        
        return Self{
            .allocator = allocator,
            .networks = networks,
            .http_client = http_client,
            .ws_clients = ws_clients,
        };
    }

    pub fn init(allocator: Allocator, rpc_url: []const u8) !Self {
        var rpc_nodes = try allocator.alloc(NodeConfig, 1);
        errdefer allocator.free(rpc_nodes);
        rpc_nodes[0] = try NodeConfig.init(rpc_url);

        const wss_nodes = try allocator.alloc(NodeConfig, 0);
        errdefer allocator.free(wss_nodes);

        var http_client = try HttpClient.init(allocator, .{});
        errdefer http_client.deinit();
        
        // Initialize networks map
        var networks = std.StringHashMap(*Network).init(allocator);
        
        // Create default network
        const network = try Network.init(allocator, "default", rpc_nodes, wss_nodes);
        try networks.put("default", network);
        
        // Initialize WebSocket clients map
        var ws_clients = std.StringHashMap(*WebSocketClient).init(allocator);
        
        // Create WebSocket client for default network
        var ws_client = try allocator.create(WebSocketClient);
        ws_client.* = WebSocketClient.init(allocator);
        try ws_clients.put("default", ws_client);

        return Self{
            .allocator = allocator,
            .networks = networks,
            .http_client = http_client,
            .ws_clients = ws_clients,
        };
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
        
        // Deinit all WebSocket clients
        var ws_it = self.ws_clients.iterator();
        while (ws_it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.ws_clients.deinit();
        
        // Deinit all networks
        var net_it = self.networks.iterator();
        while (net_it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.rpc_nodes);
            self.allocator.free(entry.value_ptr.*.wss_nodes);
            entry.value_ptr.*.deinit(self.allocator);
        }
        self.networks.deinit();
    }

    pub fn getNetwork(self: *Self, network_name: []const u8) !*Network {
        return self.networks.get(network_name) orelse return RpcError.NetworkNotFound;
    }

    pub fn getWebSocketClient(self: *Self, network_name: []const u8) !*WebSocketClient {
        return self.ws_clients.get(network_name) orelse return RpcError.NetworkNotFound;
    }

    pub fn subscribeSlots(self: *Self, network_name: []const u8, ctx: anytype, callback: WebSocketClient.Callback) !void {
        const network = try self.getNetwork(network_name);
        var ws_client = try self.getWebSocketClient(network_name);
        
        const node = try network.getNextWsNode();
        try ws_client.connect(node);
        try ws_client.subscribe(ctx, callback, "slotSubscribe");
    }

    pub fn subscribeTransaction(self: *Self, network_name: []const u8, ctx: anytype, callback: WebSocketClient.Callback) !void {
        const network = try self.getNetwork(network_name);
        var ws_client = try self.getWebSocketClient(network_name);
        
        const node = try network.getNextWsNode();
        try ws_client.connect(node);
        try ws_client.subscribe(ctx, callback, "transactionSubscribe");
    }

    pub fn getSlot(self: *Self, network_name: []const u8) !u64 {
        const network = try self.getNetwork(network_name);
        const params = "[]";
        const node = try network.getNextRpcNode();
        const response = try self.http_client.sendRequest(node, "getSlot", params);
        const result = response.object.get("result") orelse return RpcError.InvalidResponse;
        return @intCast(result.integer);
    }

    pub fn getBlock(self: *Self, network_name: []const u8, slot: u64) !json.Value {
        const network = try self.getNetwork(network_name);
        const params = try std.fmt.allocPrint(
            self.allocator,
            "[{d}, {{\"encoding\": \"json\", \"maxSupportedTransactionVersion\": 0, \"transactionDetails\": \"full\", \"rewards\": false}}]",
            .{slot},
        );
        defer self.allocator.free(params);

        const node = try network.getNextRpcNode();
        const response = try self.http_client.sendRequest(node, "getBlock", params);
        const result = response.object.get("result") orelse return RpcError.BlockNotFound;
        return result;
    }

    pub fn getNetworkNames(self: *Self, allocator: Allocator) ![][]const u8 {
        var names = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (names.items) |name| {
                allocator.free(name);
            }
            names.deinit();
        }
        
        var it = self.networks.keyIterator();
        while (it.next()) |key| {
            try names.append(try allocator.dupe(u8, key.*));
        }
        
        return names.toOwnedSlice();
    }

    const Self = @This();
};

pub const BlockInfo = struct {
    blockhash: []const u8,
    previous_blockhash: []const u8,
    parent_slot: u64,
    transactions: []json.Value,
    block_time: ?i64,
    block_height: ?u64,

    pub fn fromJson(allocator: Allocator, value: json.Value) !BlockInfo {
        const block = value.object;
        return BlockInfo{
            .blockhash = try allocator.dupe(u8, block.get("blockhash").?.string),
            .previous_blockhash = try allocator.dupe(u8, block.get("previousBlockhash").?.string),
            .parent_slot = @intCast(block.get("parentSlot").?.integer),
            .transactions = try allocator.dupe(json.Value, block.get("transactions").?.array.items),
            .block_time = if (block.get("blockTime")) |bt| @intCast(bt.integer) else null,
            .block_height = if (block.get("blockHeight")) |bh| @intCast(bh.integer) else null,
        };
    }

    pub fn deinit(self: *const BlockInfo, allocator: Allocator) void {
        allocator.free(self.blockhash);
        allocator.free(self.previous_blockhash);
        allocator.free(self.transactions);
    }
};

pub const WebSocketClient = struct {
    pub const Callback = *const fn (*anyopaque, *WebSocketClient, json.Value) void;

    allocator: Allocator,
    tcp_stream: ?net.Stream,
    thread: ?std.Thread,
    subscription_id: ?u64,
    callback_ctx: ?*anyopaque,
    callback: ?Callback,
    node: ?NodeConfig,
    should_stop: bool,
    tls_client: ?*tls.Client,
    ca_bundle: ?*std.crypto.Certificate.Bundle,

    pub fn init(allocator: Allocator) WebSocketClient {
        return .{
            .allocator = allocator,
            .tcp_stream = null,
            .thread = null,
            .subscription_id = null,
            .callback_ctx = null,
            .callback = null,
            .node = null,
            .should_stop = false,
            .tls_client = null,
            .ca_bundle = null,
        };
    }

    pub fn deinit(self: *WebSocketClient) void {
        self.should_stop = true;
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
        if (self.tcp_stream) |*stream| {
            stream.close();
            self.tcp_stream = null;
        }
        if (self.tls_client) |client| {
            self.allocator.destroy(client);
            self.tls_client = null;
        }
        if (self.ca_bundle) |bundle| {
            bundle.deinit(self.allocator);
            self.allocator.destroy(bundle);
            self.ca_bundle = null;
        }
        self.callback_ctx = null;
    }

    pub fn connect(self: *WebSocketClient, node: NodeConfig) !void {
        if (self.tcp_stream) |*stream| {
            stream.close();
            self.tcp_stream = null;
        }
        if (self.tls_client) |client| {
            self.allocator.destroy(client);
            self.tls_client = null;
        }
        if (self.ca_bundle) |bundle| {
            bundle.deinit(self.allocator);
            self.allocator.destroy(bundle);
            self.ca_bundle = null;
        }

        // Connect using IPv4
        const port = node.uri.port orelse if (node.is_secure) @as(u16, 443) else @as(u16, 80);
        const address = try std.net.Address.parseIp(node.host, port);
        var tcp_stream = try std.net.tcpConnectToAddress(address);

        errdefer tcp_stream.close();

        self.tcp_stream = tcp_stream;

        if (node.is_secure) {
            std.log.info("Setting up TLS connection for host: {s}", .{node.host});
            std.log.warn("TLS connections are not supported yet, skipping secure connection for {s}", .{node.host});
            return RpcError.TlsError;
        }

        // Generate WebSocket key
        var key_bytes: [16]u8 = undefined;
        crypto.random.bytes(&key_bytes);
        var key_base64: [base64.standard.Encoder.calcSize(16)]u8 = undefined;
        const key = base64.standard.Encoder.encode(&key_base64, &key_bytes);

        // Send handshake
        const handshake = try std.fmt.allocPrint(
            self.allocator,
            \\GET {s} HTTP/1.1\r\n\
            \\Host: {s}\r\n\
            \\Upgrade: websocket\r\n\
            \\Connection: Upgrade\r\n\
            \\Sec-WebSocket-Key: {s}\r\n\
            \\Sec-WebSocket-Version: 13\r\n\
            \\\r\n
        ,
            .{ node.path, node.host, key },
        );
        defer self.allocator.free(handshake);

        try self.tcp_stream.?.writeAll(handshake);

        // Verify handshake response
        var buffer: [1024]u8 = undefined;
        std.log.info("Waiting for handshake response...", .{});
        const response = try self.tcp_stream.?.reader().readUntilDelimiter(&buffer, '\n');
        std.log.info("Got handshake response: {s}", .{response});
        if (!std.mem.startsWith(u8, response, "HTTP/1.1 101")) {
            return RpcError.WebSocketError;
        }

        // Skip remaining headers
        while (true) {
            const line = try self.tcp_stream.?.reader().readUntilDelimiter(&buffer, '\n');
            if (line.len <= 2) break;
        }

        self.node = node;
        self.should_stop = false;
    }

    pub fn subscribe(self: *WebSocketClient, ctx: anytype, callback: Callback, subscription: []const u8) !void {
        if (self.tcp_stream == null) return RpcError.WebSocketError;

        // Store callback and context
        self.callback = callback;
        self.callback_ctx = @ptrCast(ctx);

        // Send subscription request
        const msg = try std.fmt.allocPrint(
            self.allocator,
            \\{{"jsonrpc": "2.0", "id": 1, "method": "{s}", "params": [{{"encoding": "json", "commitment": "confirmed"}}]}}
        ,
            .{subscription},
        );
        defer self.allocator.free(msg);

        try self.sendFrame(msg);

        // Start listener thread
        self.thread = try std.Thread.spawn(.{}, struct {
            fn run(client: *WebSocketClient) !void {
                try client.listen();
            }
        }.run, .{self});
    }

    fn sendFrame(self: *WebSocketClient, data: []const u8) !void {
        const frame_len = 2 + data.len;
        var frame = try self.allocator.alloc(u8, frame_len);
        defer self.allocator.free(frame);

        frame[0] = 0x81; // FIN + Text frame
        frame[1] = @intCast(data.len);
        @memcpy(frame[2..], data);

        try self.tcp_stream.?.writeAll(frame);
    }

    fn listen(self: *WebSocketClient) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var buffer: [1024 * 1024]u8 = undefined;
        while (!self.should_stop) {
            const frame = try self.readFrame(&buffer);
            if (frame.opcode == 0x8) return; // Close frame

            if (frame.payload_len > 0) {
                var parsed = try json.parseFromSlice(
                    json.Value,
                    arena.allocator(),
                    frame.payload[0..frame.payload_len],
                    .{},
                );
                defer parsed.deinit();

                if (self.callback) |cb| {
                    if (self.callback_ctx) |ctx| {
                        cb(ctx, self, parsed.value);
                    }
                }
            }

            if (!frame.fin) continue; // More fragments coming
        }
    }

    const Frame = struct {
        fin: bool,
        opcode: u8,
        payload: []u8,
        payload_len: usize,
    };

    fn readFrame(self: *WebSocketClient, buffer: []u8) !Frame {
        // Read header
        var header_buf: [2]u8 = undefined;
        _ = try self.tcp_stream.?.read(&header_buf);

        const fin = (header_buf[0] & 0x80) != 0;
        const opcode = header_buf[0] & 0x0F;
        const masked = (header_buf[1] & 0x80) != 0;
        var payload_len: u64 = header_buf[1] & 0x7F;

        // Handle extended payload length
        if (payload_len == 126) {
            var ext_len_buf: [2]u8 = undefined;
            _ = try self.tcp_stream.?.read(&ext_len_buf);
            payload_len = (@as(u64, ext_len_buf[0]) << 8) | ext_len_buf[1];
        } else if (payload_len == 127) {
            var ext_len_buf: [8]u8 = undefined;
            _ = try self.tcp_stream.?.read(&ext_len_buf);
            payload_len = 0;
            for (0..8) |i| {
                payload_len = (payload_len << 8) | ext_len_buf[i];
            }
        }

        // Read masking key if present
        var mask: [4]u8 = undefined;
        if (masked) {
            _ = try self.tcp_stream.?.read(&mask);
        }

        // Read and unmask payload
        if (payload_len > buffer.len) return RpcError.InvalidWebSocketFrame;

        const payload = buffer[0..payload_len];
        var total_read: usize = 0;
        while (total_read < payload_len) {
            const bytes = try self.tcp_stream.?.read(payload[total_read..]);
            if (bytes == 0) return RpcError.ConnectionClosed;
            total_read += bytes;
        }

        if (masked) {
            for (payload[0..total_read], 0..) |byte, i| {
                payload[i] = byte ^ mask[i % 4];
            }
        }

        return Frame{
            .fin = fin,
            .opcode = opcode,
            .payload = payload,
            .payload_len = total_read,
        };
    }
};

pub const HttpClient = struct {
    client: http.Client,
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    retry_config: RetryConfig,

    const RetryConfig = struct {
        max_retries: u32 = 3,
        base_delay_ms: u32 = 1000,
        max_delay_ms: u32 = 10000,
    };

    pub fn init(allocator: Allocator, retry_config: RetryConfig) !HttpClient {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        var client = http.Client{
            .allocator = allocator,
        };
        errdefer client.deinit();

        return HttpClient{
            .client = client,
            .allocator = allocator,
            .arena = arena,
            .retry_config = retry_config,
        };
    }

    pub fn deinit(self: *HttpClient) void {
        self.client.deinit();
        self.arena.deinit();
    }

    pub fn sendRequest(
        self: *HttpClient,
        node: NodeConfig,
        method: []const u8,
        params: []const u8,
    ) !json.Value {
        const body = try std.fmt.allocPrint(
            self.arena.allocator(),
            \\{{"jsonrpc": "2.0", "id": 1, "method": "{s}", "params": {s}}}
        ,
            .{ method, params },
        );

        var retry_count: u32 = 0;
        var delay_ms: u32 = self.retry_config.base_delay_ms;

        while (retry_count < self.retry_config.max_retries) : (retry_count += 1) {
            // Prepare headers
            var extra_headers = try std.ArrayList(http.Header).initCapacity(
                self.arena.allocator(),
                4,
            );
            try extra_headers.append(.{ .name = "Accept", .value = "application/json" });
            try extra_headers.append(.{ .name = "Host", .value = node.host });
            try extra_headers.append(.{ .name = "Content-Type", .value = "application/json" });
            try extra_headers.append(.{ .name = "Connection", .value = "keep-alive" });

            var buffer: [1024]u8 = undefined;
            var req = try self.client.open(.POST, node.uri, .{
                .server_header_buffer = &buffer,
                .extra_headers = extra_headers.items,
            });
            defer req.deinit();

            req.transfer_encoding = .{ .content_length = body.len };
            req.headers.content_type = .{ .override = "application/json" };
            req.headers.user_agent = .{ .override = "solana-indexer/1.0" };
            req.headers.host = .{ .override = node.host };

            try req.send();
            try req.writer().writeAll(body);
            try req.finish();

            // Handle response
            switch (req.response.status) {
                .ok => {
                    const response_body = try req.reader().readAllAlloc(
                        self.arena.allocator(),
                        10 * 1024 * 1024,
                    );
                    var parsed = try json.parseFromSlice(
                        json.Value,
                        self.arena.allocator(),
                        response_body,
                        .{},
                    );
                    defer parsed.deinit();

                    if (parsed.value.object.get("error")) |error_obj| {
                        std.log.err("RPC Error: {any}", .{error_obj});
                        if (retry_count + 1 < self.retry_config.max_retries) {
                            std.time.sleep(delay_ms * std.time.ns_per_ms);
                            delay_ms = @min(
                                delay_ms * 2,
                                self.retry_config.max_delay_ms,
                            );
                            continue;
                        }
                        return RpcError.RequestFailed;
                    }

                    return parsed.value;
                },
                .forbidden, .unauthorized => return RpcError.AuthenticationError,
                .too_many_requests => {
                    if (retry_count + 1 < self.retry_config.max_retries) {
                        std.time.sleep(delay_ms * std.time.ns_per_ms);
                        delay_ms = @min(
                            delay_ms * 2,
                            self.retry_config.max_delay_ms,
                        );
                        continue;
                    }
                    return RpcError.RateLimitExceeded;
                },
                else => {
                    if (retry_count + 1 < self.retry_config.max_retries) {
                        std.time.sleep(delay_ms * std.time.ns_per_ms);
                        delay_ms = @min(
                            delay_ms * 2,
                            self.retry_config.max_delay_ms,
                        );
                        continue;
                    }
                    return RpcError.RequestFailed;
                },
            }
        }

        return RpcError.RequestFailed;
    }
};