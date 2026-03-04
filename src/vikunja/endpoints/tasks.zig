const std = @import("std");
const http = @import("client");
const mcp = @import("mcp");
const Client = http.Client;
const json = std.json;

// ============================================================================
// Types
// ============================================================================

/// Task entity
pub const Task = struct {
    id: i64,
    title: []const u8,
    description: ?[]const u8,

    // Status
    done: bool,
    is_favorite: bool,
    priority: ?i32,

    // Dates
    due_date: ?[]const u8,
    start_date: ?[]const u8,
    end_date: ?[]const u8,

    // Position and organization
    position: ?f64,
    project_id: i64,
    bucket_id: ?i64,
    percent_done: ?f64,

    // Metadata
    created_by: ?User,
    created: ?[]const u8,
    updated: ?[]const u8,

    // Relations
    assignees: ?[]User,
    labels: ?[]Label,
};

/// Priority levels — stored as integer in JSON.
pub const Priority = enum(i32) {
    unset = 0,
    low = 1,
    medium = 2,
    high = 3,
    urgent = 4,
    critical = 5,
};

/// Create task request
pub const TaskCreate = struct {
    title: []const u8,
    description: ?[]const u8 = null,
    project_id: i64,
    due_date: ?[]const u8 = null,
    priority: ?i32 = null,
    bucket_id: ?i64 = null,
};

/// Update task request
pub const TaskUpdate = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    done: ?bool = null,
    is_favorite: ?bool = null,
    priority: ?i32 = null,
    due_date: ?[]const u8 = null,
    start_date: ?[]const u8 = null,
    end_date: ?[]const u8 = null,
    bucket_id: ?i64 = null,
    position: ?f64 = null,
    percent_done: ?f64 = null,
};

/// Task relation
pub const TaskRelation = struct {
    id: i64,
    task_id: i64,
    other_task_id: i64,
    relation_kind: []const u8,
    created: ?[]const u8,
};

/// Relation kinds — plain enum; use @tagName() for the API string.
pub const RelationKind = enum {
    subtask,
    parenttask,
    related,
    duplicateof,
    blocking,
    blocked,
    precedes,
    follows,
};

