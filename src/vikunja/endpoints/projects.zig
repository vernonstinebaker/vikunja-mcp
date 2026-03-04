const std = @import("std");
const http = @import("client");
const mcp = @import("mcp");
const Client = http.Client;
const json = std.json;

// ============================================================================
// Types
// ============================================================================

/// Project entity
pub const Project = struct {
    id: i64,
    title: []const u8,
    description: ?[]const u8,
    hex_color: ?[]const u8,
    parent_project_id: ?i64,
    is_archived: bool,
    is_favorited: bool,
    position: f64,

    // Relations
    views: ?[]View,
    owner: ?User,

    // Timestamps
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Create project request
pub const ProjectCreate = struct {
    title: []const u8,
    description: ?[]const u8 = null,
    hex_color: ?[]const u8 = null,
    parent_project_id: ?i64 = null,
};

/// Update project request
pub const ProjectUpdate = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    hex_color: ?[]const u8 = null,
    is_archived: ?bool = null,
    is_favorited: ?bool = null,
    position: ?f64 = null,
};

/// Project view (list, kanban, gantt, table)
pub const View = struct {
    id: i64,
    title: []const u8,
    description: ?[]const u8,
    view_kind: ViewKind,
    position: f64,
    filter: ?[]const u8,
    default_bucket_id: ?i64,
    done_bucket_id: ?i64,
};

/// View kind — stored as integer in JSON, displayed as string to MCP.
pub const ViewKind = enum(i32) {
    list = 0,
    kanban = 1,
    gantt = 2,
    table = 3,
};

pub fn viewKindFromString(s: []const u8) !ViewKind {
    if (std.mem.eql(u8, s, "list")) return .list;
    if (std.mem.eql(u8, s, "kanban")) return .kanban;
    if (std.mem.eql(u8, s, "gantt")) return .gantt;
    if (std.mem.eql(u8, s, "table")) return .table;
    return error.UnknownViewKind;
}

/// Create view request
pub const ViewCreate = struct {
    title: []const u8,
    view_kind: ViewKind,
    description: ?[]const u8 = null,
};

/// Kanban bucket
pub const Bucket = struct {
    id: i64,
    title: []const u8,
    position: f64,
    project_view_id: i64,
    limit: ?i64,
    is_done_bucket: bool,
};

/// Create bucket request
pub const BucketCreate = struct {
    title: []const u8,
    position: ?f64 = null,
    limit: ?i64 = null,
};

/// User reference
pub const User = struct {
    id: i64,
    username: []const u8,
    name: ?[]const u8,
    email: ?[]const u8,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Team reference
pub const Team = struct {
    id: i64,
    name: []const u8,
    description: ?[]const u8,
};

/// Project share (link share)
pub const ProjectShare = struct {
    id: i64,
    project_id: i64,
    hash: []const u8,
    right: i64,
    sharing_type: ?i64,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Create share request — right: 0=read, 1=write, 2=admin
pub const ProjectShareCreate = struct {
    right: i64 = 0,
};

// ============================================================================
// API Functions — helpers return raw JSON body (arena-owned).
// The UAF pattern (defer parsed.deinit(); return parsed.value) is avoided:
// callers use an arena allocator and return the raw body string directly,
// or re-stringify after parsing within the arena.
// ============================================================================

/// List all projects — returns raw JSON body
pub fn listProjects(arena: std.mem.Allocator, client: *Client) ![]u8 {
    return client.get(arena, "/projects");
}

/// Get a single project by ID — returns raw JSON body
pub fn getProject(arena: std.mem.Allocator, client: *Client, id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}", .{id});
    return client.get(arena, path);
}

/// Create a new project — returns raw JSON body
pub fn createProject(arena: std.mem.Allocator, client: *Client, project: ProjectCreate) ![]u8 {
    const body = try std.json.Stringify.valueAlloc(arena, project, .{});
    return client.put(arena, "/projects", body);
}

/// Update an existing project — returns raw JSON body
pub fn updateProject(arena: std.mem.Allocator, client: *Client, id: i64, update: ProjectUpdate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}", .{id});
    const body = try std.json.Stringify.valueAlloc(arena, update, .{});
    return client.post(arena, path, body);
}

/// Delete a project
pub fn deleteProject(arena: std.mem.Allocator, client: *Client, id: i64) !void {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}", .{id});
    try client.delete(arena, path);
}

