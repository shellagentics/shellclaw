#!/bin/bash
# shellclaw/cron/morning-briefing.sh — Scheduled multi-agent briefing
#
# Runs agent-1 then agent-2. Agent-2 reads agent-1's shared learnings
# and produces a briefing saved to shared/briefings/.
#
# Scheduling:
#   0 6 * * * /path/to/shellclaw/cron/morning-briefing.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

export AGEN_LOG_DIR="$PWD/logs"
export AGEN_MEMORY_DIR="$PWD/memory"

# Agent-1 gathers information; output discarded, side effects matter
./agents/agent-1.sh "Run a morning status check. Report anything notable." > /dev/null

# Agent-2 synthesizes from shared learnings into a briefing
BRIEFING=$(./agents/agent-2.sh "Generate a morning briefing from today's team learnings.")

mkdir -p ./shared/briefings
echo "$BRIEFING" > "./shared/briefings/$(date -I).md"

echo "Morning briefing generated: ./shared/briefings/$(date -I).md"
