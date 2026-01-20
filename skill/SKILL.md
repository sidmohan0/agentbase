---
name: agentbase
description: Multi-agent orchestration system for coordinating parallel development work. Use when managing complex multi-workstream development, triaging failures, or coordinating parallel agent work.
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Task, TodoWrite
argument-hint: [command] [workstream]
---

# AgentBase: Multi-Agent Orchestration System

You are now operating as the **Planner** in a hierarchical Planner-Worker-Judge agent system, based on the methodology from Cursor's "Scaling Long-Running Autonomous Coding" research.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      PLANNER (You)                       │
│  - Explores codebase, understands state                 │
│  - Creates tasks, assigns to workstreams                │
│  - Spawns worker sub-agents via Task tool               │
│  - Evaluates progress (Judge function)                  │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Worker 1 │    │ Worker 2 │    │ Worker 3 │
    │(Task tool)│   │(Task tool)│   │(Task tool)│
    └──────────┘    └──────────┘    └──────────┘
           │               │               │
           └───────────────┼───────────────┘
                           ▼
              ┌────────────────────────┐
              │  progress/pages/*.json │
              │   (Committed State)    │
              └────────────────────────┘
```

## Commands

Parse `$ARGUMENTS` to determine the command:

| Command | Description |
|---------|-------------|
| `status` | Show current state across all workstreams |
| `triage` | Analyze failures and prioritize work |
| `plan [workstream]` | Create tasks for a specific workstream |
| `work [workstream]` | Spawn workers for a workstream |
| `parallel [n]` | Spawn n workers across highest-priority tasks |
| `judge` | Evaluate progress, decide continue/stop |
| `init` | Initialize agentbase scaffolding in a new repo |
| `discover` | Scan codebase for tasks (tests, types, issues, TODOs) |
| `setup` | Create isolated worktree for agentbase experimentation |
| `worktree [workstream]` | Create a worktree for a specific workstream |

---

## Step 0: Check for Scaffolding (ALWAYS DO THIS FIRST)

Before ANY command except `init`, check if scaffolding exists:

```bash
# Check for required files
ls AGENTS.md 2>/dev/null || echo "MISSING: AGENTS.md"
ls docs/philosophy.md 2>/dev/null || echo "MISSING: docs/philosophy.md"
ls docs/triage.md 2>/dev/null || echo "MISSING: docs/triage.md"
ls instructions/*.md 2>/dev/null || echo "MISSING: instructions/*.md"
```

**If ANY are missing**, output:

```
## AgentBase: Scaffolding Required

This repo is not set up for agentbase orchestration.

Missing:
- [ ] AGENTS.md (workstream definitions)
- [ ] docs/philosophy.md (development principles)
- [ ] docs/triage.md (priority framework)
- [ ] instructions/*.md (workstream scopes)

Run `/agentbase init` to analyze this repo and generate the scaffolding.

This will:
1. Detect your project structure and tech stack
2. Propose workstreams based on your code organization
3. Generate coordination documents
4. Set up progress tracking
```

**Then STOP.** Do not attempt other commands without scaffolding.

---

## Step 1: Load Coordination Documents

After confirming scaffolding exists, read the coordination documents:

```
AGENTS.md                           # Master coordination (workstreams, rules)
docs/philosophy.md                  # Development mindset
docs/triage.md                      # Priority order, operating model
instructions/<workstream>.md        # Workstream-specific scope
```

---

## Step 2: Discover Tasks (Where Work Comes From)

AgentBase automatically discovers tasks from multiple sources. **You don't manually populate tasks** - they're derived from the codebase state.

### Task Discovery Sources (in priority order)

#### Source 1: Failing Tests (P0-P1)

```bash
# Node.js
npm test 2>&1 | tee /tmp/test-output.txt
grep -E "FAIL|Error|failed" /tmp/test-output.txt

# Python
pytest --tb=no -q 2>&1 | grep -E "FAILED|ERROR"

# Rust
cargo test 2>&1 | grep -E "FAILED|error\[E"

# Go
go test ./... 2>&1 | grep -E "FAIL|panic"
```

Parse failures into tasks:
- Test crash/panic → **P0**
- Test timeout → **P1**
- Test assertion failure → **P2**

#### Source 2: Type/Lint Errors (P1-P2)

```bash
# TypeScript
npx tsc --noEmit 2>&1 | head -50

# ESLint
npx eslint . --format compact 2>&1 | head -50

# Rust
cargo check 2>&1 | grep -E "^error"

# Python
mypy . 2>&1 | grep -E "error:"
```

#### Source 3: GitHub Issues (P2-P4)

```bash
# Get open bugs
gh issue list --label "bug" --state open --json number,title,labels

# Get issues by priority label
gh issue list --label "priority:high" --state open

# Get issues assigned to workstream
gh issue list --label "workstream:frontend" --state open
```

#### Source 4: Code TODOs/FIXMEs (P3-P5)

```bash
# Find all TODOs with context
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.tsx" | head -30

# Categorize by urgency
grep -rn "FIXME" src/   # → P3 (should fix)
grep -rn "TODO" src/    # → P4 (nice to have)
grep -rn "HACK" src/    # → P3 (technical debt)
```

#### Source 5: Missing Test Coverage (P3-P4)

**Code Coverage Analysis:**

```bash
# Node.js (nyc/istanbul)
npx nyc --reporter=json npm test
cat coverage/coverage-summary.json | jq '.total'

# Find files with low coverage
npx nyc --reporter=json npm test && \
  cat coverage/coverage-final.json | jq -r 'to_entries[] | select(.value.s | to_entries | map(.value) | add / length < 0.5) | .key'

# Python (coverage.py)
coverage run -m pytest && coverage json
cat coverage.json | jq '.files | to_entries[] | select(.value.summary.percent_covered < 50) | .key'

# Rust (cargo-tarpaulin)
cargo tarpaulin --out Json
cat tarpaulin-report.json | jq '.files[] | select(.covered / .coverable < 0.5) | .path'
```

**Find Untested Public Functions:**

```bash
# TypeScript: Find exported functions without test files
for f in $(find src -name "*.ts" ! -name "*.test.ts" ! -name "*.spec.ts"); do
  base=$(basename "$f" .ts)
  if ! ls src/**/${base}.test.ts src/**/${base}.spec.ts 2>/dev/null | grep -q .; then
    echo "No tests: $f"
  fi