/// Duplicate a project — returns raw JSON body
pub fn duplicateProject(arena: std.mem.Allocator, client: *Client, id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/duplicate", .{id});
    return client.put(arena, path, "{}");
}

// ============================================================================
// Views API
// ============================================================================

/// List all views for a project — returns raw JSON body
pub fn listViews(arena: std.mem.Allocator, client: *Client, project_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views", .{project_id});
    return client.get(arena, path);
}

/// Get a single view — returns raw JSON body
pub fn getView(arena: std.mem.Allocator, client: *Client, project_id: i64, view_id: i64) ![]u8 {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views/{}", .{ project_id, view_id });
    return client.get(arena, path);
}

/// Create a view — returns raw JSON body
pub fn createView(arena: std.mem.Allocator, client: *Client, project_id: i64, view: ViewCreate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views", .{project_id});
    const body = try std.json.Stringify.valueAlloc(arena, view, .{});
    return client.put(arena, path, body);
}

/// Delete a view
pub fn deleteView(arena: std.mem.Allocator, client: *Client, project_id: i64, view_id: i64) !void {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views/{}", .{ project_id, view_id });
    try client.delete(arena, path);
}

// ============================================================================
// Buckets API
// ============================================================================

/// List all buckets for a kanban view — returns raw JSON body
pub fn listBuckets(arena: std.mem.Allocator, client: *Client, project_id: i64, view_id: i64) ![]u8 {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views/{}/buckets", .{ project_id, view_id });
    return client.get(arena, path);
}

/// Create a bucket — returns raw JSON body
pub fn createBucket(arena: std.mem.Allocator, client: *Client, project_id: i64, view_id: i64, bucket: BucketCreate) ![]u8 {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views/{}/buckets", .{ project_id, view_id });
    const body = try std.json.Stringify.valueAlloc(arena, bucket, .{});
    return client.put(arena, path, body);
}

/// Delete a bucket
pub fn deleteBucket(arena: std.mem.Allocator, client: *Client, project_id: i64, view_id: i64, bucket_id: i64) !void {
    var path_buf: [192]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/views/{}/buckets/{}", .{ project_id, view_id, bucket_id });
    try client.delete(arena, path);
}

// ============================================================================
// Shares API
// ============================================================================

/// List all shares for a project — returns raw JSON body
pub fn listShares(arena: std.mem.Allocator, client: *Client, project_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/shares", .{project_id});
    return client.get(arena, path);
}

/// Create a share link — returns raw JSON body
pub fn createShare(arena: std.mem.Allocator, client: *Client, project_id: i64, share: ProjectShareCreate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/shares", .{project_id});
    const body = try std.json.Stringify.valueAlloc(arena, share, .{});
    return client.put(arena, path, body);
}

/// Delete a share (hash string)
pub fn deleteShare(arena: std.mem.Allocator, client: *Client, project_id: i64, hash: []const u8) !void {
    const path = try std.fmt.allocPrint(arena, "/projects/{}/shares/{s}", .{ project_id, hash });
    try client.delete(arena, path);
}

// ============================================================================
// MCP Tool Definitions
// ============================================================================

pub const tools = [_]mcp.Server.Tool{
    .{
        .name = "vikunja_list_projects",
        .description = "List all projects the user has access to",
        .input_schema = "{}",
        .handler = handleListProjects,
    },
    .{
        .name = "vikunja_get_project",
        .description = "Get details of a specific project",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleGetProject,
    },
    .{
        .name = "vikunja_create_project",
        .description = "Create a new project",
        .input_schema =
        \\{"type":"object","properties":{"title":{"type":"string"},"description":{"type":"string"},"parent_project_id":{"type":"integer"}},"required":["title"]}
        ,
        .handler = handleCreateProject,
    },
    .{
        .name = "vikunja_update_project",
        .description = "Update an existing project",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"},"title":{"type":"string"},"description":{"type":"string"},"is_archived":{"type":"boolean"}},"required":["id"]}
        ,
        .handler = handleUpdateProject,
    },
    .{
        .name = "vikunja_delete_project",
        .description = "Delete a project",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleDeleteProject,
    },
    .{
        .name = "vikunja_list_views",
        .description = "List all views for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"}},"required":["project_id"]}
        ,
        .handler = handleListViews,
    },
    .{
        .name = "vikunja_create_view",
        .description = "Create a new view (list/kanban/gantt/table) for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"title":{"type":"string"},"view_kind":{"type":"string","enum":["list","kanban","gantt","table"]}},"required":["project_id","title","view_kind"]}
        ,
        .handler = handleCreateView,
    },
    .{
        .name = "vikunja_list_buckets",
        .description = "List all Kanban buckets for a view",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"view_id":{"type":"integer"}},"required":["project_id","view_id"]}
        ,
        .handler = handleListBuckets,
    },
    .{
        .name = "vikunja_create_bucket",
        .description = "Create a new Kanban bucket",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"view_id":{"type":"integer"},"title":{"type":"string"}},"required":["project_id","view_id","title"]}
        ,
        .handler = handleCreateBucket,
    },
    .{
        .name = "vikunja_list_project_shares",
        .description = "List all share links for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"}},"required":["project_id"]}
        ,
        .handler = handleListProjectShares,
    },
    .{
        .name = "vikunja_create_project_share",
        .description = "Create a share link for a project",
        .input_schema =
        \\{"type":"object","properties":{"project_id":{"type":"integer"},"right":{"type":"integer","enum":[0,1,2],"description":"0=read,1=write,2=admin"}},"required":["project_id"]}
        ,
        .handler = handleCreateProjectShare,
    },
};