/// Comment entity
pub const Comment = struct {
    id: i64,
    task_id: i64,
    author: ?User,
    comment: []const u8,
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// User reference
pub const User = struct {
    id: i64,
    username: ?[]const u8,
    name: ?[]const u8,
    email: ?[]const u8,
};

/// Label reference
pub const Label = struct {
    id: i64,
    title: ?[]const u8,
    hex_color: ?[]const u8,
};

// ============================================================================
// API Functions — all return arena-owned []u8 (raw JSON body).
// ============================================================================

/// Maximum tasks fetched per page. Vikunja's server-side max is 50.
const PAGE_SIZE = 50;

/// List all tasks (with optional filter), paginating through all pages.
/// Returns a JSON array string combining all pages.
pub fn listTasks(arena: std.mem.Allocator, client: *Client, filter: ?[]const u8) ![]u8 {
    var all: std.ArrayList(u8) = .empty;
    const w = all.writer(arena);
    try w.writeByte('[');
    var page: u32 = 1;
    var total: usize = 0;
    while (true) {
        const path = if (filter) |f|
            try std.fmt.allocPrint(arena, "/tasks?page={}&per_page={}&filter={s}", .{ page, PAGE_SIZE, f })
        else
            try std.fmt.allocPrint(arena, "/tasks?page={}&per_page={}", .{ page, PAGE_SIZE });

        const body = try client.get(arena, path);

        // Body is a JSON array — strip outer brackets and append items.
        const trimmed = std.mem.trim(u8, body, " \t\r\n");
        if (trimmed.len < 2) break; // empty or malformed
        const inner = trimmed[1 .. trimmed.len - 1]; // strip [ ]
        const stripped = std.mem.trim(u8, inner, " \t\r\n");
        if (stripped.len == 0) break; // empty page — done

        // Count items on this page to detect last page.
        // Simple heuristic: count top-level '{' occurrences.
        var item_count: usize = 0;
        var depth: usize = 0;
        for (stripped) |c| {
            if (c == '{') {
                if (depth == 0) item_count += 1;
                depth += 1;
            } else if (c == '}') {
                if (depth > 0) depth -= 1;
            }
        }

        if (total > 0) try w.writeByte(',');
        try w.writeAll(stripped);
        total += item_count;

        if (item_count < PAGE_SIZE) break; // last page
        page += 1;
    }
    try w.writeByte(']');
    return all.toOwnedSlice(arena);
}

/// Count all tasks matching an optional filter, paginating through all pages.
/// Returns the total count as a usize.
pub fn countTasks(arena: std.mem.Allocator, client: *Client, filter: ?[]const u8) !usize {
    var page: u32 = 1;
    var total: usize = 0;
    while (true) {
        const path = if (filter) |f|
            try std.fmt.allocPrint(arena, "/tasks?page={}&per_page={}&filter={s}", .{ page, PAGE_SIZE, f })
        else
            try std.fmt.allocPrint(arena, "/tasks?page={}&per_page={}", .{ page, PAGE_SIZE });

        const body = try client.get(arena, path);
        const trimmed = std.mem.trim(u8, body, " \t\r\n");
        if (trimmed.len < 2) break;
        const inner = trimmed[1 .. trimmed.len - 1];
        const stripped = std.mem.trim(u8, inner, " \t\r\n");
        if (stripped.len == 0) break;

        var item_count: usize = 0;
        var depth: usize = 0;
        for (stripped) |c| {
            if (c == '{') {
                if (depth == 0) item_count += 1;
                depth += 1;
            } else if (c == '}') {
                if (depth > 0) depth -= 1;
            }
        }
        total += item_count;
        if (item_count < PAGE_SIZE) break;
        page += 1;
    }
    return total;
}

/// Count tasks in a project, paginating through all pages.
/// Returns the total count as a usize.
pub fn countProjectTasks(arena: std.mem.Allocator, client: *Client, project_id: i64) !usize {
    var page: u32 = 1;
    var total: usize = 0;
    while (true) {
        const path = try std.fmt.allocPrint(arena, "/projects/{}/tasks?page={}&per_page={}", .{ project_id, page, PAGE_SIZE });
        const body = try client.get(arena, path);
        const trimmed = std.mem.trim(u8, body, " \t\r\n");
        if (trimmed.len < 2) break;
        const inner = trimmed[1 .. trimmed.len - 1];
        const stripped = std.mem.trim(u8, inner, " \t\r\n");
        if (stripped.len == 0) break;

        var item_count: usize = 0;
        var depth: usize = 0;
        for (stripped) |c| {
            if (c == '{') {
                if (depth == 0) item_count += 1;
                depth += 1;
            } else if (c == '}') {
                if (depth > 0) depth -= 1;
            }
        }
        total += item_count;
        if (item_count < PAGE_SIZE) break;
        page += 1;
    }
    return total;
}

/// List tasks in a project, paginating through all pages.
/// Returns a JSON array string combining all pages.
pub fn listProjectTasks(arena: std.mem.Allocator, client: *Client, project_id: i64, _: ?u32) ![]u8 {
    var all: std.ArrayList(u8) = .empty;
    const w = all.writer(arena);
    try w.writeByte('[');
    var page: u32 = 1;
    var total: usize = 0;
    while (true) {
        const path = try std.fmt.allocPrint(arena, "/projects/{}/tasks?page={}&per_page={}", .{ project_id, page, PAGE_SIZE });
        const body = try client.get(arena, path);

        const trimmed = std.mem.trim(u8, body, " \t\r\n");
        if (trimmed.len < 2) break;
        const inner = trimmed[1 .. trimmed.len - 1];
        const stripped = std.mem.trim(u8, inner, " \t\r\n");
        if (stripped.len == 0) break;

        var item_count: usize = 0;
        var depth: usize = 0;
        for (stripped) |c| {
            if (c == '{') {
                if (depth == 0) item_count += 1;
                depth += 1;
            } else if (c == '}') {
                if (depth > 0) depth -= 1;
            }
        }

        if (total > 0) try w.writeByte(',');
        try w.writeAll(stripped);
        total += item_count;

        if (item_count < PAGE_SIZE) break;
        page += 1;
    }
    try w.writeByte(']');
    return all.toOwnedSlice(arena);
}

/// Get a single task — returns raw JSON body
pub fn getTask(arena: std.mem.Allocator, client: *Client, id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}", .{id});
    return client.get(arena, path);
}

