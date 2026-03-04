const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared named modules — declared once, reused by all test targets.
    const client_mod = b.createModule(.{
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mcp_mod = b.createModule(.{
        .root_source_file = b.path("src/mcp/server.zig"),
        .target = target,
        .optimize = optimize,
    });
    mcp_mod.addImport("client", client_mod);

    // Endpoint sub-modules (each needs client + mcp)
    const projects_mod = b.createModule(.{
        .root_source_file = b.path("src/vikunja/endpoints/projects.zig"),
        .target = target,
        .optimize = optimize,
    });
    projects_mod.addImport("client", client_mod);
    projects_mod.addImport("mcp", mcp_mod);

    const tasks_mod = b.createModule(.{
        .root_source_file = b.path("src/vikunja/endpoints/tasks.zig"),
        .target = target,
        .optimize = optimize,
    });
    tasks_mod.addImport("client", client_mod);
    tasks_mod.addImport("mcp", mcp_mod);

    const labels_mod = b.createModule(.{
        .root_source_file = b.path("src/vikunja/endpoints/labels.zig"),
        .target = target,
        .optimize = optimize,
    });
    labels_mod.addImport("client", client_mod);
    labels_mod.addImport("mcp", mcp_mod);

    const teams_mod = b.createModule(.{
        .root_source_file = b.path("src/vikunja/endpoints/teams.zig"),
        .target = target,
        .optimize = optimize,
    });
    teams_mod.addImport("client", client_mod);
    teams_mod.addImport("mcp", mcp_mod);

    const webhooks_mod = b.createModule(.{
        .root_source_file = b.path("src/vikunja/endpoints/webhooks.zig"),
        .target = target,
        .optimize = optimize,
    });
    webhooks_mod.addImport("client", client_mod);
    webhooks_mod.addImport("mcp", mcp_mod);

    const endpoints_mod = b.createModule(.{
        .root_source_file = b.path("src/vikunja/endpoints.zig"),
        .target = target,
        .optimize = optimize,
    });
    endpoints_mod.addImport("client", client_mod);
    endpoints_mod.addImport("mcp", mcp_mod);
    endpoints_mod.addImport("projects", projects_mod);
    endpoints_mod.addImport("tasks", tasks_mod);
    endpoints_mod.addImport("labels", labels_mod);
    endpoints_mod.addImport("teams", teams_mod);
    endpoints_mod.addImport("webhooks", webhooks_mod);

    // Main executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("client", client_mod);
    exe_mod.addImport("mcp", mcp_mod);
    exe_mod.addImport("endpoints", endpoints_mod);

    const exe = b.addExecutable(.{
        .name = "vikunja-mcp",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const test_step = b.step("test", "Run all tests");

    // Helper: add a test module with optional named imports and wire it to the
    // test step.
    const Imports = struct { name: []const u8, mod: *std.Build.Module };

    const addTests = struct {
        fn add(
            b2: *std.Build,
            step: *std.Build.Step,
            src: []const u8,
            tgt: std.Build.ResolvedTarget,
            opt: std.builtin.OptimizeMode,
            imports: []const Imports,
        ) void {
            const mod = b2.createModule(.{
                .root_source_file = b2.path(src),
                .target = tgt,
                .optimize = opt,
            });
            for (imports) |imp| {
                mod.addImport(imp.name, imp.mod);
            }
            const t = b2.addTest(.{ .root_module = mod });
            step.dependOn(&b2.addRunArtifact(t).step);
        }
    }.add;

    const no_imports: []const Imports = &.{};
    const endpoint_imports: []const Imports = &.{
        .{ .name = "client", .mod = client_mod },
        .{ .name = "mcp", .mod = mcp_mod },
    };

    addTests(b, test_step, "src/client.zig", target, optimize, no_imports);
    addTests(b, test_step, "src/mcp/server.zig", target, optimize, &.{
        .{ .name = "client", .mod = client_mod },
    });
    addTests(b, test_step, "src/vikunja/endpoints/projects.zig", target, optimize, endpoint_imports);
    addTests(b, test_step, "src/vikunja/endpoints/tasks.zig", target, optimize, endpoint_imports);
    addTests(b, test_step, "src/vikunja/endpoints/labels.zig", target, optimize, endpoint_imports);
    addTests(b, test_step, "src/vikunja/endpoints/teams.zig", target, optimize, endpoint_imports);
    addTests(b, test_step, "src/vikunja/endpoints/webhooks.zig", target, optimize, endpoint_imports);
    addTests(b, test_step, "src/vikunja/endpoints.zig", target, optimize, &.{
        .{ .name = "client", .mod = client_mod },
        .{ .name = "mcp", .mod = mcp_mod },
        .{ .name = "projects", .mod = projects_mod },
        .{ .name = "tasks", .mod = tasks_mod },
        .{ .name = "labels", .mod = labels_mod },
        .{ .name = "teams", .mod = teams_mod },
        .{ .name = "webhooks", .mod = webhooks_mod },
    });
    addTests(b, test_step, "src/main.zig", target, optimize, &.{
        .{ .name = "mcp", .mod = mcp_mod },
        .{ .name = "endpoints", .mod = endpoints_mod },
    });
}