// ============================================================================
// Handlers
// ============================================================================

fn handleListProjects(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    _ = params;
    return listProjects(arena, client);
}

fn handleGetProject(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    return getProject(arena, client, id);
}

fn handleCreateProject(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const title = strParam(params, "title") orelse return error.MissingParam;
    const req: ProjectCreate = .{
        .title = title,
        .description = strParam(params, "description"),
        .parent_project_id = intParam(params, "parent_project_id"),
    };
    return createProject(arena, client, req);
}

fn handleUpdateProject(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    const req: ProjectUpdate = .{
        .title = strParam(params, "title"),
        .description = strParam(params, "description"),
        .is_archived = boolParam(params, "is_archived"),
    };
    return updateProject(arena, client, id, req);
}

fn handleDeleteProject(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    try deleteProject(arena, client, id);
    return arena.dupe(u8, "true");
}

fn handleListViews(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    return listViews(arena, client, project_id);
}

fn handleCreateView(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const title = strParam(params, "title") orelse return error.MissingParam;
    const kind_str = strParam(params, "view_kind") orelse "list";
    const kind = viewKindFromString(kind_str) catch .list;
    const req: ViewCreate = .{
        .title = title,
        .view_kind = kind,
        .description = strParam(params, "description"),
    };
    return createView(arena, client, project_id, req);
}

fn handleListBuckets(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const view_id = intParam(params, "view_id") orelse return error.MissingParam;
    return listBuckets(arena, client, project_id, view_id);
}

fn handleCreateBucket(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const view_id = intParam(params, "view_id") orelse return error.MissingParam;
    const title = strParam(params, "title") orelse return error.MissingParam;
    const req: BucketCreate = .{ .title = title };
    return createBucket(arena, client, project_id, view_id, req);
}

fn handleListProjectShares(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    return listShares(arena, client, project_id);
}

fn handleCreateProjectShare(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const right = intParam(params, "right") orelse 0;
    const req: ProjectShareCreate = .{ .right = right };
    return createShare(arena, client, project_id, req);
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

fn boolParam(params: json.Value, key: []const u8) ?bool {
    if (params != .object) return null;
    const val = params.object.get(key) orelse return null;
    return switch (val) {
        .bool => |b| b,
        else => null,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "ProjectCreate serializes correctly" {
    const allocator = std.testing.allocator;
    const project: ProjectCreate = .{
        .title = "Test project",
    };

    const json_str = try std.json.Stringify.valueAlloc(allocator, project, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "Test project") != null);
}

test "ViewKind enum values" {
    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(ViewKind.list));
    try std.testing.expectEqual(@as(i32, 1), @intFromEnum(ViewKind.kanban));
    try std.testing.expectEqual(@as(i32, 2), @intFromEnum(ViewKind.gantt));
    try std.testing.expectEqual(@as(i32, 3), @intFromEnum(ViewKind.table));
}

test "viewKindFromString" {
    try std.testing.expectEqual(ViewKind.list, try viewKindFromString("list"));
    try std.testing.expectEqual(ViewKind.kanban, try viewKindFromString("kanban"));
    try std.testing.expectError(error.UnknownViewKind, viewKindFromString("bogus"));
}