/// Create a task — returns raw JSON body
pub fn createTask(arena: std.mem.Allocator, client: *Client, task: TaskCreate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/projects/{}/tasks", .{task.project_id});
    const body = try std.json.Stringify.valueAlloc(arena, task, .{});
    return client.put(arena, path, body);
}

/// Update a task — returns raw JSON body
pub fn updateTask(arena: std.mem.Allocator, client: *Client, id: i64, update: TaskUpdate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}", .{id});
    const body = try std.json.Stringify.valueAlloc(arena, update, .{});
    return client.post(arena, path, body);
}

/// Delete a task
pub fn deleteTask(arena: std.mem.Allocator, client: *Client, id: i64) !void {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}", .{id});
    try client.delete(arena, path);
}

/// Mark task as done — returns raw JSON body
pub fn completeTask(arena: std.mem.Allocator, client: *Client, id: i64) ![]u8 {
    return updateTask(arena, client, id, .{ .done = true });
}

/// Add comment to task — returns raw JSON body.
/// Uses json.stringifyAlloc to safely escape the comment text.
pub fn addComment(arena: std.mem.Allocator, client: *Client, task_id: i64, comment: []const u8) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/comments", .{task_id});

    // Safe JSON serialization — no raw string injection.
    const CommentRequest = struct { comment: []const u8 };
    const body = try std.json.Stringify.valueAlloc(arena, CommentRequest{ .comment = comment }, .{});

    return client.put(arena, path, body);
}

/// List assignees for a task — returns raw JSON body
pub fn listAssignees(arena: std.mem.Allocator, client: *Client, task_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/assignees", .{task_id});
    return client.get(arena, path);
}

/// Assign a user to a task — returns raw JSON body
pub fn assignTask(arena: std.mem.Allocator, client: *Client, task_id: i64, user_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/assignees", .{task_id});
    const AssignRequest = struct { user_id: i64 };
    const body = try std.json.Stringify.valueAlloc(arena, AssignRequest{ .user_id = user_id }, .{});
    return client.put(arena, path, body);
}

/// Remove an assignee from a task
pub fn unassignTask(arena: std.mem.Allocator, client: *Client, task_id: i64, user_id: i64) !void {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/assignees/{}", .{ task_id, user_id });
    try client.delete(arena, path);
}

/// Delete a relation between two tasks
pub fn deleteRelation(arena: std.mem.Allocator, client: *Client, task_id: i64, other_task_id: i64, kind: RelationKind) !void {
    const path = try std.fmt.allocPrint(arena, "/tasks/{}/relations/{s}/{}", .{ task_id, @tagName(kind), other_task_id });
    try client.delete(arena, path);
}

/// Create task relation — returns raw JSON body.
pub fn createRelation(arena: std.mem.Allocator, client: *Client, task_id: i64, other_task_id: i64, kind: RelationKind) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/relations", .{task_id});

    const RelationRequest = struct {
        other_task_id: i64,
        relation_kind: []const u8,
    };
    const body = try std.json.Stringify.valueAlloc(arena, RelationRequest{
        .other_task_id = other_task_id,
        .relation_kind = @tagName(kind),
    }, .{});

    return client.put(arena, path, body);
}

/// List comments on a task — returns raw JSON body
pub fn listComments(arena: std.mem.Allocator, client: *Client, task_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tasks/{}/comments", .{task_id});
    return client.get(arena, path);
}

// ============================================================================
// MCP Tool Definitions
// ============================================================================

