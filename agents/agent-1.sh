#!/bin/bash
# agents/agent-1.sh — The basic 8-step agent pattern
#
# This is the core pattern: log, remember, think, log, learn, share, output.
# Everything an agent does is visible as files on disk.
#
# Usage: ./agent-1.sh "your request here"

set -euo pipefail

MSG="${1:-}"
AGENT="agent-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL="$SCRIPT_DIR/../souls/agent-1.md"
SHARED="$SCRIPT_DIR/../shared"

# --- Tool discovery ---
# Find Shell Agentics primitives in PATH or sibling directories.

find_tool() {
  local tool="$1"
  if command -v "$tool" &>/dev/null; then
    echo "$tool"
  elif [[ -x "$SCRIPT_DIR/../../$tool/$tool" ]]; then
    echo "$SCRIPT_DIR/../../$tool/$tool"
  else
    echo "Error: $tool not found in PATH or local dev paths" >&2
    exit 1
  fi
}

AGENT_BIN=$(find_tool agent)
ALOG=$(find_tool alog)
AMEM=$(find_tool amem)

export AGENT_LOG_DIR="$SCRIPT_DIR/../logs"
export AGENT_MEMORY_DIR="$SCRIPT_DIR/../memory"

if [[ -z "$MSG" ]]; then
  echo "Usage: agent-1.sh <message>" >&2
  exit 1
fi

# Step 1: Log the request
echo "$MSG" | "$ALOG" --agent "$AGENT" --event request

# Step 2: Load persistent memory
MEMORY=$("$AMEM" read "$AGENT" 2>/dev/null || echo "No prior context.")

# Steps 3-4: Compose context and call the LLM
RESULT=$({
  echo "## Previous Context"
  echo "$MEMORY"
  echo ""
  echo "## Current Request"
  echo "$MSG"
} | "$AGENT_BIN" --system-file "$SOUL" "Process this request and respond concisely.")

# Step 5: Log the response
echo "$RESULT" | "$ALOG" --agent "$AGENT" --event complete

# Step 6: Extract and store learnings
LEARNINGS=$(echo "$RESULT" | "$AGENT_BIN" --system "Extract key facts learned as brief bullet points. If nothing new was learned, output only: none" 2>/dev/null || true)

if [[ -n "$LEARNINGS" ]] && [[ "$LEARNINGS" != "none" ]]; then
  echo "$LEARNINGS" | "$AMEM" write "$AGENT"

  # Step 7: Share learnings to cross-agent filesystem
  mkdir -p "$SHARED/learnings/$AGENT"
  {
    echo "### $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "$LEARNINGS"
    echo ""
  } >> "$SHARED/learnings/$AGENT/$(date -I).md"
fi

# Step 8: Output the result
echo "$RESULT"
