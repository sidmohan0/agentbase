# Installation

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed and authenticated
- Git (for worktree features)
- Bash (for multi-session script)

Optional:
- GitHub CLI (`gh`) for issue integration
- `tmux` for multi-session monitoring

## Installation Methods

### Method 1: Global Installation (Recommended)

Install once, available in all projects:

```bash
# Clone the repo
git clone https://github.com/sidmohan0/agentbase.git
cd agentbase

# Copy to global Claude Code skills directory
mkdir -p ~/.claude/skills
cp -r skill/ ~/.claude/skills/agentbase/
```

### Method 2: Project-Local Installation

Install per-project (committed to repo):

```bash
# From your project root
mkdir -p .claude/skills
git clone https://github.com/sidmohan0/agentbase.git /tmp/agentbase
cp -r /tmp/agentbase/skill/ .claude/skills/agentbase/
rm -rf /tmp/agentbase

# Optionally commit
git add .claude/skills/agentbase/
git commit -m "Add agentbase skill"
```

### Method 3: Direct Download

```bash
# Global
mkdir -p ~/.claude/skills/agentbase/scripts
curl -o ~/.claude/skills/agentbase/SKILL.md https://raw.githubusercontent.com/sidmohan0/agentbase/main/skill/SKILL.md
curl -o ~/.claude/skills/agentbase/scripts/multi-session.sh https://raw.githubusercontent.com/sidmohan0/agentbase/main/skill/scripts/multi-session.sh
chmod +x ~/.claude/skills/agentbase/scripts/multi-session.sh
```

## Verify Installation

```bash
# Start Claude Code
claude

# Check skill is available
/agentbase status
```

If scaffolding doesn't exist yet, you'll see:

```
## AgentBase: Scaffolding Required

This repo is not set up for agentbase orchestration.
Run `/agentbase init` to analyze this repo and generate the scaffolding.
```

## Initialize Your First Project

```bash
# In your project directory
claude

# Initialize agentbase scaffolding
/agentbase init
```

This will:
1. Analyze your project structure
2. Detect your tech stack
3. Propose workstreams
4. Generate coordination documents

## Troubleshooting

### Skill not found

Ensure the skill is in one of these locations:
- `~/.claude/skills/agentbase/SKILL.md` (global)
- `.claude/skills/agentbase/SKILL.md` (project-local)

### Permission denied on multi-session.sh

```bash
chmod +x ~/.claude/skills/agentbase/scripts/multi-session.sh
# or
chmod +x .claude/skills/agentbase/scripts/multi-session.sh
```

### AGENTS.md not found

Run `/agentbase init` to generate scaffolding, or `/agentbase setup` to create an isolated worktree first.

## Updating

```bash
# If installed via git clone
cd path/to/agentbase
git pull
cp -r skill/ ~/.claude/skills/agentbase/
```

## Uninstalling

```bash
# Global
rm -rf ~/.claude/skills/agentbase/

# Project-local
rm -rf .claude/skills/agentbase/
```
