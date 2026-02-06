#!/bin/bash
# shellclaw/demo.sh — Demonstrate the multi-agent system
#
# Runs agent-1 and agent-2, then shows the audit trail, memory, and shared
# learnings. Uses the stub backend by default so it works without LLM calls.
#
# Usage: ./demo.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Tool discovery ---

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

# --- Environment ---

export AGEN_BACKEND="${AGEN_BACKEND:-stub}"
export AGEN_LOG_DIR="$SCRIPT_DIR/logs"
export AGEN_MEMORY_DIR="$SCRIPT_DIR/memory"
mkdir -p "$AGEN_LOG_DIR" "$AGEN_MEMORY_DIR"

# Reset stub counter for a clean demo
if [[ "$AGEN_BACKEND" == "stub" ]]; then
  rm -f "${AGEN_STUB_FILE:-/tmp/agen-stub-counter}"
fi

echo "=== Shellclaw Demo (backend: $AGEN_BACKEND) ==="
echo ""

# --- Agent 1 ---

echo "[agent-1] Running..."
./agents/agent-1.sh "Describe what you would check to verify system health."
echo ""

# --- Agent 2 (reads agent-1's shared output) ---

echo "[agent-2] Running (reads agent-1's shared learnings)..."
./agents/agent-2.sh "Summarize what other agents have reported today."
echo ""

# --- Audit trail ---

echo "=== Audit Trail ==="
"$AGEN_AUDIT" --today --log-dir "$AGEN_LOG_DIR" --format pretty || echo "(no logs yet)"

# --- Agent memory ---

echo ""
echo "=== Agent Memory ==="
for agent in agent-1 agent-2; do
  echo "[$agent]"
  "$AGEN_MEMORY" list "$agent" --memory-dir "$AGEN_MEMORY_DIR" 2>/dev/null | sed 's/^/  /' || echo "  (no memory yet)"
done

# --- Shared learnings ---

echo ""
echo "=== Shared Learnings ==="
if ls shared/learnings/*/"$(date -I)".md &>/dev/null; then
  ls -la shared/learnings/*/"$(date -I)".md
else
  echo "(no shared learnings today)"
fi

echo ""
echo "Try:"
echo "  cat logs/all.jsonl | jq ."
echo "  cat memory/agent-1/_general.md"
echo "  cat shared/learnings/agent-1/$(date -I).md"
echo "  AGEN_BACKEND=claude-code ./demo.sh    # run with a real LLM"
