#!/bin/bash
# shellclaw/demo.sh — Demonstrate the multi-agent system
#
# This script runs all three agents and shows the audit trail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Find agen-audit
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

# Ensure directories exist
export AGEN_LOG_DIR="$SCRIPT_DIR/logs"
export AGEN_MEMORY_DIR="$SCRIPT_DIR/memory"
mkdir -p "$AGEN_LOG_DIR" "$AGEN_MEMORY_DIR"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SHELLCLAW DEMO                            ║"
echo "║  A shell-native multi-agent system with full observability   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ 1. ASKING DATA TO VERIFY BACKUPS                              │"
echo "└────────────────────────────────────────────────────────────────┘"
./agents/data.sh "Verify backup integrity for today. List what you would check."
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ 2. ASKING AURORA ABOUT SYSTEM HEALTH                          │"
echo "└────────────────────────────────────────────────────────────────┘"
./agents/aurora.sh "Report on system health. What metrics would you examine?"
echo ""

echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ 3. ASKING LORE TO SYNTHESIZE                                  │"
echo "└────────────────────────────────────────────────────────────────┘"
./agents/lore.sh "Generate a brief status summary based on team learnings today."
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      AUDIT TRAIL                             ║"
echo "║  Every action is logged. Query with grep, jq, or agen-audit  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
"$AGEN_AUDIT" --today --log-dir "$AGEN_LOG_DIR" --format pretty || echo "(no logs yet)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     AGENT MEMORY                             ║"
echo "║  Persistent state as files. cat, diff, git your memory.     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
for agent in data aurora lore; do
  echo "[$agent]"
  "$AGEN_MEMORY" list "$agent" --memory-dir "$AGEN_MEMORY_DIR" 2>/dev/null | sed 's/^/  /' || echo "  (no memory yet)"
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   SHARED LEARNINGS                           ║"
echo "║  Agents coordinate through the filesystem.                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
if ls shared/learnings/*/"$(date -I)".md &>/dev/null; then
  ls -la shared/learnings/*/"$(date -I)".md
else
  echo "(no shared learnings today)"
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo "Demo complete. The thesis: everything is inspectable."
echo ""
echo "Try:"
echo "  cat logs/all.jsonl | jq ."
echo "  cat memory/data/_general.md"
echo "  diff logs/data.jsonl logs/aurora.jsonl"
echo "────────────────────────────────────────────────────────────────"
