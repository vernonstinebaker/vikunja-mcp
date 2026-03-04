const std = @import("std");
const Client = @import("client").Client;

/// MCP Protocol Version
pub const PROTOCOL_VERSION = "2024-11-05";

/// MCP Server — stdio JSON-RPC 2.0 message loop.
///
/// Tool handlers receive an arena allocator (freed after each message) and
/// the live HTTP client. They return a caller-owned JSON string.
pub const Server = struct {
    allocator: std.mem.Allocator,
    client: Client,
    tools: std.ArrayList(Tool),

    /// A registered MCP tool.
    pub const Tool = struct {
        name: []const u8,
        description: []const u8,
        /// Must be a valid JSON Schema object string.
        input_schema: []const u8,
        /// Returns a caller-owned JSON string (any valid JSON value).
        handler: *const fn (arena: std.mem.Allocator, client: *Client, params: std.json.Value) anyerror![]const u8,
    };

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8, token: []const u8) !Server {
        return .{
            .allocator = allocator,
            .client = Client.init(allocator, base_url, token),
            .tools = .empty,
        };
    }

    pub fn deinit(self: *Server) void {
        self.client.deinit();
        self.tools.deinit(self.allocator);
    }

    pub fn registerTools(self: *Server, tools: []const Tool) !void {
        try self.tools.appendSlice(self.allocator, tools);
    }

    /// Run until EOF on stdin.
    pub fn run(self: *Server) !void {
        // 64 KB read buffer for stdin — sufficient for large JSON-RPC messages.
        var stdin_buf: [65536]u8 = undefined;
        var stdin_file_reader = std.fs.File.stdin().readerStreaming(&stdin_buf);
        const stdin_reader = &stdin_file_reader.interface;

        // 4 KB write buffer for stdout.
        var stdout_buf: [4096]u8 = undefined;
        var stdout_file_writer = std.fs.File.stdout().writerStreaming(&stdout_buf);
        const stdout_writer = &stdout_file_writer.interface;

        while (try stdin_reader.takeDelimiter('\n')) |line| {
            // Each message gets its own arena; freed after the response is sent.
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const aa = arena.allocator();

            const response = self.handleMessage(aa, line) catch |err| blk: {
                std.log.err("handleMessage error: {}", .{err});
                break :blk null;
            };

            if (response) |r| {
                try stdout_writer.writeAll(r);
                try stdout_writer.writeByte('\n');
                try stdout_writer.flush();
            }
        }
    }

    /// Handle one JSON-RPC message. Returns arena-owned response string or null
    /// for notifications (no id) or unparseable input.
    fn handleMessage(self: *Server, arena: std.mem.Allocator, line: []const u8) !?[]const u8 {
        const parsed = std.json.parseFromSlice(std.json.Value, arena, line, .{}) catch |err| {
            std.log.err("JSON parse error: {}", .{err});
            // Per JSON-RPC 2.0 §5: parse errors should return -32700 with id=null.
            return try std.fmt.allocPrint(arena,
                \\{{"jsonrpc":"2.0","id":null,"error":{{"code":-32700,"message":"Parse error"}}}}
            , .{});
        };

        const msg = parsed.value;
        if (msg != .object) return null;

        // Notifications have no "id" field; do not respond to them.
        const id_val = msg.object.get("id") orelse return null;

        const method_val = msg.object.get("method") orelse return null;
        if (method_val != .string) return null;
        const method = method_val.string;

        const id_str = try jsonValueToString(arena, id_val);

        if (std.mem.eql(u8, method, "initialize")) {
            return try self.handleInitialize(arena, id_str);
        }

        if (std.mem.eql(u8, method, "initialized")) {
            // Notification with id is unusual; treat as no-op (no response).
            return null;
        }

        if (std.mem.eql(u8, method, "tools/list")) {
            return try self.handleToolsList(arena, id_str);
        }

        if (std.mem.eql(u8, method, "tools/call")) {
            const params = msg.object.get("params") orelse .null;
            return try self.handleToolCall(arena, id_str, params);
        }

        // Unknown method
        return try std.fmt.allocPrint(arena,
            \\{{"jsonrpc":"2.0","id":{s},"error":{{"code":-32601,"message":"Method not found"}}}}
        , .{id_str});
    }

    fn handleInitialize(self: *Server, arena: std.mem.Allocator, id: []const u8) ![]const u8 {
        _ = self;
        return std.fmt.allocPrint(arena,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"protocolVersion":"{s}","capabilities":{{"tools":{{}}}},"serverInfo":{{"name":"vikunja-mcp","version":"0.1.0"}}}}}}
        , .{ id, PROTOCOL_VERSION });
    }

    fn handleToolsList(self: *Server, arena: std.mem.Allocator, id: []const u8) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;
        const w = buf.writer(arena);

        try w.print("{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{{\"tools\":[", .{id});

        for (self.tools.items, 0..) |tool, i| {
            if (i > 0) try w.writeByte(',');
            // description may contain quotes — JSON-encode it safely.
            const desc_json = try std.json.Stringify.valueAlloc(arena, tool.description, .{});

            try w.print(
                "{{\"name\":\"{s}\",\"description\":{s},\"inputSchema\":{s}}}",
                .{ tool.name, desc_json, tool.input_schema },
            );
        }

        try w.writeAll("]}}");
        return buf.toOwnedSlice(arena);
    }

    fn handleToolCall(self: *Server, arena: std.mem.Allocator, id: []const u8, params: std.json.Value) ![]const u8 {
        // Safely extract tool name.
        const name: []const u8 = blk: {
            if (params != .object) break :blk "";
            const name_val = params.object.get("name") orelse break :blk "";
            if (name_val != .string) break :blk "";
            break :blk name_val.string;
        };

        const arguments: std.json.Value = blk: {
            if (params != .object) break :blk .null;
            break :blk params.object.get("arguments") orelse .null;
        };

        for (self.tools.items) |tool| {
            if (!std.mem.eql(u8, tool.name, name)) continue;

            const result = tool.handler(arena, &self.client, arguments) catch |err| {
                const err_str = try jsonEscapeString(arena, @errorName(err));
                return std.fmt.allocPrint(arena,
                    \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":{s}}}],"isError":true}}}}
                , .{ id, err_str });
            };

            // result is already valid JSON — wrap it as a text content item.
            const result_str = try jsonEscapeString(arena, result);
            return std.fmt.allocPrint(arena,
                \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":{s}}}]}}}}
            , .{ id, result_str });
        }

        return std.fmt.allocPrint(arena,
            \\{{"jsonrpc":"2.0","id":{s},"error":{{"code":-32601,"message":"Tool not found: {s}"}}}}
        , .{ id, name });
    }
};

