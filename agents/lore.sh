#!/bin/bash
# =============================================================================
# agents/lore.sh — Lore: orchestrator and synthesizer
# =============================================================================
#
# PURPOSE:
#   Lore is the orchestrator and synthesizer. Unlike Data and Aurora, who are
#   specialists in their domains, Lore's job is to see the big picture. It
#   reads learnings from ALL other agents and synthesizes them into briefings.
#
# PERSONALITY (defined in souls/lore.md):
#   - Executive summary first
#   - Organized, hierarchical structure
#   - Credits sources when synthesizing
#   - Maintains the big picture of system state
#
# SPECIAL ABILITY:
#   Lore has access to the shared learnings from all agents. Before processing
#   a request, it gathers today's learnings from every agent's learnings
#   directory and includes them in its context. This is how multi-agent
#   coordination happens: agents share knowledge via the filesystem, and
#   Lore synthesizes it.
#
# HOW IT WORKS:
#   1. Log the incoming request (observability)
#   2. Load persistent memory from previous sessions
#   3. GATHER TEAM LEARNINGS (Lore's special step)
#   4. Compose context (memory + team learnings + current request)
#   5. Call the LLM with the soul file as system prompt
#   6. Log the response (observability)
#   7. Extract learnings and save to memory
#   8. Share learnings to the cross-agent filesystem
#   9. Output the result
#
# USAGE:
#   ./lore.sh "Generate morning briefing from team learnings"
#   ./lore.sh "Summarize what all agents discovered today"
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

MSG="${1:-}"
AGENT="lore"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUL="$SCRIPT_DIR/../souls/lore.md"
SHARED="$SCRIPT_DIR/../shared"

# =============================================================================
# TOOL DISCOVERY
# =============================================================================

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
  echo "Usage: lore.sh <message>" >&2
  exit 1
fi

# =============================================================================
# STEP 1: LOG THE INCOMING REQUEST
# =============================================================================

echo "$MSG" | "$AGEN_LOG" --agent "$AGENT" --event request

# =============================================================================
# STEP 2: LOAD PERSISTENT MEMORY
# =============================================================================

MEMORY=$("$AGEN_MEMORY" read "$AGENT" 2>/dev/null || echo "No prior context.")

# =============================================================================
# STEP 3: GATHER TEAM LEARNINGS (Lore's special ability)
# =============================================================================
# This is what makes Lore the synthesizer. We scan all agent learnings
# directories and collect today's learnings from each one.
#
# The directory structure is:
#   shared/learnings/data/2024-01-15.md
#   shared/learnings/aurora/2024-01-15.md
#   shared/learnings/lore/2024-01-15.md
#
# We read today's file from each agent that has one.

TEAM_LEARNINGS=""

# Loop through each agent's learnings directory
for agent_dir in "$SHARED"/learnings/*/; do
  # Skip if the glob didn't match anything (no directories)
  [[ -d "$agent_dir" ]] || continue

  # Extract the agent name from the directory path
  agent_name=$(basename "$agent_dir")

  # Check if there's a file for today
  today_file="$agent_dir/$(date -I).md"
  if [[ -f "$today_file" ]]; then
    # Add this agent's learnings with a header
    TEAM_LEARNINGS+="## $agent_name"$'\n'
    TEAM_LEARNINGS+=$(cat "$today_file")
    TEAM_LEARNINGS+=$'\n\n'
  fi
done

# Provide a default if no learnings were found
if [[ -z "$TEAM_LEARNINGS" ]]; then
  TEAM_LEARNINGS="No team learnings recorded today."
fi

# =============================================================================
# STEP 4: COMPOSE CONTEXT AND CALL THE LLM
# =============================================================================
# Lore's context is richer than other agents: it includes team learnings.
# This allows Lore to synthesize across the whole team's knowledge.

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

# =============================================================================
# STEP 5: LOG THE RESPONSE
# =============================================================================

echo "$RESULT" | "$AGEN_LOG" --agent "$AGENT" --event complete

# =============================================================================
# STEP 6: EXTRACT AND STORE LEARNINGS
# =============================================================================
# Lore might learn meta-patterns: relationships between agents' findings,
# recurring themes, or insights from synthesis.

LEARNINGS=$(echo "$RESULT" | "$AGEN" --system "Extract key facts learned as brief bullet points. If nothing new was learned, output only: none" 2>/dev/null || true)

if [[ -n "$LEARNINGS" ]] && [[ "$LEARNINGS" != "none" ]]; then
  echo "$LEARNINGS" | "$AGEN_MEMORY" write "$AGENT"

  # =============================================================================
  # STEP 7: SHARE LEARNINGS TO CROSS-AGENT FILESYSTEM
  # =============================================================================
  # Lore's learnings go to the shared filesystem too. This creates a feedback
  # loop: future Lore runs will see past synthesis insights.

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