pub const tools = [_]mcp.Server.Tool{
    .{
        .name = "vikunja_list_tasks",
        .description = "List all tasks with optional filter expression. Paginates automatically to return all results.",
        .input_schema =
        \\{"type":"object","properties":{"filter":{"type":"string","description":"Vikunja filter query (e.g. 'done = false && priority >= 3')"},"project_id":{"type":"integer","description":"Limit to a specific project"}}}
        ,
        .handler = handleListTasks,
    },
    .{
        .name = "vikunja_count_tasks",
        .description = "Count tasks with optional filter or project_id. Returns a single integer. Use this instead of vikunja_list_tasks when you only need a count.",
        .input_schema =
        \\{"type":"object","properties":{"filter":{"type":"string","description":"Vikunja filter query (e.g. 'done = true')"},"project_id":{"type":"integer","description":"Limit to a specific project"}}}
        ,
        .handler = handleCountTasks,
    },
    .{
        .name = "vikunja_get_task",
        .description = "Get details of a specific task",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleGetTask,
    },
    .{
        .name = "vikunja_create_task",
        .description = "Create a new task in a project",
        .input_schema =
        \\{"type":"object","properties":{"title":{"type":"string"},"project_id":{"type":"integer"},"description":{"type":"string"},"priority":{"type":"integer","minimum":0,"maximum":5},"due_date":{"type":"string","description":"RFC3339 datetime"}},"required":["title","project_id"]}
        ,
        .handler = handleCreateTask,
    },
    .{
        .name = "vikunja_update_task",
        .description = "Update an existing task",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"},"title":{"type":"string"},"description":{"type":"string"},"done":{"type":"boolean"},"priority":{"type":"integer","minimum":0,"maximum":5},"due_date":{"type":"string"}},"required":["id"]}
        ,
        .handler = handleUpdateTask,
    },
    .{
        .name = "vikunja_delete_task",
        .description = "Delete a task permanently",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleDeleteTask,
    },
    .{
        .name = "vikunja_complete_task",
        .description = "Mark a task as done",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleCompleteTask,
    },
    .{
        .name = "vikunja_add_comment",
        .description = "Add a comment to a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"comment":{"type":"string"}},"required":["task_id","comment"]}
        ,
        .handler = handleAddComment,
    },
    .{
        .name = "vikunja_list_comments",
        .description = "List all comments on a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"}},"required":["task_id"]}
        ,
        .handler = handleListComments,
    },
    .{
        .name = "vikunja_list_assignees",
        .description = "List all assignees of a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"}},"required":["task_id"]}
        ,
        .handler = handleListAssignees,
    },
    .{
        .name = "vikunja_assign_task",
        .description = "Assign a user to a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"user_id":{"type":"integer"}},"required":["task_id","user_id"]}
        ,
        .handler = handleAssignTask,
    },
    .{
        .name = "vikunja_unassign_task",
        .description = "Remove a user assignment from a task",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"user_id":{"type":"integer"}},"required":["task_id","user_id"]}
        ,
        .handler = handleUnassignTask,
    },
    .{
        .name = "vikunja_create_relation",
        .description = "Create a relation between two tasks (e.g. subtask, blocking, related)",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"other_task_id":{"type":"integer"},"relation_kind":{"type":"string","enum":["subtask","parenttask","related","duplicateof","blocking","blocked","precedes","follows"]}},"required":["task_id","other_task_id","relation_kind"]}
        ,
        .handler = handleCreateRelation,
    },
    .{
        .name = "vikunja_delete_relation",
        .description = "Delete a relation between two tasks",
        .input_schema =
        \\{"type":"object","properties":{"task_id":{"type":"integer"},"other_task_id":{"type":"integer"},"relation_kind":{"type":"string","enum":["subtask","parenttask","related","duplicateof","blocking","blocked","precedes","follows"]}},"required":["task_id","other_task_id","relation_kind"]}
        ,
        .handler = handleDeleteRelation,
    },
};

// ============================================================================
// Handlers
// ============================================================================

