#!/bin/bash
# shellclaw/cron/morning-briefing.sh
#
# Automated morning briefing generation.
# Run via cron: 0 6 * * * /path/to/shellclaw/cron/morning-briefing.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

export AGEN_LOG_DIR="$PWD/logs"
export AGEN_MEMORY_DIR="$PWD/memory"

# Each agent does their morning check
./agents/data.sh "Run morning backup verification. Report status." > /dev/null
./agents/aurora.sh "Run morning system health check. Report any concerns." > /dev/null

# Lore synthesizes
BRIEFING=$(./agents/lore.sh "Generate morning briefing from today's team learnings.")

# Save the briefing
mkdir -p ./shared/briefings
echo "$BRIEFING" > "./shared/briefings/$(date -I).md"

echo "Morning briefing generated: ./shared/briefings/$(date -I).md"
