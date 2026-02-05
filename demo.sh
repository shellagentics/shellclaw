#!/bin/bash
# =============================================================================
# shellclaw/demo.sh — Demonstrate the multi-agent system
# =============================================================================
#
# PURPOSE:
#   This script runs all three Shellclaw agents and demonstrates the
#   observability features. It's designed to show the complete picture:
#   agents receiving requests, producing responses, and leaving auditable
#   traces in logs and memory.
#
# WHAT IT DEMONSTRATES:
#   1. Multi-agent execution — three agents with different specialties
#   2. Audit trail — every action logged as JSONL, queryable with agen-audit
#   3. Agent memory — persistent state stored as files
#   4. Cross-agent coordination — shared learnings via filesystem
#
# USAGE:
#   cd shellclaw && ./demo.sh
#
# =============================================================================

# Exit immediately on error, undefined variable, or pipe failure.
set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================
# Change to the script's directory so relative paths work correctly.
# This allows running the demo from any location.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# TOOL DISCOVERY
# =============================================================================
# Find the Shell Agentics primitives. We need agen-audit and agen-memory
# for the audit trail and memory inspection sections of the demo.

find_tool() {
  local tool="$1"
  if command -v "$tool" &>/dev/null; then
    echo "$tool"
  elif [[ -x "$SCRIPT_DIR/../$tool/$tool" ]]; then
    echo "$SCRIPT_DIR/../$tool/$tool"
  else
    echo "Error: $tool not found" >&2
    exit 1
  fi
}

AGEN_AUDIT=$(find_tool agen-audit)
AGEN_MEMORY=$(find_tool agen-memory)

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================
# Configure where logs and memory are stored.
# Create the directories if they don't exist.

export AGEN_LOG_DIR="$SCRIPT_DIR/logs"
export AGEN_MEMORY_DIR="$SCRIPT_DIR/memory"
mkdir -p "$AGEN_LOG_DIR" "$AGEN_MEMORY_DIR"

# =============================================================================
# DEMO HEADER
# =============================================================================
# ASCII art box to make the demo output visually clear.

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SHELLCLAW DEMO                            ║"
echo "║  A shell-native multi-agent system with full observability   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# AGENT 1: DATA
# =============================================================================
# Data is the backup and monitoring specialist. We ask it about backup
# verification to demonstrate its domain expertise.

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ 1. ASKING DATA TO VERIFY BACKUPS                              │"
echo "└────────────────────────────────────────────────────────────────┘"
./agents/data.sh "Verify backup integrity for today. List what you would check."
echo ""

# =============================================================================
# AGENT 2: AURORA
# =============================================================================
# Aurora is the system health monitor. We ask it about system health
# to demonstrate its alert-oriented communication style.

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ 2. ASKING AURORA ABOUT SYSTEM HEALTH                          │"
echo "└────────────────────────────────────────────────────────────────┘"
./agents/aurora.sh "Report on system health. What metrics would you examine?"
echo ""

# =============================================================================
# AGENT 3: LORE
# =============================================================================
# Lore is the synthesizer. It has access to learnings from all other agents.
# We ask it to synthesize, demonstrating multi-agent coordination.

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ 3. ASKING LORE TO SYNTHESIZE                                  │"
echo "└────────────────────────────────────────────────────────────────┘"
./agents/lore.sh "Generate a brief status summary based on team learnings today."
echo ""

# =============================================================================
# AUDIT TRAIL SECTION
# =============================================================================
# This is the key observability demonstration. Every agent action was logged.
# We can now query those logs to see exactly what happened.

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      AUDIT TRAIL                             ║"
echo "║  Every action is logged. Query with grep, jq, or agen-audit  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Use agen-audit to show today's events in human-readable format.
# The || echo handles the case where there are no logs yet.
"$AGEN_AUDIT" --today --log-dir "$AGEN_LOG_DIR" --format pretty || echo "(no logs yet)"

# =============================================================================
# AGENT MEMORY SECTION
# =============================================================================
# Show what each agent has stored in memory. This demonstrates that
# agents have persistent state that survives between runs.

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     AGENT MEMORY                             ║"
echo "║  Persistent state as files. cat, diff, git your memory.     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# List memory keys for each agent
for agent in data aurora lore; do
  echo "[$agent]"
  # The sed command indents the output for readability
  # The 2>/dev/null || handles first-run case where memory doesn't exist
  "$AGEN_MEMORY" list "$agent" --memory-dir "$AGEN_MEMORY_DIR" 2>/dev/null | sed 's/^/  /' || echo "  (no memory yet)"
done

# =============================================================================
# SHARED LEARNINGS SECTION
# =============================================================================
# Show the cross-agent coordination mechanism: the shared filesystem.
# Agents write their learnings here; other agents (especially Lore) read them.

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   SHARED LEARNINGS                           ║"
echo "║  Agents coordinate through the filesystem.                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if any agent wrote learnings today
# The quotes around $(date -I) prevent word splitting (shellcheck fix)
if ls shared/learnings/*/"$(date -I)".md &>/dev/null; then
  ls -la shared/learnings/*/"$(date -I)".md
else
  echo "(no shared learnings today)"
fi

# =============================================================================
# DEMO FOOTER
# =============================================================================
# Provide helpful commands for further exploration.

echo ""
echo "────────────────────────────────────────────────────────────────"
echo "Demo complete. The thesis: everything is inspectable."
echo ""
echo "Try:"
echo "  cat logs/all.jsonl | jq ."
echo "  cat memory/data/_general.md"
echo "  diff logs/data.jsonl logs/aurora.jsonl"
echo "────────────────────────────────────────────────────────────────"
