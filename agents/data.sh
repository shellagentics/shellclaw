#!/bin/bash
# =============================================================================
# agents/data.sh — Data: backup and monitoring specialist
# =============================================================================
#
# PURPOSE:
#   Data is a specialist agent focused on backup verification, checksum
#   validation, and system monitoring. It maintains its own memory and
#   shares learnings with other agents via the filesystem.
#
# PERSONALITY (defined in souls/data.md):
#   - Precise, factual, minimal communication
#   - Leads with status, follows with details
#   - States exactly what commands it would run
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
#   ./data.sh "Verify backup integrity for today"
#   ./data.sh "Check the status of weekly backup jobs"
#
# =============================================================================

# Exit immediately on error, undefined variable, or pipe failure.
# This is critical for agent scripts — we want to fail loudly, not silently.
set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# The message/request to process (passed as first argument)
MSG="${1:-}"

# Agent identity — used for logging, memory, and learnings
AGENT="data"

# Find the directory where this script lives.
# This allows the script to work regardless of where it's called from.
# BASH_SOURCE[0] is the path to this script, even if called via symlink.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the soul file — defines this agent's personality and rules
# The soul file is a Markdown document that becomes the LLM's system prompt
SOUL="$SCRIPT_DIR/../souls/data.md"

# Path to the shared filesystem where agents coordinate
# Each agent writes learnings here; other agents can read them
SHARED="$SCRIPT_DIR/../shared"

# =============================================================================
# TOOL DISCOVERY
# =============================================================================
# The agent needs access to the Shell Agentics primitives (agen, agen-log, etc).
# We look for them in two places:
#   1. In PATH (if user has installed them system-wide)
#   2. In the parent directory (for development/testing)
#
# This allows the agent to work both in production and development setups.

find_tool() {
  local tool="$1"

  # First, check if the tool is in PATH
  if command -v "$tool" &>/dev/null; then
    echo "$tool"
    return
  fi

  # Second, check the local development path (../agen-log/agen-log, etc.)
  if [[ -x "$SCRIPT_DIR/../../$tool/$tool" ]]; then
    echo "$SCRIPT_DIR/../../$tool/$tool"
    return
  fi

  # Tool not found — this is a fatal error
  echo "Error: $tool not found in PATH or local dev paths" >&2
  exit 1
}

# Locate each required primitive
AGEN=$(find_tool agen)
AGEN_LOG=$(find_tool agen-log)
AGEN_MEMORY=$(find_tool agen-memory)

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================
# Tell the primitives where to store their data.
# These are set relative to the shellclaw directory structure.

export AGEN_LOG_DIR="$SCRIPT_DIR/../logs"
export AGEN_MEMORY_DIR="$SCRIPT_DIR/../memory"

# =============================================================================
# INPUT VALIDATION
# =============================================================================
# An agent without a request is meaningless. Fail early with clear message.

if [[ -z "$MSG" ]]; then
  echo "Usage: data.sh <message>" >&2
  exit 1
fi

# =============================================================================
# STEP 1: LOG THE INCOMING REQUEST
# =============================================================================
# Every action starts with a log entry. This is the foundation of observability.
# Later, we can use agen-audit to see exactly what requests this agent received.

echo "$MSG" | "$AGEN_LOG" --agent "$AGENT" --event request

# =============================================================================
# STEP 2: LOAD PERSISTENT MEMORY
# =============================================================================
# Read everything this agent has remembered from previous sessions.
# If the agent has no memory yet (first run), we get a default message.
#
# The 2>/dev/null suppresses "directory not found" errors on first run.
# The || provides a fallback if agen-memory outputs nothing.

MEMORY=$("$AGEN_MEMORY" read "$AGENT" 2>/dev/null || echo "No prior context.")

# =============================================================================
# STEP 3 & 4: COMPOSE CONTEXT AND CALL THE LLM
# =============================================================================
# We build a structured document containing:
#   - Previous context (what the agent remembers)
#   - Current request (what the user is asking)
#
# This document is piped to agen, which prepends the soul file (system prompt)
# and sends the whole thing to the LLM.
#
# The structure (## headers, clear sections) helps the LLM understand what's
# persistent context vs. what's the current task.

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
# Record what the agent produced. This completes the audit trail:
# request -> response, both timestamped and logged.

echo "$RESULT" | "$AGEN_LOG" --agent "$AGENT" --event complete

# =============================================================================
# STEP 6: EXTRACT AND STORE LEARNINGS
# =============================================================================
# Ask the LLM to extract any key facts or learnings from its response.
# This is meta-cognition: the agent reflects on what it just did.
#
# If nothing new was learned, the LLM should output "none" (or nothing).
# We check for this to avoid storing empty/meaningless memories.
#
# The 2>/dev/null suppresses errors if agen fails (e.g., API issues).
# The || true ensures the script continues even if extraction fails.

LEARNINGS=$(echo "$RESULT" | "$AGEN" --system "Extract key facts learned as brief bullet points. If nothing new was learned, output only: none" 2>/dev/null || true)

# Only save learnings if there's something meaningful
if [[ -n "$LEARNINGS" ]] && [[ "$LEARNINGS" != "none" ]]; then

  # Save to this agent's personal memory (append to general notes)
  echo "$LEARNINGS" | "$AGEN_MEMORY" write "$AGENT"

  # =============================================================================
  # STEP 7: SHARE LEARNINGS TO CROSS-AGENT FILESYSTEM
  # =============================================================================
  # This is how agents coordinate: by writing to a shared location.
  # Lore (the synthesizer) will read from all agents' learnings directories
  # when generating briefings.
  #
  # Each day gets its own file. Learnings accumulate throughout the day.

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
# Finally, return the LLM's response to the caller.
# This goes to stdout and can be piped to other commands or captured.

echo "$RESULT"
