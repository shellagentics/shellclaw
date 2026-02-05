#!/bin/bash
# agents/data.sh — Data: backup and monitoring specialist
#
# Usage: ./data.sh "Verify backup integrity for today"

set -euo pipefail

MSG="${1:-}"
AGENT="data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL="$SCRIPT_DIR/../souls/data.md"
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
  echo "Usage: data.sh <message>" >&2
  exit 1
fi

# 1. Log incoming request
echo "$MSG" | "$AGEN_LOG" --agent "$AGENT" --event request

# 2. Load persistent memory
MEMORY=$("$AGEN_MEMORY" read "$AGENT" 2>/dev/null || echo "No prior context.")

# 3. Compose context and consult the LLM
RESULT=$({
  echo "## Previous Context"
  echo "$MEMORY"
  echo ""
  echo "## Current Request"
  echo "$MSG"
} | "$AGEN" --system-file "$SOUL" "Process this request and respond concisely.")

# 4. Log the response
echo "$RESULT" | "$AGEN_LOG" --agent "$AGENT" --event complete

# 5. Extract and store learnings
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

# 6. Return response to caller
echo "$RESULT"