fn handleCountTasks(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id");
    const filter = strParam(params, "filter");
    const n = if (project_id) |pid|
        try countProjectTasks(arena, client, pid)
    else
        try countTasks(arena, client, filter);
    return std.fmt.allocPrint(arena, "{}", .{n});
}

fn handleListTasks(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const project_id = intParam(params, "project_id");
    const filter = strParam(params, "filter");
    if (project_id) |pid| {
        return listProjectTasks(arena, client, pid, null);
    }
    return listTasks(arena, client, filter);
}

fn handleGetTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    return getTask(arena, client, id);
}

fn handleCreateTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const title = strParam(params, "title") orelse return error.MissingParam;
    const project_id = intParam(params, "project_id") orelse return error.MissingParam;
    const req: TaskCreate = .{
        .title = title,
        .project_id = project_id,
        .description = strParam(params, "description"),
        .priority = if (intParam(params, "priority")) |p| @intCast(p) else null,
        .due_date = strParam(params, "due_date"),
    };
    return createTask(arena, client, req);
}

fn handleUpdateTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    const req: TaskUpdate = .{
        .title = strParam(params, "title"),
        .description = strParam(params, "description"),
        .done = boolParam(params, "done"),
        .priority = if (intParam(params, "priority")) |p| @intCast(p) else null,
        .due_date = strParam(params, "due_date"),
    };
    return updateTask(arena, client, id, req);
}

fn handleDeleteTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    try deleteTask(arena, client, id);
    return arena.dupe(u8, "true");
}

fn handleCompleteTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    return completeTask(arena, client, id);
}

fn handleAddComment(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const comment = strParam(params, "comment") orelse return error.MissingParam;
    return addComment(arena, client, task_id, comment);
}

fn handleListComments(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    return listComments(arena, client, task_id);
}

fn handleListAssignees(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    return listAssignees(arena, client, task_id);
}

fn handleAssignTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const user_id = intParam(params, "user_id") orelse return error.MissingParam;
    return assignTask(arena, client, task_id, user_id);
}

fn handleUnassignTask(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const user_id = intParam(params, "user_id") orelse return error.MissingParam;
    try unassignTask(arena, client, task_id, user_id);
    return arena.dupe(u8, "true");
}

fn handleCreateRelation(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const other_task_id = intParam(params, "other_task_id") orelse return error.MissingParam;
    const kind_str = strParam(params, "relation_kind") orelse return error.MissingParam;
    const kind = relationKindFromString(kind_str) orelse return error.InvalidParam;
    return createRelation(arena, client, task_id, other_task_id, kind);
}

fn handleDeleteRelation(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const task_id = intParam(params, "task_id") orelse return error.MissingParam;
    const other_task_id = intParam(params, "other_task_id") orelse return error.MissingParam;
    const kind_str = strParam(params, "relation_kind") orelse return error.MissingParam;
    const kind = relationKindFromString(kind_str) orelse return error.InvalidParam;
    try deleteRelation(arena, client, task_id, other_task_id, kind);
    return arena.dupe(u8, "true");
}

fn relationKindFromString(s: []const u8) ?RelationKind {
    inline for (@typeInfo(RelationKind).@"enum".fields) |f| {
        if (std.mem.eql(u8, s, f.name)) return @enumFromInt(f.value);
    }
    return null;
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

test "TaskCreate serializes correctly" {
    const allocator = std.testing.allocator;
    const task: TaskCreate = .{
        .title = "Test task",
        .project_id = 1,
        .priority = 3,
    };

    const json_str = try std.json.Stringify.valueAlloc(allocator, task, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "Test task") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"project_id\":1") != null);
}

test "Priority enum values" {
    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(Priority.unset));
    try std.testing.expectEqual(@as(i32, 1), @intFromEnum(Priority.low));
    try std.testing.expectEqual(@as(i32, 5), @intFromEnum(Priority.critical));
}

test "RelationKind enum tags" {
    try std.testing.expectEqualStrings("subtask", @tagName(RelationKind.subtask));
    try std.testing.expectEqualStrings("blocking", @tagName(RelationKind.blocking));
}
