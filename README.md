# AgentBase

A Claude Code skill that implements the Planner-Worker-Judge pattern for multi-agent orchestration, based on Cursor's ["Scaling Long-Running Autonomous Coding"](https://cursor.com/blog/scaling-agents) research.

## What It Does

AgentBase turns Claude Code into a hierarchical multi-agent system:

```
┌─────────────────────────────────────────────────────────┐
│                      PLANNER (Claude)                   │
│  - Explores codebase, creates tasks                     │
│  - Spawns worker sub-agents                             │
│  - Evaluates progress (Judge function)                  │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Worker 1 │    │ Worker 2 │    │ Worker 3 │
    └──────────┘    └──────────┘    └──────────┘
```

Workers operate on isolated **workstreams** (e.g., `frontend`, `backend`, `api`) with non-overlapping ownership, enabling true parallel development.

## Quick Start

```bash
# 1. Install the skill
cp -r skill/ ~/.claude/skills/agentbase/
# Or for project-local: cp -r skill/ .claude/skills/agentbase/

# 2. In Claude Code, initialize your repo
/agentbase init

# 3. Start working
/agentbase status      # See current state
/agentbase triage      # Prioritize work
/agentbase parallel 3  # Spawn 3 workers on top priorities
```

## Commands

| Command | Description |
|---------|-------------|
| `/agentbase init` | Initialize scaffolding in a new repo |
| `/agentbase status` | Overview of all workstreams and progress |
| `/agentbase triage` | Analyze failures, create prioritized task list |
| `/agentbase discover` | Scan codebase for tasks (tests, types, TODOs, coverage) |
| `/agentbase plan <ws>` | Create detailed plan for a workstream |
| `/agentbase work <ws>` | Spawn a worker for a specific workstream |
| `/agentbase parallel <n>` | Spawn n workers on top-priority tasks |
| `/agentbase judge` | Evaluate progress, decide continue/stop/pivot |
| `/agentbase setup` | Create isolated worktree for experimentation |
| `/agentbase worktree <ws>` | Create a worktree for a specific workstream |

## Features

### Automatic Task Discovery

AgentBase finds work from 7 sources:

1. **Failing tests** (P0-P1) - crashes, timeouts, assertions
2. **Type/lint errors** (P1-P2) - TypeScript, ESLint, mypy
3. **GitHub issues** (P2-P4) - bugs, features by label
4. **Code TODOs** (P3-P5) - TODO, FIXME, HACK comments
5. **Coverage gaps** (P3-P4) - untested code paths
6. **Mutation testing** (P3) - weak test detection
7. **Progress files** (varies) - existing scoreboard

### Git Worktree Integration

For true parallel isolation, each workstream can run in its own worktree:

```bash
/agentbase worktree frontend   # Creates ../project-frontend/ on branch agentbase/frontend
/agentbase worktree backend    # Creates ../project-backend/ on branch agentbase/backend
```

Workers in separate worktrees can't conflict—they own different files.

### Multi-Session Scaling

For hundreds of parallel agents, use the included shell script:

```bash
./skill/scripts/multi-session.sh --worktrees --tmux
```

## Installation

See [INSTALL.md](INSTALL.md) for detailed instructions.

**Quick version:**
```bash
# Clone this repo
git clone https://github.com/sidmohan0/agentbase.git

# Copy skill to Claude Code skills directory
cp -r agentbase/skill/ ~/.claude/skills/agentbase/
```

## How It Works

1. **Scaffolding** - `/agentbase init` analyzes your repo and generates:
   - `AGENTS.md` - Master coordination document
   - `docs/philosophy.md` - Development principles
   - `docs/triage.md` - Priority framework
   - `instructions/<workstream>.md` - Scope definitions
   - `progress/` - Committed scoreboard

2. **Task Discovery** - Automatically finds work from tests, types, issues, TODOs

3. **Worker Spawning** - Uses Claude's Task tool to spawn sub-agents with:
   - Specific task assignment
   - Workstream scope (owns / does not own)
   - Definition of done
   - Resource limits

4. **Progress Tracking** - JSON files committed to git track status

## Key Principles

From the [Cursor research](https://cursor.com/blog/scaling-agents):

- **Role Separation**: Planner plans, Workers execute, Judge evaluates
- **Non-Overlapping Ownership**: Workstreams have explicit scope boundaries
- **Measurable Outcomes**: "If you can't show a delta, you're not done"
- **Prompting > Infrastructure**: The skill IS the coordination mechanism
- **Simplicity**: Remove complexity rather than add it

## Documentation

- [Installation Guide](INSTALL.md)
- [Usage Guide](docs/usage.md)
- [Concepts: Planner-Worker-Judge](docs/concepts.md)
- [Customization](docs/customization.md)

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT - see [LICENSE](LICENSE)

## Acknowledgments

Based on Wilson Lin's research at Cursor: ["Scaling Long-Running Autonomous Coding"](https://cursor.com/blog/scaling-agents)
