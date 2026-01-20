# Concepts: Planner-Worker-Judge Architecture

This document explains the multi-agent architecture that AgentBase implements, based on [Cursor's research](https://cursor.com/blog/scaling-agents) on scaling autonomous coding agents.

## The Problem

Single agents work well on focused tasks but struggle with:
- Complex, long-running projects
- Parallel development across multiple areas
- Coordination without bottlenecks

Flat hierarchies (equal-status agents) fail because:
- Agents become risk-averse, avoiding difficult work
- Duplicate efforts occur
- Lock contention creates bottlenecks

## The Solution: Hierarchical Roles

### You (Master Orchestrator)

You are the human in charge. Your responsibilities:

- **Set goals** - What should the system accomplish?
- **Review reports** - The Agent Planner reports progress periodically
- **Intervene when needed** - Stop, pivot, or provide guidance
- **Approve major decisions** - The system asks when blocked

You don't manage individual tasks—you set direction and review outcomes.

### Agent Planner (Autonomous)

The Agent Planner runs continuously when you invoke `/agentbase go`. It:

- **Discovers tasks** from tests, errors, issues, TODOs
- **Triages and prioritizes** based on severity
- **Spawns workers** with specific assignments
- **Evaluates progress** (the Judge function)
- **Reports back to you** periodically
- **Decides when to stop** - goal achieved, blocked, or stalled

The Agent Planner never writes code directly—it coordinates.

### Workers

Workers are sub-agents spawned by the Agent Planner via Claude's Task tool. They:

- **Focus entirely on their assigned task**
- **Do NOT coordinate with other workers**
- **Do NOT worry about the big picture**
- **Work until done or blocked**, then report back

This isolation is key. Workers don't need to know what other workers are doing because workstream ownership ensures non-overlapping scope.

### Judge

The Judge function (built into the Agent Planner) evaluates progress after each cycle:

- **CONTINUE**: Progress being made, work remains
- **GOAL ACHIEVED**: All priority tasks done, stop with success
- **STALLED**: No progress for 2 cycles, report to human and stop
- **BLOCKED**: Worker hit unresolvable issue, report to human and stop

## Workstreams

A **workstream** is a scope of ownership. Examples:

| Workstream | Owns | Does NOT Own |
|------------|------|--------------|
| `frontend` | `src/components/`, `src/hooks/` | `src/api/`, database |
| `backend` | `src/server/`, `src/services/` | UI components |
| `api` | Route handlers, validation | Database queries |

Each workstream has an `instructions/<name>.md` file defining its scope.

**Why this matters:** When workstreams don't overlap, workers can operate in parallel without conflicts. The frontend worker can modify components while the backend worker modifies services—no merge conflicts.

## Task Discovery

Tasks come from the codebase, not manual entry:

```
Failing Tests → P0-P1 (highest priority)
Type Errors   → P1-P2
GitHub Issues → P2-P4
TODOs/FIXMEs  → P3-P5
Coverage Gaps → P3-P4
```

This ensures work is always grounded in reality—you fix what's actually broken.

## The Coordination Loop

```
1. TRIAGE
   └─> Discover tasks, prioritize by severity

2. PLAN
   └─> Assign tasks to workstreams

3. WORK
   └─> Spawn workers for each workstream

4. JUDGE
   └─> Evaluate progress
       ├─> CONTINUE → Go to step 3
       ├─> PIVOT    → Go to step 2 with new approach
       └─> STOP     → Human intervention needed
```

## Key Insights from Cursor's Research

### "Prompting outweighs infrastructure"

> "A surprising amount of the system's behavior comes down to how we prompt the agents."

AgentBase is primarily a collection of prompts. The `SKILL.md` file IS the system—there's no complex runtime, no message queues, no databases. Claude's Task tool handles spawning, and git handles state.

### "Simplicity wins"

Cursor removed an "integrator" role they initially designed for conflict resolution. Workers handled conflicts independently.

AgentBase follows this principle: workstreams prevent conflicts by design, so no integrator is needed.

### Measurable outcomes

> "If you can't show a measurable delta, you are not done."

Workers must demonstrate:
- Test passes that previously failed
- Page renders that previously timed out
- Panic eliminated with regression test
- Accuracy improved (metric decreased)

Vague "improvements" don't count.

## Scaling Beyond Sub-Agents

Claude's Task tool spawns sub-agents that share the session's context. For true parallelism:

1. **Git worktrees** - Each workstream gets its own directory and branch
2. **Multiple Claude sessions** - Run `claude` in each worktree
3. **Multi-session script** - `multi-session.sh` automates this

This enables hundreds of agents working in parallel, limited only by compute.
