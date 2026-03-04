const std = @import("std");
const http = @import("client");
const mcp = @import("mcp");
const Client = http.Client;
const json = std.json;

// ============================================================================
// Types
// ============================================================================

/// Team entity
pub const Team = struct {
    id: i64,
    name: []const u8,
    description: ?[]const u8,
    hex_color: ?[]const u8,
    is_public: bool,

    // Relations
    members: ?[]TeamMember,

    // Timestamps
    created: ?[]const u8,
    updated: ?[]const u8,
};

/// Create team request
pub const TeamCreate = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    hex_color: ?[]const u8 = null,
    is_public: bool = false,
};

/// Update team request
pub const TeamUpdate = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    hex_color: ?[]const u8 = null,
    is_public: ?bool = null,
};

/// Team member
pub const TeamMember = struct {
    id: i64,
    username: ?[]const u8,
    name: ?[]const u8,
    email: ?[]const u8,
    admin: ?bool,
    created: ?[]const u8,
};

/// Add member request
pub const TeamMemberAdd = struct {
    user_id: i64,
    admin: bool = false,
};

// ============================================================================
// API Functions — all return arena-owned []u8 (raw JSON body).
// ============================================================================

/// List all teams — returns raw JSON body
pub fn listTeams(arena: std.mem.Allocator, client: *Client) ![]u8 {
    return client.get(arena, "/teams");
}

/// Get a team by ID — returns raw JSON body
pub fn getTeam(arena: std.mem.Allocator, client: *Client, id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/teams/{}", .{id});
    return client.get(arena, path);
}

/// Create a team — returns raw JSON body
pub fn createTeam(arena: std.mem.Allocator, client: *Client, team: TeamCreate) ![]u8 {
    const body = try std.json.Stringify.valueAlloc(arena, team, .{});
    return client.put(arena, "/teams", body);
}

/// Update a team — returns raw JSON body
pub fn updateTeam(arena: std.mem.Allocator, client: *Client, id: i64, update: TeamUpdate) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/teams/{}", .{id});
    const body = try std.json.Stringify.valueAlloc(arena, update, .{});
    return client.post(arena, path, body);
}

/// Delete a team
pub fn deleteTeam(arena: std.mem.Allocator, client: *Client, id: i64) !void {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/teams/{}", .{id});
    try client.delete(arena, path);
}

/// List team members — returns raw JSON body
pub fn listTeamMembers(arena: std.mem.Allocator, client: *Client, team_id: i64) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/teams/{}/members", .{team_id});
    return client.get(arena, path);
}

/// Add member to team — returns raw JSON body
pub fn addTeamMember(arena: std.mem.Allocator, client: *Client, team_id: i64, member: TeamMemberAdd) ![]u8 {
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/teams/{}/members", .{team_id});
    const body = try std.json.Stringify.valueAlloc(arena, member, .{});
    return client.put(arena, path, body);
}

/// Remove member from team
pub fn removeTeamMember(arena: std.mem.Allocator, client: *Client, team_id: i64, user_id: i64) !void {
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/teams/{}/members/{}", .{ team_id, user_id });
    try client.delete(arena, path);
}

// ============================================================================
// MCP Tool Definitions
// ============================================================================

pub const tools = [_]mcp.Server.Tool{
    .{
        .name = "vikunja_list_teams",
        .description = "List all teams",
        .input_schema = "{}",
        .handler = handleListTeams,
    },
    .{
        .name = "vikunja_create_team",
        .description = "Create a new team",
        .input_schema =
        \\{"type":"object","properties":{"name":{"type":"string"},"description":{"type":"string"}},"required":["name"]}
        ,
        .handler = handleCreateTeam,
    },
    .{
        .name = "vikunja_get_team",
        .description = "Get team details",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleGetTeam,
    },
    .{
        .name = "vikunja_delete_team",
        .description = "Delete a team",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
        ,
        .handler = handleDeleteTeam,
    },
    .{
        .name = "vikunja_list_team_members",
        .description = "List members of a team",
        .input_schema =
        \\{"type":"object","properties":{"team_id":{"type":"integer"}},"required":["team_id"]}
        ,
        .handler = handleListTeamMembers,
    },
    .{
        .name = "vikunja_add_team_member",
        .description = "Add a member to a team",
        .input_schema =
        \\{"type":"object","properties":{"team_id":{"type":"integer"},"user_id":{"type":"integer"},"admin":{"type":"boolean"}},"required":["team_id","user_id"]}
        ,
        .handler = handleAddTeamMember,
    },
    .{
        .name = "vikunja_update_team",
        .description = "Update a team's name, description, or visibility",
        .input_schema =
        \\{"type":"object","properties":{"id":{"type":"integer"},"name":{"type":"string"},"description":{"type":"string"},"is_public":{"type":"boolean"}},"required":["id"]}
        ,
        .handler = handleUpdateTeam,
    },
    .{
        .name = "vikunja_remove_team_member",
        .description = "Remove a member from a team",
        .input_schema =
        \\{"type":"object","properties":{"team_id":{"type":"integer"},"user_id":{"type":"integer"}},"required":["team_id","user_id"]}
        ,
        .handler = handleRemoveTeamMember,
    },
};

// ============================================================================
// Handlers
// ============================================================================

fn handleListTeams(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    _ = params;
    return listTeams(arena, client);
}

fn handleCreateTeam(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const name = strParam(params, "name") orelse return error.MissingParam;
    const req: TeamCreate = .{
        .name = name,
        .description = strParam(params, "description"),
    };
    return createTeam(arena, client, req);
}

fn handleGetTeam(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    return getTeam(arena, client, id);
}

fn handleDeleteTeam(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    try deleteTeam(arena, client, id);
    return arena.dupe(u8, "true");
}

fn handleListTeamMembers(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const team_id = intParam(params, "team_id") orelse return error.MissingParam;
    return listTeamMembers(arena, client, team_id);
}

fn handleAddTeamMember(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const team_id = intParam(params, "team_id") orelse return error.MissingParam;
    const user_id = intParam(params, "user_id") orelse return error.MissingParam;
    const admin = boolParam(params, "admin") orelse false;
    const req: TeamMemberAdd = .{ .user_id = user_id, .admin = admin };
    return addTeamMember(arena, client, team_id, req);
}

fn handleUpdateTeam(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const id = intParam(params, "id") orelse return error.MissingParam;
    const req: TeamUpdate = .{
        .name = strParam(params, "name"),
        .description = strParam(params, "description"),
        .is_public = boolParam(params, "is_public"),
    };
    return updateTeam(arena, client, id, req);
}

fn handleRemoveTeamMember(arena: std.mem.Allocator, client: *Client, params: json.Value) ![]const u8 {
    const team_id = intParam(params, "team_id") orelse return error.MissingParam;
    const user_id = intParam(params, "user_id") orelse return error.MissingParam;
    try removeTeamMember(arena, client, team_id, user_id);
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

test "TeamCreate serializes correctly" {
    const allocator = std.testing.allocator;
    const team: TeamCreate = .{
        .name = "Engineering",
        .description = "Engineering team",
    };

    const json_str = try std.json.Stringify.valueAlloc(allocator, team, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "Engineering") != null);
}