done

# Find public functions in files with no corresponding test
grep -l "^export " src/**/*.ts | while read f; do
  test_file="${f%.ts}.test.ts"
  if [[ ! -f "$test_file" ]]; then
    echo "Missing test file: $test_file"
    grep "^export function\|^export const\|^export class" "$f"
  fi
done
```

**Find Complex Functions Without Tests:**

```bash
# Use complexity analysis (requires tools like escomplex, radon, etc.)

# JavaScript (escomplex)
npx escomplex src/**/*.ts --format json | jq '.reports[] | select(.aggregate.cyclomatic > 10) | {file: .path, complexity: .aggregate.cyclomatic}'

# Python (radon)
radon cc src/ -j | jq '.[] | to_entries[] | select(.value[].complexity > 10)'

# Then cross-reference with coverage to find complex untested code
```

**Find Changed Files Without Test Updates:**

```bash
# Files changed in last N commits without corresponding test changes
git diff --name-only HEAD~10 -- "*.ts" "*.tsx" | while read f; do
  test_file="${f%.ts}.test.ts"
  if ! git diff --name-only HEAD~10 | grep -q "$test_file"; then
    echo "Changed without test update: $f"
  fi
done
```

**Output Tasks for Missing Coverage:**

```json
{
  "id": "task-coverage-001",
  "priority": "P3",
  "source": "coverage",
  "title": "Add tests for UserService (32% coverage)",
  "description": "Low coverage on critical service",
  "file": "src/services/UserService.ts",
  "workstream": "tests",
  "suggested_tests": [
    "createUser() - happy path",
    "createUser() - duplicate email",
    "deleteUser() - not found case"
  ]
}
```

#### Source 6: Edge Cases & Mutation Testing (Advanced)

**Find Boundary Conditions Without Tests:**

```bash
# Look for numeric comparisons that might need edge case tests
grep -rn "< \|> \|<= \|>= \|== 0\|=== 0" src/ --include="*.ts" | \
  grep -v "test\|spec" | head -20

