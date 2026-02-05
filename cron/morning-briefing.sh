#!/bin/bash
# =============================================================================
# shellclaw/cron/morning-briefing.sh — Automated morning briefing generation
# =============================================================================
#
# PURPOSE:
#   This script demonstrates scheduled multi-agent coordination. It runs
#   each specialist agent to gather their morning assessments, then has
#   Lore synthesize everything into a briefing.
#
# HOW IT WORKS:
#   1. Data runs morning backup verification
#   2. Aurora runs morning health check
#   3. Lore synthesizes learnings into a briefing
#   4. Briefing is saved to shared/briefings/
#
# SCHEDULING:
#   Add to crontab to run automatically each morning:
#
#     0 6 * * * /path/to/shellclaw/cron/morning-briefing.sh
#
#   This runs at 6:00 AM daily. Adjust the time as needed.
#
# OUTPUT:
#   Creates a briefing file at shared/briefings/YYYY-MM-DD.md
#
# NOTE:
#   This is "orchestration via cron" — no daemon, no message queue, no
#   scheduler service. Just a shell script that cron runs on a schedule.
#   The coordination happens through the filesystem.
#
# =============================================================================

# Exit immediately on error, undefined variable, or pipe failure.
set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================
# Change to the shellclaw directory (parent of cron/).
# This ensures all relative paths work correctly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Configure environment for the primitives
export AGEN_LOG_DIR="$PWD/logs"
export AGEN_MEMORY_DIR="$PWD/memory"

# =============================================================================
# STEP 1: DATA'S MORNING CHECK
# =============================================================================
# Data verifies backups. Its learnings will be written to shared/learnings/data/
# for Lore to read later.
#
# The > /dev/null discards the direct output — we care about the side effects
# (logging, memory updates, shared learnings) not the response itself.

./agents/data.sh "Run morning backup verification. Report status." > /dev/null

# =============================================================================
# STEP 2: AURORA'S MORNING CHECK
# =============================================================================
# Aurora checks system health. Any concerns will be in shared/learnings/aurora/.

./agents/aurora.sh "Run morning system health check. Report any concerns." > /dev/null

# =============================================================================
# STEP 3: LORE SYNTHESIZES THE BRIEFING
# =============================================================================
# Lore reads from all agents' learnings directories and produces a synthesis.
# We capture this output — it IS the briefing.

BRIEFING=$(./agents/lore.sh "Generate morning briefing from today's team learnings.")

# =============================================================================
# STEP 4: SAVE THE BRIEFING
# =============================================================================
# Store the briefing in the shared/briefings/ directory with today's date.
# This creates an archive of daily briefings that can be reviewed later.

mkdir -p ./shared/briefings
echo "$BRIEFING" > "./shared/briefings/$(date -I).md"

# =============================================================================
# OUTPUT
# =============================================================================
# Print confirmation message. If running via cron, this goes to cron's mail
# or wherever cron output is redirected.

echo "Morning briefing generated: ./shared/briefings/$(date -I).md"
