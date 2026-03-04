const std = @import("std");
const http = @import("client");
const mcp = @import("mcp");
const Client = http.Client;
const json = std.json;

// ============================================================================
// Types
// ============================================================================

/// Webhook entity
pub const Webhook = struct {
    id: i64,
    project_id: i64,
    target_url: []const u8,
    secret: ?[]const u8,
    events: ?[][]const u8,
    is_active: bool,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Create webhook request
pub const WebhookCreate = struct {
    target_url: []const u8,
    secret: ?[]const u8 = null,
    /// Event names: "task.created", "task.updated", "task.deleted",
    /// "task.completed", "project.updated", "project.deleted"
    events: ?[]const []const u8 = null,
};

/// Project share (public link)
pub const Share = struct {
    id: i64,
    project_id: i64,
    hash: []const u8,
    right: i64,
    password: ?[]const u8,
    sharing_type: ?i64,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Create share request — right: 0=read, 1=write, 2=admin
pub const ShareCreate = struct {
    right: i64 = 0,
    password: ?[]const u8 = null,
};

// ============================================================================
// API Functions - Webhooks — all return arena-owned []u8 (raw JSON body).
// ============================================================================

/// List project webhooks — returns raw JSON body
pub fn listWebhooks(arena: std.mem.Allocator, client: *Client, project_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/webhooks", .{project_id});
    return client.get(arena, path);
}

/// Create a webhook — returns raw JSON body
pub fn createWebhook(arena: std.mem.Allocator, client: *Client, project_id: i64, webhook: WebhookCreate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/webhooks", .{project_id});
    const body = try std.json.Stringify.valueAlloc(arena, webhook, .{});
    return client.put(arena, path, body);
}

/// Delete a webhook
pub fn deleteWebhook(arena: std.mem.Allocator, client: *Client, project_id: i64, webhook_id: i64) !void {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/webhooks/{}", .{ project_id, webhook_id });
    try client.delete(arena, path);
}

// ============================================================================
// API Functions - Shares
// ============================================================================

/// List project shares — returns raw JSON body
pub fn listShares(arena: std.mem.Allocator, client: *Client, project_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/shares", .{project_id});
    return client.get(arena, path);
}

/// Create a share link — returns raw JSON body
pub fn createShare(arena: std.mem.Allocator, client: *Client, project_id: i64, share: ShareCreate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/shares", .{project_id});
    const body = try std.json.Stringify.valueAlloc(arena, share, .{});
    return client.put(arena, path, body);
}

/// Delete a share by hash string
pub fn deleteShare(arena: std.mem.Allocator, client: *Client, project_id: i64, hash: []const u8) !void {
    const path = try std.fmt.allocPrint(arena, "/projects/{}/shares/{s}", .{ project_id, hash });
    try client.delete(arena, path);
}

// ============================================================================
// MCP Tool Definitions
// ============================================================================

pub const tools = [_]mcp.Server.Tool{
    .{
        .name = "vikunja_list_webhooks",
        .description = "List webhooks for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"}},"required":["project_id"]}
        ,
        .handler = handleListWebhooks,
    },
    .{
        .name = "vikunja_create_webhook",
        .description = "Create a webhook for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"target_url":{"type":"string"},"events":{"type":"array","items":{"type":"string"},"description":"e.g. [\"task.created\",\"task.updated\"]"}},"required":["project_id","target_url"]}
        ,
        .handler = handleCreateWebhook,
    },
    .{
        .name = "vikunja_delete_webhook",
        .description = "Delete a webhook",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"webhook_id":{"type":"integer"}},"required":["project_id","webhook_id"]}
        ,
        .handler = handleDeleteWebhook,
    },
    .{
        .name = "vikunja_list_shares",
        .description = "List share links for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"}},"required":["project_id"]}
        ,
        .handler = handleListShares,
    },
    .{
        .name = "vikunja_create_share",
        .description = "Create a share link for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"right":{"type":"integer","enum":[0,1,2],"description":"0=read,1=write,2=admin"}},"required":["project_id"]}
        ,
        .handler = handleCreateShare,
    },
    .{
        .name = "vikunja_delete_share",
        .description = "Delete a share link by its hash",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"hash":{"type":"string"}},"required":["project_id","hash"]}
        ,
        .handler = handleDeleteShare,
    },
};

// ============================================================================
// Handlers
// ============================================================================

fn handleListWebhooks(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    return listWebhooks(arena, client, project_id);
}

fn handleCreateWebhook(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const target_url = strParam(params, "target_url") orelse return error.MissingParam;
    // events array: collect strings from params if present
    const events: ?[]const []const u8 = blk: {
        if (params != .object) break :blk null;
        const ev = params.object.get("events") orelse break :blk null;
        if (ev != .array) break :blk null;
        var list: std.ArrayList([]const u8) = .empty;
        for (ev.array.items) |item| {
            if (item == .string) try list.append(arena, item.string);
        }
        break :blk try list.toOwnedSlice(arena);
    };
    const req: WebhookCreate = .{
        .target_url = target_url,
        .events = events,
    };
    return createWebhook(arena, client, project_id, req);
}

fn handleDeleteWebhook(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const webhook_id = intParam(params, "webhook_id") orelse return error.MissingParam;
    try deleteWebhook(arena, client, project_id, webhook_id);
    return arena.dupe(u8, "true");
}

fn handleListShares(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    return listShares(arena, client, project_id);
}

fn handleCreateShare(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const right = intParam(params, "right") orelse 0;
    const req: ShareCreate = .{ .right = right };
    return createShare(arena, client, project_id, req);
}

fn handleDeleteShare(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const hash = strParam(params, "hash") orelse return error.MissingParam;
    try deleteShare(arena, client, project_id, hash);
    return arena.dupe(u8, "true");
}

// ============================================================================
// Param helpers
// ============================================================================

fn intParam(params: json.Value, key: []const u8) ?i64 {
    if (params != .object) return null;
    const val = params.object.get(key) orelse return null;
    return switch (val) {
        .integer => |n| n,
        .float => |f| @intFromFloat(f),
        // Some LLMs (e.g. MiniMax) encode integers as JSON strings.
        .string => |s| std.fmt.parseInt(i64, s, 10) catch null,
        else => null,
    };
}

fn strParam(params: json.Value, key: []const u8) ?[]const u8 {
    if (params != .object) return null;
    const val = params.object.get(key) orelse return null;
    return switch (val) {
        .string => |s| s,
        else => null,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "WebhookCreate serializes correctly" {
    const allocator = std.testing.allocator;
    const webhook: WebhookCreate = .{
        .target_url = "https://example.com/webhook",
    };

    const json_str = try std.json.Stringify.valueAlloc(allocator, webhook, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "example.com") != null);
}

test "ShareCreate defaults to read right" {
    const allocator = std.testing.allocator;
    const share: ShareCreate = .{};
    const json_str = try std.json.Stringify.valueAlloc(allocator, share, .{});
    defer allocator.free(json_str);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"right\":0") != null);
}
