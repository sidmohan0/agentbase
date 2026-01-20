# AgentBase: Multi-Agent Orchestration for Claude Code

A skill that implements the hierarchical Planner-Worker-Judge pattern from Cursor's "Scaling Long-Running Autonomous Coding" research.

## Quick Start

```bash
# In any Claude Code session:
/agentbase status      # See current state
/agentbase triage      # Prioritize work
/agentbase work layout # Spawn a worker for the layout workstream
/agentbase parallel 3  # Spawn 3 workers on top priorities
/agentbase judge       # Evaluate progress
```

## How It Works

### The Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      PLANNER                            │
│  Claude Code session running /agentbase                 │
│  - Reads AGENTS.md, progress/*.json                     │
│  - Creates prioritized task list                        │
│  - Spawns worker sub-agents                             │
│  - Evaluates progress (judge function)                  │
└─────────────────────────────────────────────────────────┘
                           │
                    Task tool calls
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Worker 1 │    │ Worker 2 │    │ Worker 3 │
    │ (subagent)│   │ (subagent)│   │ (subagent)│
    └──────────┘    └──────────┘    └──────────┘
```

### Single-Session Mode (Built-in)

The skill uses Claude Code's Task tool to spawn sub-agents:

```bash
# Spawn workers sequentially
/agentbase work capability_buildout
/agentbase work js_engine

# Spawn workers in parallel (single message, multiple Task calls)
/agentbase parallel 3
```

**Limitations**: Sub-agents share the session's context budget. For truly large-scale work, use multi-session mode.

### Multi-Session Mode (True Parallelism)

For hundreds of agents working in parallel, run multiple Claude Code sessions:

```bash
# Make the script executable
chmod +x .claude/skills/agentbase/scripts/multi-session.sh

# Run all workstreams in background
./.claude/skills/agentbase/scripts/multi-session.sh --background

# Or run in tmux for monitoring
./.claude/skills/agentbase/scripts/multi-session.sh --tmux

# Check status
./.claude/skills/agentbase/scripts/multi-session.sh --status

# Stop all workers
./.claude/skills/agentbase/scripts/multi-session.sh --stop
```

## Setting Up a New Project

### 1. Initialize the Scaffolding

```bash
/agentbase init
```

This creates:
- `AGENTS.md` - Master coordination document
- `docs/philosophy.md` - Development mindset
- `docs/triage.md` - Priority framework
- `instructions/` - Workstream-specific scopes
- `progress/` - Committed scoreboard

### 2. Define Your Workstreams

Edit `AGENTS.md` to define workstreams appropriate to your project:

```markdown
## Workstreams

### Core
- **api**: `instructions/api.md` - REST endpoints, validation
- **database**: `instructions/database.md` - Schema, queries, migrations

### Frontend
- **components**: `instructions/components.md` - React components
- **state**: `instructions/state.md` - Redux, context, hooks
```

### 3. Create Workstream Instructions

For each workstream, create `instructions/<name>.md`:

```markdown
# API (`api`)

This workstream handles REST API endpoints.

## Owns
- Route handlers in `src/api/`
- Request validation
- Response serialization

## Does NOT own
- Database queries (→ database workstream)
- Frontend integration (→ components workstream)
```

### 4. Set Up Progress Tracking

Create a mechanism to track progress. Options:

**Option A: JSON scoreboard (like fastrender)**
```json
// progress/tests/auth.json
{
  "name": "auth",
  "status": "failing",
  "tests_passing": 12,
  "tests_failing": 3,
  "last_run": "2024-01-20T10:00:00Z"
}
```

**Option B: GitHub Issues with labels**
```bash
# Use GitHub CLI to track
gh issue list --label "workstream:api" --state open
```

**Option C: Simple TODO tracking**
```markdown
<!-- progress/api.md -->
## API Workstream Progress

- [x] GET /users endpoint
- [ ] POST /users validation
- [ ] Authentication middleware
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `/agentbase status` | Overview of all workstreams and progress |
| `/agentbase triage` | Analyze failures, create prioritized task list |
| `/agentbase plan <ws>` | Create detailed plan for a workstream |
| `/agentbase work <ws>` | Spawn a worker for a specific workstream |
| `/agentbase parallel <n>` | Spawn n workers on top-priority tasks |
| `/agentbase judge` | Evaluate progress, decide continue/stop/pivot |
| `/agentbase init` | Initialize scaffolding in a new repo |

## Key Principles

From the Cursor research:

1. **Role Separation**: Planner plans, Workers execute, Judge evaluates
2. **Non-Overlapping Ownership**: Workstreams have explicit scope boundaries
3. **Measurable Outcomes**: "If you can't show a delta, you're not done"
4. **Resource Safety**: All commands have timeouts and memory limits
5. **Committed Scoreboard**: Progress tracked in git
6. **Simplicity**: Remove complexity rather than add it

## Customization

### Adding Custom Workstreams

1. Add entry to `AGENTS.md` ownership table
2. Create `instructions/<workstream>.md` with scope definition
3. Add progress tracking mechanism

### Modifying Triage Priorities

Edit `docs/triage.md`:

```markdown
| Priority | Category | Description |
|----------|----------|-------------|
| **P0** | Security | Any security vulnerability |
| **P1** | Crashes | Application crashes |
| **P2** | Bugs | Incorrect behavior |
| **P3** | Performance | Slowness issues |
| **P4** | Polish | UI/UX improvements |
```

### Custom Worker Prompts

The skill uses a standard worker template. Customize by editing the `work` command section in `SKILL.md`.

## Troubleshooting

### "AGENTS.md not found"

Run `/agentbase init` to create the scaffolding.

### Workers not making progress

1. Check if tasks are scoped correctly (not too broad)
2. Verify resource limits aren't killing processes
3. Check for blocking dependencies between workstreams

### Multi-session mode not starting

Ensure:
- `claude` CLI is in PATH
- Script is executable (`chmod +x`)
- AGENTS.md exists with workstream definitions

## Architecture Deep Dive

See [agent-organization-research.md](../../../agent-organization-research.md) for the full research synthesis on why this architecture works.

## License

MIT
