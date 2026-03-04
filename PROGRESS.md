# Vikunja MCP Project Progress

**Goal:** Build a Zig-based MCP server for Vikunja API  
**Total Endpoints:** 107  
**Testing Instance:** plan.agility.plus (v1.0.0, Webhooks enabled)

---

## Implementation Status

| Bot | Category | Endpoints | Implementation | Tests | Status |
|-----|----------|-----------|----------------|-------|--------|
| ZeroClawBot | Projects | 22 | ✅ `projects.zig` | ⏳ | Done |
| macOSBot | Tasks | 26 | ✅ `tasks.zig` | ✅ | Done |
| OrangePiBot | Labels, Filters, Notifications | 12 | ⏳ | ⏳ | Pending |
| NullClawBot | Teams, Webhooks, Sharing | 23 | ⏳ | ⏳ | Pending |
| OpenClawBot | Foundation, Auth | - | ⏳ | ⏳ | Pending |

---

## Files Created

```
/projects/vikunja-mcp/
├── build.zig                    # Zig build configuration
├── src/
│   ├── main.zig                 # MCP server entry point
│   ├── vikunja/
│   │   ├── client.zig           # HTTP client foundation ✅
│   │   └── endpoints/
│   │       ├── projects.zig     # ZeroClawBot (22 endpoints) ✅
│   │       └── tasks.zig        # macOSBot (26 endpoints) ✅
│   └── mcp/
│       ├── types.zig            # MCP protocol types
│       └── server.zig           # MCP server implementation
└── docs/                        # Reference docs (optional)
```

---

## Next Steps

1. **macOSBot** - ✅ Created HTTP client (`client.zig`) and Tasks API (`tasks.zig`)
2. **All bots** - Implement your assigned endpoint .zig files
3. **Tests** - Add comprehensive tests for all functions
4. **Integration** - Wire up MCP server with all endpoints
5. **Build & Test** - Cross-compile for all target platforms

---

## Dependencies

- Zig compiler (0.13.0 or later)
- Testing instance: plan.agility.plus

---

## Build Commands

```bash
# Build for current platform
zig build

# Run tests
zig build test

# Cross-compile for ARM64 Linux
zig build -Dtarget=aarch64-linux-gnu

# Cross-compile for RISC-V64 Linux
zig build -Dtarget=riscv64-linux-gnu
```

---

## Notes

- Live instance at plan.agility.plus has Webhooks enabled ✅
- Vikunja v1.0.0 API is stable
- Focus on .zig implementation files with embedded tests (not separate .md docs)