# Find array/string operations (empty array edge cases)
grep -rn "\.length\|\.slice\|\.map\|\.filter" src/ --include="*.ts" | \
  grep -v "test\|spec" | head -20

# Find null/undefined checks that might need testing
grep -rn "!= null\|!== null\|!= undefined\|!== undefined\|\?\." src/ --include="*.ts" | \
  grep -v "test\|spec" | head -20
```

**Mutation Testing (Find Weak Tests):**

```bash
# JavaScript (Stryker)
npx stryker run --reporters json
cat reports/mutation/mutation.json | jq '.files | to_entries[] | select(.value.mutants | map(select(.status == "Survived")) | length > 0)'

# Python (mutmut)
mutmut run && mutmut results
mutmut show  # Shows surviving mutants = weak test coverage
```

Surviving mutants indicate:
- Code that can be changed without breaking tests
- Missing edge case coverage
- Assertions that don't actually verify behavior

**Generate Edge Case Tasks:**

```json
{
  "id": "task-edge-001",
  "priority": "P3",
  "source": "mutation",
  "title": "Add edge case tests for calculateDiscount()",
  "description": "Mutant survived: changed '>' to '>=' on line 45",
  "file": "src/pricing/calculateDiscount.ts:45",
  "workstream": "tests",
  "suggested_tests": [
    "Test boundary: discount = 0",
    "Test boundary: discount = maxDiscount",
    "Test negative discount attempt"
  ]
}
```

#### Source 7: Progress Scoreboard (if exists)

```bash
# Find progress files (fastrender-style)
ls progress/pages/*.json 2>/dev/null | head -20
ls progress/*.json 2>/dev/null | head -20

# Or check for a tasks file
cat progress/tasks.json 2>/dev/null
cat progress/backlog.md 2>/dev/null
```

### Automatic Task File Generation

After discovering tasks, write them to `progress/tasks.json`:

```json
{
  "generated_at": "2024-01-20T10:00:00Z",
  "tasks": [
    {
      "id": "task-001",
      "priority": "P0",
      "source": "test",
      "title": "Fix auth.test.ts crash",
      "description": "TypeError: Cannot read property 'user' of undefined",
      "file": "src/auth/auth.test.ts:45",
      "workstream": "backend"
    },
    {
      "id": "task-002",
      "priority": "P1",
      "source": "typescript",
      "title": "Fix type error in UserService",
      "description": "Property 'email' does not exist on type 'User'",
      "file": "src/services/UserService.ts:23",
      "workstream": "backend"
    },
    {
      "id": "task-003",
      "priority": "P2",
      "source": "github",
      "title": "Login button unresponsive on mobile",
      "description": "GitHub Issue #45",
      "url": "https://github.com/user/repo/issues/45",
      "workstream": "frontend"
    }
  ]
}
```

### Task Discovery Command

When running `/agentbase triage` or `/agentbase status`, automatically:

1. Run test suite (with timeout)
2. Run type checker
3. Check GitHub issues (if `gh` available)
4. Scan for TODOs
5. Aggregate into prioritized task list
6. Write to `progress/tasks.json`

### Manual Task Addition

Users can also add tasks manually to `progress/backlog.md`:

```markdown
# Backlog

## P1 - Must Fix
- [ ] Fix memory leak in WebSocket handler (#backend)
- [ ] Resolve race condition in cache invalidation (#backend)

## P2 - Should Fix
- [ ] Improve error messages for validation failures (#api)
- [ ] Add loading states to dashboard (#frontend)

## P3 - Nice to Have
- [ ] Refactor auth middleware for clarity (#backend)
- [ ] Add dark mode support (#frontend)
```

The `#workstream` tags route tasks to the correct workstream.

---

## Step 3: Understand Current State

### Read Progress/Task Files

```bash
# Check for tasks file
cat progress/tasks.json 2>/dev/null | head -50

# Or backlog
cat progress/backlog.md 2>/dev/null

# Or fastrender-style scoreboard
ls progress/pages/*.json 2>/dev/null | head -20
```

### Categorize by Priority

| Priority | Category | Sources |
|----------|----------|---------|
| **P0** | Crashes/Panics | Test crashes, runtime panics |
| **P1** | Blocking | Test failures, type errors, lint errors |
| **P2** | Major bugs | GitHub issues (bug label), assertion failures |
| **P3** | Minor issues | FIXMEs, HAcKs, minor GitHub issues |
| **P4** | Enhancements | TODOs, feature requests |
| **P5** | Tech debt | Refactoring, documentation |

---

## Step 3: Command Execution

### `status` Command

1. Read all progress JSON files
2. Summarize by status category
3. Show top failures per workstream
4. Report overall health metrics

Output format:
```
## AgentBase Status Report

### Overview
- Total pages: X
- OK: Y (Z%)
- Timeout: A
- Panic: B
- Error: C

### By Workstream
| Workstream | Assigned | Completed | Blocked |
|------------|----------|-----------|---------|
| ...        | ...      | ...       | ...     |

### Top Priority Issues
1. [P0] panic in layout/flex.rs (affects 3 pages)
2. [P1] timeout in cascade (affects 5 pages)
...
```

### `triage` Command

1. Load failure classification from `docs/triage.md`
2. Categorize all failures by hotspot
3. Identify root causes that affect multiple pages
4. Output prioritized task list

**Critical Rule**: Do NOT assign "one worker per page". Split by failure class/hotspot:
> "If 5 pages timeout in layout, assign one worker to fix the layout issue, not 5 workers to each page."

### `plan [workstream]` Command

1. Load workstream instructions from `instructions/<workstream>.md`
2. Identify what the workstream OWNS vs DOES NOT own
3. Find relevant failures within scope
4. Create specific, measurable tasks

Output format:
```
## Plan: [workstream]

### Scope
- Owns: [from instructions file]
- Does NOT own: [from instructions file]

### Tasks (Priority Order)
1. [ ] Fix cascade timeout affecting amazon.com, ebay.com (P1)
   - Evidence: stages_ms.cascade > 4000ms
   - Success: Both pages render in < 5s

2. [ ] Implement missing CSS property X (P2)
   - Evidence: 12 pages show wrong layout
   - Success: diff_percent improves on affected pages
```

### `work [workstream]` Command

Spawn a worker sub-agent using the Task tool:

```
<Task tool call>
subagent_type: general-purpose
prompt: |
  You are a WORKER agent in the agentbase system.

  ## Your Workstream: [workstream]

  ## Instructions
  [Content from instructions/<workstream>.md]

  ## Your Task
  [Specific task from plan]

  ## Definition of Done
  Your task is ONLY done if it produces:
  - Page transitions timeout → render (status changes in progress JSON)
  - Page gets materially faster (lower total_ms)
  - Panic/crash eliminated (with regression test)
  - Correctness fix (observable improvement)

  If you cannot show a measurable delta, you are not done.

  ## Non-Negotiables
  - No page-specific hacks
  - No panics in production code
  - Always use timeout -k with cargo commands
  - Always use scripts/cargo_agent.sh wrapper

  ## Resource Limits
  timeout -k 10 600 bash scripts/cargo_agent.sh build --release
  timeout -k 10 600 bash scripts/cargo_agent.sh test --quiet --lib

  Work until done or blocked, then report back.
</Task>
```

### `parallel [n]` Command

1. Run triage to get prioritized tasks
2. Spawn n workers IN PARALLEL using multiple Task tool calls in a single message
3. Each worker gets a different task from the priority queue
4. Use `run_in_background: true` for true parallelism

Example for n=3:
```
[Task 1: Worker for P0 panic fix]
[Task 2: Worker for P1 timeout fix]
[Task 3: Worker for P2 accuracy fix]
```

### `judge` Command

Evaluate progress since last checkpoint:

1. Read progress JSON files
2. Compare to previous state (via git diff or cached baseline)
3. Calculate metrics:
   - Pages fixed (timeout → ok)
   - Pages regressed (ok → timeout/panic)
   - Accuracy improvements
   - Accuracy regressions

4. Decision:
   - **CONTINUE**: Progress being made, work remains
   - **STOP**: No progress in N iterations, need human input
   - **PIVOT**: Current approach not working, try different strategy

Output:
```
## Judge Evaluation

### Progress Since Last Checkpoint
- Fixed: 3 pages (timeout → ok)
- Regressed: 0 pages
- Accuracy improved: 5 pages (avg -2.3% diff)

### Assessment
[CONTINUE] Making steady progress. Recommend continuing with layout workstream.

### Next Priorities
1. Continue P1 timeout fixes (2 remaining)
2. Start P2 accuracy work on cascade
```

### `init` Command

**This is the most important command for new repos.** It analyzes your codebase and generates the scaffolding.

#### Step 1: Analyze the Repository

Use Glob and Grep to understand the codebase structure:

```bash
# Find project configuration files
ls -la *.json *.toml *.yaml Cargo.toml package.json pyproject.toml 2>/dev/null

# Find source directories
find . -type d -name "src" -o -name "lib" -o -name "app" -o -name "packages" 2>/dev/null | head -20

# Find test directories
find . -type d -name "test" -o -name "tests" -o -name "__tests__" -o -name "spec" 2>/dev/null | head -10

# Check for existing docs
ls -la docs/ README.md CONTRIBUTING.md 2>/dev/null
```

#### Step 2: Detect Technology Stack

Based on files found:
- `Cargo.toml` → Rust project
- `package.json` → Node.js/JavaScript
- `pyproject.toml` / `setup.py` → Python
- `go.mod` → Go
- `src-tauri/` → Tauri desktop app
- `functions/` → Cloud functions

#### Step 3: Propose Workstreams

Based on directory structure, propose 3-6 workstreams. Examples:

| Project Type | Typical Workstreams |
|--------------|---------------------|
| Full-stack web | `frontend`, `backend`, `database`, `api` |
| CLI tool | `core`, `cli`, `config`, `tests` |
| Library | `core`, `api`, `docs`, `examples` |
| Desktop app | `ui`, `backend`, `platform`, `data` |
| Monorepo | One workstream per package |

**Ask the user to confirm or modify the proposed workstreams before generating.**

#### Step 4: Generate Scaffolding

Create the following files:

**`AGENTS.md`** (use template from `templates/AGENTS.template.md`):
- Fill in project name
- List detected workstreams with ownership tables
- Add appropriate non-negotiables for the tech stack

**`docs/philosophy.md`**:
```markdown
# [Project] Philosophy

## The Product
[What this project delivers - ask user if unclear]

## Core Principles
1. **[Primary goal]** is the product
2. **90/10 rule**: 90% core functionality, 10% infrastructure
3. **Measurable outcomes**: If you can't show a delta, you're not done
4. **No hacks**: Correct > fast, incomplete > wrong

## What Counts
- New capability with regression test
- Bugfix with regression test
- Crash/error eliminated with regression test

## What Does NOT Count
- Refactoring without behavioral change
- Tooling work not immediately used
- Documentation not blocking a fix
```

**`docs/triage.md`**:
```markdown
# Triage & Priorities

## Priority Order
| Priority | Category | Description |
|----------|----------|-------------|
| **P0** | Crashes | Application crashes, panics, exceptions |
| **P1** | Blocking bugs | Features completely broken |
| **P2** | Major bugs | Features partially broken |
| **P3** | Minor bugs | Edge cases, cosmetic issues |
| **P4** | Enhancements | New features, improvements |
| **P5** | Tech debt | Refactoring, cleanup |

## Definition of Done
A task is done when:
- [ ] The fix/feature works as expected
- [ ] Tests pass (existing + new regression)
- [ ] No new warnings/errors introduced
```

**`instructions/<workstream>.md`** for each workstream:
```markdown
# [Workstream Name] (`workstream_id`)

## Owns
- [Directory or feature 1]
- [Directory or feature 2]

## Does NOT own
- [Out of scope 1]
- [Out of scope 2]

## Key Files
- `path/to/main/code/`
- `path/to/tests/`

## Definition of Done
- [ ] Feature works
- [ ] Tests added
- [ ] No regressions
```

**`progress/status.json`**:
```json
{
  "initialized": "2024-01-20T00:00:00Z",
  "workstreams": {
    "workstream_1": { "status": "active", "tasks_completed": 0 },
    "workstream_2": { "status": "active", "tasks_completed": 0 }
  }
}
```

#### Step 5: Confirm and Write

Show the user what will be created:

```
## AgentBase Init Preview

Will create:
  AGENTS.md                    (master coordination)
  docs/philosophy.md           (development principles)
  docs/triage.md               (priority framework)
  instructions/frontend.md     (workstream scope)
  instructions/backend.md      (workstream scope)
  instructions/api.md          (workstream scope)
  progress/status.json         (initial scoreboard)

Detected workstreams:
  1. frontend - React components, hooks, UI
  2. backend - Server logic, database
  3. api - REST endpoints, validation

Proceed? [Y/n]
```

Use the Write tool to create all files after confirmation

---

### `setup` Command (Recommended for Existing Repos)

**Use this to experiment without touching your main codebase.**

This creates an isolated worktree where all agentbase scaffolding lives, leaving your main branch pristine.

#### How Git Worktrees Work

```
your-project/                    ← Main working directory (untouched)
├── src/
├── package.json
└── .git/

your-project-agentbase/          ← Worktree (isolated branch)
├── src/                         ← Same code, different branch
├── package.json
├── AGENTS.md                    ← NEW: scaffolding lives here
├── docs/philosophy.md           ← NEW
├── docs/triage.md               ← NEW
├── instructions/                ← NEW
└── progress/                    ← NEW
```

#### Step 1: Create the Worktree

```bash
# From within the repo
cd /path/to/your-project

# Create a new branch and worktree in one command
git worktree add ../your-project-agentbase -b agentbase-setup

# Or if you want it as a sibling directory with custom name
git worktree add ../your-project-agents -b agentbase/main
```

#### Step 2: Initialize in the Worktree

```bash
# Move to the worktree
cd ../your-project-agentbase

# Start claude and init
claude
# Then: /agentbase init
```

#### Step 3: Work in Isolation

All changes happen in the worktree branch. Your main branch stays clean.

```bash
# In worktree: make changes, test scaffolding
git add AGENTS.md docs/ instructions/ progress/
git commit -m "Add agentbase scaffolding"

# When ready to merge (from main repo):
cd ../your-project
git merge agentbase-setup

# Or cherry-pick specific files:
git checkout agentbase-setup -- AGENTS.md docs/ instructions/
```

#### Step 4: Clean Up (Optional)

```bash
# Remove worktree when done experimenting
git worktree remove ../your-project-agentbase

# Or keep it for ongoing parallel work
```

**Output for `/agentbase setup`:**

```
## AgentBase Setup: Isolated Worktree

Current repo: /path/to/your-project (branch: main)

This will create:
  Worktree: /path/to/your-project-agentbase
  Branch: agentbase-setup

Your main branch will NOT be modified.

Commands to run:
  git worktree add ../your-project-agentbase -b agentbase-setup
  cd ../your-project-agentbase
  claude
  # Then: /agentbase init

Proceed with worktree creation? [Y/n]
```

If user confirms, run the git worktree command via Bash tool.

---

### `worktree [workstream]` Command

**For true parallel isolation: one worktree per workstream.**

This is the ultimate scaling pattern - each workstream gets its own:
- Working directory
- Branch
- Claude session

#### The Pattern

```
your-project/                    ← Main (read-only reference)
your-project-frontend/           ← Worktree: frontend workstream
your-project-backend/            ← Worktree: backend workstream
your-project-api/                ← Worktree: api workstream
```

#### Create Workstream Worktree

```bash
# Create worktree for a specific workstream
git worktree add ../your-project-frontend -b agentbase/frontend

# Each worktree branches from the same base
git worktree add ../your-project-backend -b agentbase/backend
git worktree add ../your-project-api -b agentbase/api
```

#### Run Parallel Workers

```bash
# Terminal 1: Frontend worker
cd ../your-project-frontend
claude --print "/agentbase work frontend"

# Terminal 2: Backend worker
cd ../your-project-backend
claude --print "/agentbase work backend"

# Terminal 3: API worker
cd ../your-project-api
claude --print "/agentbase work api"
```

#### Merge Strategy

When workstreams complete:

```bash
# From main repo
cd your-project

# Merge each workstream (they don't conflict if scopes are correct)
git merge agentbase/frontend
git merge agentbase/backend
git merge agentbase/api

# Or rebase for cleaner history
git rebase agentbase/frontend
```

#### Why This Works

1. **No merge conflicts during work** - Each workstream owns different files
2. **True parallelism** - Separate processes, separate directories
3. **Easy rollback** - Just delete the worktree/branch
4. **Clean history** - Merge only validated changes

**Output for `/agentbase worktree frontend`:**

```
## AgentBase Worktree: frontend

Creating isolated worktree for frontend workstream...

Worktree: /path/to/your-project-frontend
Branch: agentbase/frontend
Scope: src/components/, src/hooks/, UI (from instructions/frontend.md)

Commands:
  git worktree add ../your-project-frontend -b agentbase/frontend
  cd ../your-project-frontend
  claude --print "/agentbase work frontend"

This workstream OWNS:
  - src/components/
  - src/hooks/
  - src/styles/

This workstream does NOT touch:
  - src/server/
  - src/api/
  - database/

Proceed? [Y/n]
```

---

## Recommended Workflow for Existing Codebases

```
1. SETUP (create isolated environment)
   /agentbase setup
   → Creates worktree, keeps main clean

2. INIT (in worktree)
   /agentbase init
   → Generates scaffolding in the worktree branch

3. TEST (validate the approach)
   /agentbase status
   /agentbase work <workstream>
   → Make sure it works before touching main

4. SCALE (optional: one worktree per workstream)
   /agentbase worktree frontend
   /agentbase worktree backend
   → True parallel isolation

5. MERGE (when validated)
   git merge agentbase-setup
   → Bring scaffolding into main only when ready
```

---

## Worker Prompt Template

When spawning workers, use this template:

```markdown
# Worker Agent: [WORKSTREAM]

You are a WORKER in the agentbase multi-agent system.

## Role
- Execute assigned tasks completely
- Do NOT coordinate with other workers
- Do NOT worry about the big picture
- Grind on your task until done, then report back

## Your Assignment
[SPECIFIC TASK]

## Scope (from instructions/[workstream].md)
**OWNS**: [list]
**DOES NOT OWN**: [list]

## Definition of Done
Your task is ONLY done if you can show a measurable delta:
- [ ] Test passes that previously failed
- [ ] Page renders that previously timed out
- [ ] Panic eliminated with regression test
- [ ] Accuracy improved (diff_percent decreased)

## Constraints
1. No page-specific hacks (no hostname checks, no magic numbers)
2. No panics - return errors cleanly
3. Spec-first: incomplete but correct > complete but wrong
4. Always use resource limits on commands

## When Blocked
If you cannot complete the task:
1. Document what you tried
2. Document what's blocking you
3. Suggest how to unblock
4. Report back to planner

Do not spin on a problem indefinitely.
```

---

## Multi-Session Scaling

For true parallel scaling beyond sub-agents, use multiple Claude Code sessions:

```bash
#!/bin/bash
# multi-session.sh - Run multiple agentbase sessions in parallel

WORKSTREAMS=("capability_buildout" "pageset_page_loop" "js_engine" "browser_chrome")

for ws in "${WORKSTREAMS[@]}"; do
  echo "Starting worker for $ws..."
  claude --print "use agentbase work $ws" &
done

wait
echo "All workers completed"
```

Or use tmux/screen for interactive monitoring:

```bash
tmux new-session -d -s agentbase
for ws in "${WORKSTREAMS[@]}"; do
  tmux new-window -t agentbase -n "$ws" "claude --print 'use agentbase work $ws'"
done
tmux attach -t agentbase
```

---

## Key Principles (from research)

1. **Role Separation**: You are the Planner. Workers execute. Judge evaluates.
2. **Non-Overlapping Ownership**: Each workstream has explicit owns/does-not-own.
3. **Measurable Outcomes**: "If you can't show a measurable delta, you are not done."
4. **Resource Safety**: Always use timeouts and memory limits.
5. **Committed Scoreboard**: Progress tracked in git via JSON files.
6. **Simplicity**: Remove complexity rather than add it.
7. **Prompts > Architecture**: These instructions ARE the coordination mechanism.

---

## Example Session

```
User: /agentbase status

AgentBase: [reads progress files, outputs status report]

User: /agentbase triage

AgentBase: [categorizes failures, outputs prioritized task list]

User: /agentbase parallel 3

AgentBase: [spawns 3 worker sub-agents in parallel on top priorities]

User: /agentbase judge

AgentBase: [evaluates progress, recommends next action]
```
