#!/bin/bash
# agents/agent-2.sh — Agent pattern with cross-agent coordination
#
# Same 8-step pattern as agent-1, plus one extra step: read other agents'
# shared learnings before composing context. This is how agents coordinate
# through the filesystem — no message passing, no RPC, just files.
#
# Usage: ./agent-2.sh "your request here"

set -euo pipefail

MSG="${1:-}"
AGENT="agent-2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL="$SCRIPT_DIR/../souls/agent-2.md"
SHARED="$SCRIPT_DIR/../shared"

# --- Tool discovery ---

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
  echo "Usage: agent-2.sh <message>" >&2
  exit 1
fi

# Step 1: Log the request
echo "$MSG" | "$ALOG" --agent "$AGENT" --event request

# Step 2: Load persistent memory
MEMORY=$("$AMEM" read "$AGENT" 2>/dev/null || echo "No prior context.")

# Step 3: Gather other agents' learnings from the shared filesystem
TEAM_LEARNINGS=""
for agent_dir in "$SHARED"/learnings/*/; do
  [[ -d "$agent_dir" ]] || continue
  agent_name=$(basename "$agent_dir")
  today_file="$agent_dir/$(date -I).md"
  if [[ -f "$today_file" ]]; then
    TEAM_LEARNINGS+="## $agent_name"$'\n'
    TEAM_LEARNINGS+=$(cat "$today_file")
    TEAM_LEARNINGS+=$'\n\n'
  fi
done
if [[ -z "$TEAM_LEARNINGS" ]]; then
  TEAM_LEARNINGS="No team learnings recorded today."
fi

# Steps 4-5: Compose context (with team learnings) and call the LLM
RESULT=$({
  echo "## Previous Context"
  echo "$MEMORY"
  echo ""
  echo "## Team Learnings Today"
  echo "$TEAM_LEARNINGS"
  echo ""
  echo "## Current Request"
  echo "$MSG"
} | "$AGENT_BIN" --system-file "$SOUL" "Process this request and respond concisely.")

# Step 6: Log the response
echo "$RESULT" | "$ALOG" --agent "$AGENT" --event complete

# Step 7: Extract and store learnings
LEARNINGS=$(echo "$RESULT" | "$AGENT_BIN" --system "Extract key facts learned as brief bullet points. If nothing new was learned, output only: none" 2>/dev/null || true)

if [[ -n "$LEARNINGS" ]] && [[ "$LEARNINGS" != "none" ]]; then
  echo "$LEARNINGS" | "$AMEM" write "$AGENT"

  # Step 8: Share learnings to cross-agent filesystem
  mkdir -p "$SHARED/learnings/$AGENT"
  {
    echo "### $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "$LEARNINGS"
    echo ""
  } >> "$SHARED/learnings/$AGENT/$(date -I).md"
fi

# Step 9: Output the result
echo "$RESULT"