/// Render a JSON value back to its string form (for re-embedding the request id).
fn jsonValueToString(arena: std.mem.Allocator, val: std.json.Value) ![]const u8 {
    return switch (val) {
        .null => "null",
        .bool => |b| if (b) "true" else "false",
        .integer => |n| try std.fmt.allocPrint(arena, "{d}", .{n}),
        .float => |f| try std.fmt.allocPrint(arena, "{d}", .{f}),
        .string => |s| try std.fmt.allocPrint(arena, "\"{s}\"", .{s}),
        else => "null",
    };
}

/// JSON-encode a string value, including surrounding quotes.
/// Returns the encoded form e.g. `"hello \"world\""`.
fn jsonEscapeString(arena: std.mem.Allocator, s: []const u8) ![]const u8 {
    return std.json.Stringify.valueAlloc(arena, s, .{});
}

// ============================================================================
// Tests
// ============================================================================

test "Server initialize response contains version and server name" {
    const allocator = std.testing.allocator;
    var server = try Server.init(allocator, "https://example.com", "test-token");
    defer server.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const response = try server.handleInitialize(arena.allocator(), "1");
    try std.testing.expect(std.mem.indexOf(u8, response, "vikunja-mcp") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, PROTOCOL_VERSION) != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"id\":1") != null);
}

test "jsonValueToString round-trips primitive types" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    try std.testing.expectEqualStrings("null", try jsonValueToString(aa, .null));
    try std.testing.expectEqualStrings("true", try jsonValueToString(aa, .{ .bool = true }));
    try std.testing.expectEqualStrings("42", try jsonValueToString(aa, .{ .integer = 42 }));
    try std.testing.expectEqualStrings("\"hello\"", try jsonValueToString(aa, .{ .string = "hello" }));
}

test "jsonEscapeString handles special characters" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const result = try jsonEscapeString(arena.allocator(), "say \"hello\"");
    try std.testing.expect(std.mem.indexOf(u8, result, "\\\"") != null);
}
