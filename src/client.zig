const std = @import("std");

/// HTTP client for the Vikunja API.
///
/// All methods accept a caller-supplied allocator and return caller-owned []u8
/// bodies. The caller is responsible for freeing the returned slice.
/// DELETE returns void and discards the body.
pub const Client = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    token: []const u8,
    http_client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8, token: []const u8) Client {
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .token = token,
            .http_client = .{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
    }

    /// GET /api/v1{path} → caller-owned body (allocated with `alloc`)
    pub fn get(self: *Client, alloc: std.mem.Allocator, path: []const u8) ![]u8 {
        return self.request(alloc, .GET, path, null);
    }

    /// PUT /api/v1{path} with JSON body → caller-owned body (allocated with `alloc`)
    pub fn put(self: *Client, alloc: std.mem.Allocator, path: []const u8, body: []const u8) ![]u8 {
        return self.request(alloc, .PUT, path, body);
    }

    /// POST /api/v1{path} with JSON body → caller-owned body (allocated with `alloc`)
    pub fn post(self: *Client, alloc: std.mem.Allocator, path: []const u8, body: []const u8) ![]u8 {
        return self.request(alloc, .POST, path, body);
    }

    /// DELETE /api/v1{path} — discards response body
    pub fn delete(self: *Client, alloc: std.mem.Allocator, path: []const u8) !void {
        const body = try self.request(alloc, .DELETE, path, null);
        alloc.free(body);
    }

    fn request(self: *Client, alloc: std.mem.Allocator, method: std.http.Method, path: []const u8, body: ?[]const u8) ![]u8 {
        // Build full URL using the internal allocator (short-lived).
        const url = try std.fmt.allocPrint(self.allocator, "{s}/api/v1{s}", .{ self.base_url, path });
        defer self.allocator.free(url);

        // Stack-allocated auth header avoids a heap allocation.
        var auth_buf: [512]u8 = undefined;
        const auth_header = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{self.token});

        // Accumulate response body into an allocating writer.
        var aw: std.Io.Writer.Allocating = .init(alloc);
        defer aw.deinit();

        const result = try self.http_client.fetch(.{
            .location = .{ .url = url },
            .method = method,
            .payload = body,
            .response_writer = &aw.writer,
            .extra_headers = &.{
                .{ .name = "Authorization", .value = auth_header },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Accept", .value = "application/json" },
            },
        });

        const status = @intFromEnum(result.status);
        if (status >= 400) {
            std.log.err("Vikunja API {s} {s} -> {d}: {s}", .{ @tagName(method), path, status, aw.written() });
            return error.ApiError;
        }

        // Transfer ownership to the caller.
        return aw.toOwnedSlice();
    }

    /// Build the full URL for a path (for logging/debug).
    pub fn buildUrl(self: *const Client, path: []const u8) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}/api/v1{s}", .{ self.base_url, path });
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Client.buildUrl" {
    const allocator = std.testing.allocator;
    var client = Client.init(allocator, "https://plan.agility.plus", "test-token");
    defer client.deinit();

    const url = try client.buildUrl("/projects");
    defer allocator.free(url);

    try std.testing.expectEqualStrings("https://plan.agility.plus/api/v1/projects", url);
}

test "Client.init stores fields correctly" {
    const allocator = std.testing.allocator;
    var client = Client.init(allocator, "https://example.com", "my-token");
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com", client.base_url);
    try std.testing.expectEqualStrings("my-token", client.token);
}
