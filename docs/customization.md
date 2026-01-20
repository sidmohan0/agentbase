# Customization Guide

AgentBase is designed to adapt to any codebase. This guide covers how to customize it for your needs.

## Defining Workstreams

### Step 1: Identify Natural Boundaries

Look for areas of your codebase with:
- Different concerns (UI vs logic vs data)
- Different file locations
- Different expertise requirements

Common patterns:

| Project Type | Typical Workstreams |
|--------------|---------------------|
| Full-stack web | `frontend`, `backend`, `database`, `api` |
| CLI tool | `core`, `cli`, `config`, `tests` |
| Library | `core`, `api`, `docs`, `examples` |
| Desktop app | `ui`, `backend`, `platform`, `data` |
| Monorepo | One workstream per package |

### Step 2: Create Instruction Files

For each workstream, create `instructions/<name>.md`:

```markdown
# Frontend (`frontend`)

This workstream handles all user-facing components.

## Owns
- `src/components/` - React components
- `src/hooks/` - Custom hooks
- `src/styles/` - CSS/styling
- `src/pages/` - Page components

## Does NOT Own
- `src/api/` - API routes (→ api workstream)
- `src/server/` - Server logic (→ backend workstream)
- `database/` - Schema and migrations (→ database workstream)

## Key Patterns
- Use TypeScript strict mode
- Components should be pure when possible
- State management via React Query for server state

## Definition of Done
- [ ] Component renders correctly
- [ ] Tests added for new components
- [ ] No TypeScript errors
- [ ] Storybook story added (if applicable)
```

### Step 3: Update AGENTS.md

Add the workstream to the ownership table:

```markdown
## Workstreams

| ID | Name | Scope | Instructions |
|----|------|-------|--------------|
| `frontend` | Frontend | UI, components | `instructions/frontend.md` |
| `backend` | Backend | Server, services | `instructions/backend.md` |
| `api` | API | Routes, validation | `instructions/api.md` |
```

## Customizing Priorities

Edit `docs/triage.md` to define what matters in your project:

```markdown
# Triage & Priorities

## Priority Order

| Priority | Category | Description |
|----------|----------|-------------|
| **P0** | Security | Any security vulnerability |
| **P1** | Crashes | Application crashes, data loss |
| **P2** | Blocking bugs | Features completely broken |
| **P3** | Major bugs | Features partially broken |
| **P4** | Minor bugs | Edge cases, cosmetic issues |
| **P5** | Enhancements | New features, improvements |
| **P6** | Tech debt | Refactoring, cleanup |
```

### Project-Specific Examples

**E-commerce site:**
```markdown
| **P0** | Payment | Any payment processing issue |
| **P1** | Checkout | Checkout flow broken |
| **P2** | Cart | Cart functionality issues |
```

**API service:**
```markdown
| **P0** | Data integrity | Data corruption or loss |
| **P1** | Availability | Service unavailable |
| **P2** | Performance | Response time > 500ms |
```

## Customizing Task Discovery

The skill discovers tasks from multiple sources. You can adjust which sources matter by editing the `discover` command section in `SKILL.md`.

### Disable a Source

Comment out or remove the source from the discovery section:

```markdown
#### Source 4: Code TODOs/FIXMEs (P3-P5)
<!-- Disabled: Too many false positives
```bash
grep -rn "TODO\|FIXME" src/
```
-->
```

### Add a Custom Source

Add a new source section:

```markdown
#### Source 8: Sentry Errors (P1-P2)

```bash
# If you have Sentry CLI configured
sentry-cli issues list --project your-project --status unresolved | head -20
```

Parse errors into tasks with P1-P2 priority.
```

### Adjust Priority Mapping

Change how sources map to priorities:

```markdown
# Default
Test crash/panic → **P0**
Test timeout → **P1**
Test assertion failure → **P2**

# Your project (tests are less critical)
Test crash/panic → **P1**
Test timeout → **P2**
Test assertion failure → **P3**
```

## Customizing Worker Prompts

Workers are spawned with a detailed prompt template. Find the `Worker Prompt Template` section in `SKILL.md` and customize:

### Add Project-Specific Rules

```markdown
## Project Rules
- All API responses must include `request_id` header
- Database queries must use the query builder, not raw SQL
- Components must support dark mode
```

### Adjust Resource Limits

```markdown
## Resource Limits
timeout -k 10 600 npm run build   # 10 min build timeout
timeout -k 10 300 npm test        # 5 min test timeout
```

### Change Definition of Done

```markdown
## Definition of Done
Your task is ONLY done if you can show:
- [ ] All tests pass (including new ones)
- [ ] TypeScript compiles with no errors
- [ ] ESLint passes with no warnings
- [ ] Coverage doesn't decrease
- [ ] PR description written
```

## Progress Tracking Options

### Option A: JSON Scoreboard (Default)

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

### Option B: Markdown Checklists

```markdown
<!-- progress/frontend.md -->
## Frontend Progress

### P1 - Blocking
- [x] Fix login button (completed 2024-01-19)
- [ ] Fix cart total calculation

### P2 - Major
- [ ] Add loading states to dashboard
```

### Option C: GitHub Issues

Use labels to track:
- `workstream:frontend`, `workstream:backend`
- `priority:p1`, `priority:p2`
- `status:in-progress`, `status:blocked`

```bash
gh issue list --label "workstream:frontend,priority:p1" --state open
```

## Multi-Session Configuration

Edit `skill/scripts/multi-session.sh` to customize:

### Default Workstreams

```bash
# Change the workstreams array
WORKSTREAMS=("frontend" "backend" "api" "database")
```

### Log Location

```bash
LOG_DIR="${REPO_ROOT}/logs/agentbase"  # Custom log directory
```

### Timeout Settings

```bash
# Add timeout to worker commands
timeout 3600 claude --print "/agentbase work ${ws}"  # 1 hour max
```
