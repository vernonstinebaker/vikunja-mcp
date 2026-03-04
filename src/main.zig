const std = @import("std");
const mcp = @import("mcp");
const endpoints = @import("endpoints");

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get configuration from environment
    const base_url = std.process.getEnvVarOwned(allocator, "VIKUNJA_URL") catch {
        std.log.err("VIKUNJA_URL environment variable not set", .{});
        return error.MissingEnvVar;
    };
    defer allocator.free(base_url);

    const token = std.process.getEnvVarOwned(allocator, "VIKUNJA_TOKEN") catch {
        std.log.err("VIKUNJA_TOKEN environment variable not set", .{});
        return error.MissingEnvVar;
    };
    defer allocator.free(token);

    // Start MCP server
    var server = try mcp.Server.init(allocator, base_url, token);
    defer server.deinit();

    try server.registerTools(endpoints.all_tools);
    try server.run();
}

// ============================================================================
// Tests
// ============================================================================

test "main imports compile" {
    _ = mcp;
    _ = endpoints;
}
