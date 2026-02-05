#!/bin/bash
# agents/lore.sh — Lore: orchestrator and synthesizer
#
# Usage: ./lore.sh "Generate morning briefing from team learnings"

set -euo pipefail

MSG="${1:-}"
AGENT="lore"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL="$SCRIPT_DIR/../souls/lore.md"
SHARED="$SCRIPT_DIR/../shared"

# Find tools (check PATH first, then local dev paths)
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

AGEN=$(find_tool agen)
AGEN_LOG=$(find_tool agen-log)
AGEN_MEMORY=$(find_tool agen-memory)

# Set environment for primitives
export AGEN_LOG_DIR="$SCRIPT_DIR/../logs"
export AGEN_MEMORY_DIR="$SCRIPT_DIR/../memory"

# Require a message
if [[ -z "$MSG" ]]; then
  echo "Usage: lore.sh <message>" >&2
  exit 1
fi

# 1. Log incoming request
echo "$MSG" | "$AGEN_LOG" --agent "$AGENT" --event request

# 2. Load persistent memory
MEMORY=$("$AGEN_MEMORY" read "$AGENT" 2>/dev/null || echo "No prior context.")

# 3. Gather team learnings (Lore's special ability)
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

# 4. Compose context and consult the LLM
RESULT=$({
  echo "## Previous Context"
  echo "$MEMORY"
  echo ""
  echo "## Team Learnings Today"
  echo "$TEAM_LEARNINGS"
  echo ""
  echo "## Current Request"
  echo "$MSG"
} | "$AGEN" --system-file "$SOUL" "Process this request and respond concisely.")

# 5. Log the response
echo "$RESULT" | "$AGEN_LOG" --agent "$AGENT" --event complete

# 6. Extract and store learnings
LEARNINGS=$(echo "$RESULT" | "$AGEN" --system "Extract key facts learned as brief bullet points. If nothing new was learned, output only: none" 2>/dev/null || true)

if [[ -n "$LEARNINGS" ]] && [[ "$LEARNINGS" != "none" ]]; then
  echo "$LEARNINGS" | "$AGEN_MEMORY" write "$AGENT"

  # Share to cross-agent learnings
  mkdir -p "$SHARED/learnings/$AGENT"
  {
    echo "### $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "$LEARNINGS"
    echo ""
  } >> "$SHARED/learnings/$AGENT/$(date -I).md"
fi

# 7. Return response to caller
echo "$RESULT"
