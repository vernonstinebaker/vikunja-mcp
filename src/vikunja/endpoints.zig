const std = @import("std");
const mcp = @import("mcp");

pub const projects = @import("projects");
pub const tasks = @import("tasks");
pub const labels = @import("labels");
pub const teams = @import("teams");
pub const webhooks = @import("webhooks");

/// Re-export common types
pub const Project = projects.Project;
pub const Task = tasks.Task;
pub const Label = labels.Label;
pub const Team = teams.Team;
pub const Webhook = webhooks.Webhook;
pub const Share = webhooks.Share;

/// Aggregate all MCP tools from all endpoint modules
pub const all_tools: []const mcp.Server.Tool = &(projects.tools ++ tasks.tools ++ labels.tools ++ teams.tools ++ webhooks.tools);

// ============================================================================
// Tests
// ============================================================================

test "all_tools is not empty" {
    try std.testing.expect(all_tools.len > 0);
}
