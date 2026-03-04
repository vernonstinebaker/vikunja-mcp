# Vikunja MCP Server

A Model Context Protocol (MCP) server for Vikunja, written in Zig.

## Features

- **Projects**: Create, read, update, delete projects
- **Tasks**: Full CRUD operations, comments, relations, bulk operations
- **Labels**: Manage labels and assign them to tasks
- **Teams**: Team management and member administration
- **Webhooks**: Create and manage project webhooks
- **Sharing**: Public link sharing for projects

## Building

```bash
zig build
```

## Running

Set environment variables and run:

```bash
export VIKUNJA_URL="https://your-vikunja-instance.com"
export VIKUNJA_TOKEN="your-api-token"

./zig-out/bin/vikunja-mcp
```

## MCP Tools

### Projects
- `vikunja_list_projects` - List all projects
- `vikunja_get_project` - Get project details
- `vikunja_create_project` - Create a new project
- `vikunja_update_project` - Update a project
- `vikunja_delete_project` - Delete a project
- `vikunja_list_views` - List project views
- `vikunja_create_view` - Create a view (list/kanban/gantt/table)
- `vikunja_list_buckets` - List Kanban buckets
- `vikunja_create_bucket` - Create a Kanban bucket
- `vikunja_list_project_shares` - List share links
- `vikunja_create_project_share` - Create a share link

### Tasks
- `vikunja_list_tasks` - List all tasks with optional filter
- `vikunja_get_task` - Get task details
- `vikunja_create_task` - Create a task
- `vikunja_update_task` - Update a task
- `vikunja_delete_task` - Delete a task
- `vikunja_complete_task` - Mark task as done
- `vikunja_add_comment` - Add comment to task

### Labels
- `vikunja_list_labels` - List all labels
- `vikunja_create_label` - Create a label
- `vikunja_delete_label` - Delete a label
- `vikunja_add_label_to_task` - Add label to task
- `vikunja_list_filters` - List saved filters

### Teams
- `vikunja_list_teams` - List all teams
- `vikunja_create_team` - Create a team
- `vikunja_get_team` - Get team details
- `vikunja_delete_team` - Delete a team
- `vikunja_list_team_members` - List team members
- `vikunja_add_team_member` - Add member to team

### Webhooks & Sharing
- `vikunja_list_webhooks` - List project webhooks
- `vikunja_create_webhook` - Create a webhook
- `vikunja_delete_webhook` - Delete a webhook
- `vikunja_list_shares` - List project shares
- `vikunja_create_share` - Create a share link
- `vikunja_delete_share` - Delete a share

## Testing

Run unit tests:

```bash
zig build test
```

Run integration tests against a live Vikunja instance:

```bash
export VIKUNJA_URL="https://your-instance.com"
export VIKUNJA_TOKEN="your-token"
zig build test-integration
```

## Project Structure

```
vikunja-mcp/
├── build.zig           # Build configuration
├── build.zig.zon       # Dependencies
├── src/
│   ├── main.zig        # Entry point
│   ├── client.zig      # HTTP client
│   ├── mcp/
│   │   └── server.zig  # MCP protocol implementation
│   └── vikunja/
│       ├── endpoints.zig        # Aggregates all endpoints
│       └── endpoints/
│           ├── projects.zig     # Projects API
│           ├── tasks.zig        # Tasks API
│           ├── labels.zig       # Labels & Filters API
│           ├── teams.zig        # Teams API
│           └── webhooks.zig     # Webhooks & Shares API
└── tests/
    └── integration.zig          # Integration tests
```

## License

MIT
