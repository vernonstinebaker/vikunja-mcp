const std = @import("std");
const http = @import("client");
const mcp = @import("mcp");
const Client = http.Client;
const json = std.json;

// ============================================================================
// Types
// ============================================================================

/// Label entity
pub const Label = struct {
    id: i64,
    title: []const u8,
    description: ?[]const u8,
    hex_color: ?[]const u8,
    created_by: ?User,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Create label request
pub const LabelCreate = struct {
    title: []const u8,
    description: ?[]const u8 = null,
    hex_color: ?[]const u8 = null,
};

/// Update label request
pub const LabelUpdate = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    hex_color: ?[]const u8 = null,
};

/// User reference
pub const User = struct {
    id: i64,
    username: ?[]const u8,
    name: ?[]const u8,
};

/// Saved filter entity
pub const Filter = struct {
    id: i64,
    title: []const u8,
    description: ?[]const u8,
    filters: ?FilterQuery,
    is_favorite: bool,
    owner: ?User,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Filter query parameters
pub const FilterQuery = struct {
    sort_by: ?[][]const u8,
    order_by: ?[][]const u8,
    filter: ?[]const u8,
    filter_include_nulls: ?bool,
    s: ?[]const u8,
};

/// Create filter request
pub const FilterCreate = struct {
    title: []const u8,
    description: ?[]const u8 = null,
    filters: ?FilterQuery = null,
};

// ============================================================================
// API Functions — all return arena-owned []u8 (raw JSON body).
// ============================================================================

/// List all labels — returns raw JSON body
pub fn listLabels(arena: std.mem.Allocator, client: *Client) ![]u8 {
    return client.get(arena, "/labels");
}

/// Get a label by ID — returns raw JSON body
pub fn getLabel(arena: std.mem.Allocator, client: *Client, id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/labels/{}", .{id});
    return client.get(arena, path);
}

/// Create a label — returns raw JSON body
pub fn createLabel(arena: std.mem.Allocator, client: *Client, label: LabelCreate) ![]u8 {
    const body = try std.json.Stringify.valueAlloc(arena, label, .{});
    return client.put(arena, "/labels", body);
}

/// Update a label — returns raw JSON body
pub fn updateLabel(arena: std.mem.Allocator, client: *Client, id: i64, update: LabelUpdate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/labels/{}", .{id});
    const body = try std.json.Stringify.valueAlloc(arena, update, .{});
    return client.post(arena, path, body);
}

/// Delete a label
pub fn deleteLabel(arena: std.mem.Allocator, client: *Client, id: i64) !void {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/labels/{}", .{id});
    try client.delete(arena, path);
}

/// Add label to task — returns raw JSON body
pub fn addLabelToTask(arena: std.mem.Allocator, client: *Client, task_id: i64, label_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/labels", .{task_id});
    const LabelRef = struct { label_id: i64 };
    const body = try std.json.Stringify.valueAlloc(arena, LabelRef{ .label_id = label_id }, .{});
    return client.put(arena, path, body);
}

/// Remove label from task
pub fn removeLabelFromTask(arena: std.mem.Allocator, client: *Client, task_id: i64, label_id: i64) !void {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/labels/{}", .{ task_id, label_id });
    try client.delete(arena, path);
}

// ============================================================================
// API Functions - Filters
// ============================================================================

/// List all saved filters — returns raw JSON body
pub fn listFilters(arena: std.mem.Allocator, client: *Client) ![]u8 {
    return client.get(arena, "/filters");
}

/// Create a saved filter — returns raw JSON body
pub fn createFilter(arena: std.mem.Allocator, client: *Client, filter: FilterCreate) ![]u8 {
    const body = try std.json.Stringify.valueAlloc(arena, filter, .{});
    return client.put(arena, "/filters", body);
}

/// Delete a saved filter
pub fn deleteFilter(arena: std.mem.Allocator, client: *Client, id: i64) !void {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/filters/{}", .{id});
    try client.delete(arena, path);
}

// ============================================================================
// MCP Tool Definitions
// ============================================================================

pub const tools = [_]mcp.Server.Tool{
    .{
        .name = "vikunja_list_labels",
        .description = "List all labels",
        .input_schema = "{}",
        .handler = handleListLabels,
    },
    .{
        .name = "vikunja_create_label",
        .description = "Create a new label",
        .input_schema =
        \\{"type":"object","properties":{"title":{"type":"string"},"hex_color":{"type":"string","description":"Hex color e.g. #ff0000"}},"required":["title"]}
        ,
        .handler = handleCreateLabel,
    },
    .{
        .name = "vikunja_delete_label",
        .description = "Delete a label",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleDeleteLabel,
    },
    .{
        .name = "vikunja_add_label_to_task",
        .description = "Add a label to a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"label_id":{"type":"integer"}},"required":["task_id","label_id"]}
        ,
        .handler = handleAddLabelToTask,
    },
    .{
        .name = "vikunja_remove_label_from_task",
        .description = "Remove a label from a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"label_id":{"type":"integer"}},"required":["task_id","label_id"]}
        ,
        .handler = handleRemoveLabelFromTask,
    },
    .{
        .name = "vikunja_list_filters",
        .description = "List all saved filters",
        .input_schema = "{}",
        .handler = handleListFilters,
    },
    .{
        .name = "vikunja_delete_filter",
        .description = "Delete a saved filter",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleDeleteFilter,
    },
};

// ============================================================================
// Handlers
// ============================================================================

fn handleListLabels(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    _ = params;
    return listLabels(arena, client);
}

fn handleCreateLabel(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const title = strParam(params, "title") orelse return error.MissingParam;
    const req: LabelCreate = .{
        .title = title,
        .hex_color = strParam(params, "hex_color"),
        .description = strParam(params, "description"),
    };
    return createLabel(arena, client, req);
}

fn handleDeleteLabel(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    try deleteLabel(arena, client, id);
    return arena.dupe(u8, "true");
}

fn handleAddLabelToTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const label_id = intParam(params, "label_id") orelse return error.MissingParam;
    return addLabelToTask(arena, client, task_id, label_id);
}

fn handleListFilters(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    _ = params;
    return listFilters(arena, client);
}

fn handleRemoveLabelFromTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const label_id = intParam(params, "label_id") orelse return error.MissingParam;
    try removeLabelFromTask(arena, client, task_id, label_id);
    return arena.dupe(u8, "true");
}

fn handleDeleteFilter(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    try deleteFilter(arena, client, id);
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

test "LabelCreate serializes correctly" {
    const allocator = std.testing.allocator;
    const label: LabelCreate = .{
        .title = "bug",
        .hex_color = "#ff0000",
    };

    const json_str = try std.json.Stringify.valueAlloc(allocator, label, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "bug") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "#ff0000") != null);
}
