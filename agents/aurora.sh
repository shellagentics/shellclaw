#!/bin/bash
# =============================================================================
# agents/aurora.sh — Aurora: system health and alerting specialist
# =============================================================================
#
# PURPOSE:
#   Aurora monitors system health, tracks metrics, detects anomalies, and
#   escalates issues with appropriate urgency. It maintains its own memory
#   and shares learnings with other agents via the filesystem.
#
# PERSONALITY (defined in souls/aurora.md):
#   - Alert-oriented: severity first, details second
#   - Uses clear severity levels: INFO, WARNING, CRITICAL
#   - Always includes actionable next steps
#   - Doesn't cry wolf — only escalates genuine concerns
#
# HOW IT WORKS:
#   1. Log the incoming request (observability)
#   2. Load persistent memory from previous sessions
#   3. Compose context (memory + current request)
#   4. Call the LLM with the soul file as system prompt
#   5. Log the response (observability)
#   6. Extract learnings and save to memory
#   7. Share learnings to the cross-agent filesystem
#   8. Output the result
#
# USAGE:
#   ./aurora.sh "Check system health status"
#   ./aurora.sh "Report on disk usage and any concerns"
#
# =============================================================================

# Exit immediately on error, undefined variable, or pipe failure.
set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

MSG="${1:-}"
AGENT="aurora"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL="$SCRIPT_DIR/../souls/aurora.md"
SHARED="$SCRIPT_DIR/../shared"

# =============================================================================
# TOOL DISCOVERY
# =============================================================================
# Find Shell Agentics primitives in PATH or local development paths.

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

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

export AGEN_LOG_DIR="$SCRIPT_DIR/../logs"
export AGEN_MEMORY_DIR="$SCRIPT_DIR/../memory"

# =============================================================================
# INPUT VALIDATION
# =============================================================================

if [[ -z "$MSG" ]]; then
  echo "Usage: aurora.sh <message>" >&2
  exit 1
fi

# =============================================================================
# STEP 1: LOG THE INCOMING REQUEST
# =============================================================================
# Create an audit trail entry for this request.

echo "$MSG" | "$AGEN_LOG" --agent "$AGENT" --event request

# =============================================================================
# STEP 2: LOAD PERSISTENT MEMORY
# =============================================================================
# Aurora might remember previous alerts, known issues, or baseline metrics.

MEMORY=$("$AGEN_MEMORY" read "$AGENT" 2>/dev/null || echo "No prior context.")

# =============================================================================
# STEP 3 & 4: COMPOSE CONTEXT AND CALL THE LLM
# =============================================================================
# Build the full context document and send to the LLM with Aurora's soul.

RESULT=$({
  echo "## Previous Context"
  echo "$MEMORY"
  echo ""
  echo "## Current Request"
  echo "$MSG"
} | "$AGEN" --system-file "$SOUL" "Process this request and respond concisely.")

# =============================================================================
# STEP 5: LOG THE RESPONSE
# =============================================================================
# Record Aurora's response for the audit trail.

echo "$RESULT" | "$AGEN_LOG" --agent "$AGENT" --event complete

# =============================================================================
# STEP 6: EXTRACT AND STORE LEARNINGS
# =============================================================================
# Aurora might learn about new baselines, recurring issues, or patterns.

LEARNINGS=$(echo "$RESULT" | "$AGEN" --system "Extract key facts learned as brief bullet points. If nothing new was learned, output only: none" 2>/dev/null || true)

if [[ -n "$LEARNINGS" ]] && [[ "$LEARNINGS" != "none" ]]; then
  # Save to Aurora's personal memory
  echo "$LEARNINGS" | "$AGEN_MEMORY" write "$AGENT"

  # =============================================================================
  # STEP 7: SHARE LEARNINGS TO CROSS-AGENT FILESYSTEM
  # =============================================================================
  # Aurora's learnings (alerts, metrics, concerns) are valuable for Lore's
  # synthesis and for other agents to be aware of system state.

  mkdir -p "$SHARED/learnings/$AGENT"
  {
    echo "### $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "$LEARNINGS"
    echo ""
  } >> "$SHARED/learnings/$AGENT/$(date -I).md"
fi

# =============================================================================
# STEP 8: OUTPUT THE RESULT
# =============================================================================

echo "$RESULT"
