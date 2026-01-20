#!/bin/bash
#
# multi-session.sh - Run multiple agentbase workers in parallel
#
# This script spawns multiple Claude Code sessions, each working on
# a different workstream. Supports both shared-directory and worktree modes.
#
# Usage:
#   ./multi-session.sh                    # Run all workstreams (shared dir)
#   ./multi-session.sh --worktrees        # Run with isolated worktrees (recommended)
#   ./multi-session.sh --tmux             # Run in tmux for monitoring
#   ./multi-session.sh --setup            # Create worktrees for all workstreams
#   ./multi-session.sh --discover         # Run task discovery before starting
#   ./multi-session.sh ws1 ws2 ws3        # Run specific workstreams
#
# Worktree mode creates:
#   ../project-ws1/  (branch: agentbase/ws1)
#   ../project-ws2/  (branch: agentbase/ws2)
#   etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"
PARENT_DIR="$(dirname "$REPO_ROOT")"
LOG_DIR="${REPO_ROOT}/.agentbase/logs"
PIDS_FILE="${REPO_ROOT}/.agentbase/pids"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[agentbase]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1" >&2; }
success() { echo -e "${GREEN}[success]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }

# Parse workstreams from AGENTS.md
get_workstreams() {
    local agents_file="${REPO_ROOT}/AGENTS.md"
    if [[ ! -f "$agents_file" ]]; then
        agents_file="${PARENT_DIR}/${REPO_NAME}-agentbase/AGENTS.md"
    fi
    if [[ ! -f "$agents_file" ]]; then
        error "AGENTS.md not found. Run '/agentbase init' first."
        exit 1
    fi
    grep -oE 'instructions/[a-z_]+\.md' "$agents_file" 2>/dev/null | \
        sed 's|instructions/||g; s|\.md||g' | sort -u
}

# Check if worktree exists
worktree_exists() {
    local ws="$1"
    local wt_path="${PARENT_DIR}/${REPO_NAME}-${ws}"
    [[ -d "$wt_path" ]]
}

# Create worktree for a workstream
create_worktree() {
    local ws="$1"
    local wt_path="${PARENT_DIR}/${REPO_NAME}-${ws}"
    local branch="agentbase/${ws}"

    if worktree_exists "$ws"; then
        warn "Worktree already exists: $wt_path"
        return 0
    fi

    log "Creating worktree for ${CYAN}${ws}${NC}..."
    cd "$REPO_ROOT"
    git worktree add "$wt_path" -b "$branch" 2>/dev/null || \
        git worktree add "$wt_path" "$branch" 2>/dev/null || {
            error "Failed to create worktree for $ws"
            return 1
        }
    success "Created: $wt_path (branch: $branch)"
}

# Setup all worktrees
setup_worktrees() {
    local workstreams=("$@")

    log "Setting up worktrees for ${#workstreams[@]} workstreams..."

    if [[ ! -f "${REPO_ROOT}/AGENTS.md" ]]; then
        local setup_path="${PARENT_DIR}/${REPO_NAME}-agentbase"
        if [[ ! -d "$setup_path" ]]; then
            log "Creating agentbase-setup worktree..."
            cd "$REPO_ROOT"
            git worktree add "$setup_path" -b agentbase-setup 2>/dev/null || \
                git worktree add "$setup_path" agentbase-setup
            success "Created: $setup_path"
            echo -e "\n${YELLOW}Next steps:${NC}"
            echo "  cd $setup_path && claude"
            echo "  /agentbase init"
            return 0
        fi
    fi

    for ws in "${workstreams[@]}"; do
        create_worktree "$ws"
    done

    success "All worktrees created!"
    echo -e "\nWorktrees:"
    for ws in "${workstreams[@]}"; do
        echo "  ${PARENT_DIR}/${REPO_NAME}-${ws}"
    done
}

# Run task discovery
run_discovery() {
    log "Running task discovery..."
    mkdir -p "${REPO_ROOT}/progress"

    local tasks_file="${REPO_ROOT}/progress/tasks.json"
    local tasks=()

    # Test failures
    log "Checking for test failures..."
    if [[ -f "package.json" ]]; then
        npm test 2>&1 | grep -E "FAIL|Error" | head -10 | while read line; do
            echo "  [P1] $line"
        done
    fi

    # TypeScript errors
    if [[ -f "tsconfig.json" ]]; then
        log "Checking TypeScript errors..."
        npx tsc --noEmit 2>&1 | grep -E "error TS" | head -10 | while read line; do
            echo "  [P1] $line"
        done
    fi

    # TODOs/FIXMEs
    log "Scanning for TODOs/FIXMEs..."
    grep -rn "TODO\|FIXME" src/ 2>/dev/null | head -10 | while read line; do
        echo "  [P4] $line"
    done

    # Coverage (if available)
    if [[ -f "coverage/coverage-summary.json" ]]; then
        log "Checking coverage gaps..."
        cat coverage/coverage-summary.json | head -20
    fi

    success "Discovery complete. Run '/agentbase triage' for full analysis."
}

# Run worker in worktree
run_worker_worktree() {
    local ws="$1"
    local wt_path="${PARENT_DIR}/${REPO_NAME}-${ws}"
    local log_file="${LOG_DIR}/${ws}.log"

    if ! worktree_exists "$ws"; then
        create_worktree "$ws"
    fi

    mkdir -p "$LOG_DIR"
    log "Starting worker: ${CYAN}${ws}${NC} (worktree)"

    cd "$wt_path"
    claude --print "/agentbase work ${ws}" > "${log_file}" 2>&1 &
    echo "${ws}:$!:worktree" >> "$PIDS_FILE"
}

# Run worker in shared directory
run_worker_shared() {
    local ws="$1"
    local log_file="${LOG_DIR}/${ws}.log"

    mkdir -p "$LOG_DIR"
    log "Starting worker: ${CYAN}${ws}${NC}"

    cd "$REPO_ROOT"
    claude --print "/agentbase work ${ws}" > "${log_file}" 2>&1 &
    echo "${ws}:$!:shared" >> "$PIDS_FILE"
}

# Run in tmux with worktrees
run_tmux() {
    local mode="$1"
    shift
    local workstreams=("$@")
    local session="agentbase-$(date +%H%M%S)"

    if [[ "$mode" == "worktrees" ]]; then
        for ws in "${workstreams[@]}"; do
            worktree_exists "$ws" || create_worktree "$ws"
        done
    fi

    log "Creating tmux session: ${session}"

    local first_ws="${workstreams[0]}"
    local first_dir="$REPO_ROOT"
    [[ "$mode" == "worktrees" ]] && first_dir="${PARENT_DIR}/${REPO_NAME}-${first_ws}"

    tmux new-session -d -s "$session" -n "${first_ws}" \
        "cd '$first_dir' && claude; read -p 'Press enter...'"

    for ws in "${workstreams[@]:1}"; do
        local ws_dir="$REPO_ROOT"
        [[ "$mode" == "worktrees" ]] && ws_dir="${PARENT_DIR}/${REPO_NAME}-${ws}"
        tmux new-window -t "$session" -n "$ws" \
            "cd '$ws_dir' && claude; read -p 'Press enter...'"
    done

    tmux new-window -t "$session" -n "planner" "cd '$REPO_ROOT' && claude"

    success "Tmux session: ${session}"
    echo "Attach: tmux attach -t ${session}"

    read -p "Attach now? [Y/n] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]] && tmux attach -t "$session"
}

# Show status
show_status() {
    echo "=== Worktrees ==="
    cd "$REPO_ROOT" && git worktree list
    echo ""

    if [[ -f "$PIDS_FILE" ]]; then
        echo "=== Workers ==="
        while IFS=: read -r ws pid mode; do
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "  ${GREEN}[running]${NC} ${ws} (${mode})"
            else
                echo -e "  ${RED}[stopped]${NC} ${ws}"
            fi
        done < "$PIDS_FILE"
    fi

    if [[ -f "${REPO_ROOT}/progress/tasks.json" ]]; then
        echo ""
        echo "=== Tasks ==="
        cat "${REPO_ROOT}/progress/tasks.json" | head -20
    fi
}

# Stop workers
stop_workers() {
    [[ -f "$PIDS_FILE" ]] || { log "No workers running"; return; }

    while IFS=: read -r ws pid mode; do
        kill -0 "$pid" 2>/dev/null && kill "$pid" && log "Stopped $ws"
    done < "$PIDS_FILE"

    rm -f "$PIDS_FILE"
    success "All workers stopped"
}

# Cleanup
cleanup() {
    local workstreams=("$@")
    for ws in "${workstreams[@]}"; do
        local wt="${PARENT_DIR}/${REPO_NAME}-${ws}"
        [[ -d "$wt" ]] && { cd "$REPO_ROOT"; git worktree remove "$wt" --force 2>/dev/null || rm -rf "$wt"; }
    done
    git worktree prune 2>/dev/null
    success "Cleanup complete"
}

# Help
show_help() {
    cat << EOF
AgentBase Multi-Session Runner

Usage: $0 [options] [workstreams...]

Modes:
  --worktrees    Use isolated git worktrees (recommended for parallel work)
  --shared       Use shared directory (default)
  --tmux         Run in tmux for monitoring

Commands:
  --setup        Create worktrees for all workstreams
  --discover     Run task discovery (tests, types, TODOs, coverage)
  --status       Show worktrees and workers
  --stop         Stop all workers
  --cleanup      Remove all worktrees
  --help         Show this help

Examples:
  $0 --discover                 # Find tasks first
  $0 --setup                    # Create worktrees
  $0 --worktrees --tmux         # Run in tmux with worktrees
  $0 frontend backend           # Run specific workstreams

EOF
}

# Main
main() {
    local mode="shared"
    local use_tmux=false
    local command=""
    local workstreams=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktrees)  mode="worktrees"; shift ;;
            --shared)     mode="shared"; shift ;;
            --tmux)       use_tmux=true; shift ;;
            --setup)      command="setup"; shift ;;
            --discover)   command="discover"; shift ;;
            --status)     command="status"; shift ;;
            --stop)       command="stop"; shift ;;
            --cleanup)    command="cleanup"; shift ;;
            --help|-h)    show_help; exit 0 ;;
            -*)           error "Unknown: $1"; exit 1 ;;
            *)            workstreams+=("$1"); shift ;;
        esac
    done

    [[ ${#workstreams[@]} -eq 0 ]] && mapfile -t workstreams < <(get_workstreams)

    case "$command" in
        setup)    setup_worktrees "${workstreams[@]}"; exit 0 ;;
        discover) run_discovery; exit 0 ;;
        status)   show_status; exit 0 ;;
        stop)     stop_workers; exit 0 ;;
        cleanup)  cleanup "${workstreams[@]}"; exit 0 ;;
    esac

    [[ ${#workstreams[@]} -eq 0 ]] && { error "No workstreams found"; exit 1; }

    log "Mode: $mode | Workstreams: ${workstreams[*]}"

    if $use_tmux; then
        run_tmux "$mode" "${workstreams[@]}"
    else
        rm -f "$PIDS_FILE"; touch "$PIDS_FILE"
        for ws in "${workstreams[@]}"; do
            [[ "$mode" == "worktrees" ]] && run_worker_worktree "$ws" || run_worker_shared "$ws"
            sleep 1
        done
        success "Workers started | Logs: $LOG_DIR"
    fi
}

main "$@"
