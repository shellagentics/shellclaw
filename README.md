# Shellclaw

## What Is This?

Shellclaw is a reference implementation showing how the `agen-*` primitives compose into a working multi-agent system. A team of AI agents coordinate by writing files to a shared folder — no framework, no daemon, just bash scripts calling composable tools. Most AI agent systems are black boxes. You ask them to do something, magic happens, you get a result. Shellclaw is the opposite. Every action is logged. Every memory is a file you can read. Every decision is traceable. You can `grep` through what your agents did, `diff` their memories between runs, and `cat` their execution traces at 3am when something breaks. This is a POC reference implementation demonstrating that you CAN build observable, auditable AI agent systems from Unix primitives. This is an experiment and I welcome input and pull requests.

## Shell Agentics

Part of the [Shell Agentics](https://github.com/shellagentics/shell-agentics) toolkit - small programs that compose via pipes and text streams to build larger agentic structures using Unix primitives. No frameworks. No magic. Total observability.

---

## Quick Start

```bash
# Clone and enter
git clone https://github.com/shellagentics/shellclaw
cd shellclaw

# Ensure primitives are available (or install them)
# See: github.com/shellagentics/{agen,agen-log,agen-memory,agen-audit}

# Run the demo
./demo.sh
```

The demo will:
1. Ask the "data" agent about backup verification
2. Ask the "aurora" agent about system health
3. Ask the "lore" agent to synthesize team learnings
4. Show you the complete audit trail
5. Show you the agent memory state

## The Agents

Shellclaw comes with three agents, each defined by a **soul file** (personality/instructions) and an **agent script** (orchestration logic).

### Data — The Backup Specialist

**Soul:** `souls/data.md`
**Script:** `agents/data.sh`

Data handles backup verification, checksum validation, and system monitoring. It's precise, factual, and always states exactly what commands it would run.

```bash
./agents/data.sh "Verify backup integrity for today"
```

### Aurora — The Health Monitor

**Soul:** `souls/aurora.md`
**Script:** `agents/aurora.sh`

Aurora monitors system health, tracks metrics, and escalates issues. It uses severity levels (INFO, WARNING, CRITICAL) and always includes actionable next steps.

```bash
./agents/aurora.sh "Check disk usage and report any concerns"
```

### Lore — The Synthesizer

**Soul:** `souls/lore.md`
**Script:** `agents/lore.sh`

Lore orchestrates and synthesizes. It reads learnings from all other agents and generates briefings. It maintains the big picture.

```bash
./agents/lore.sh "Generate morning briefing from team learnings"
```

## How Agents Work

Each agent script follows an 8-step pattern:

```
1. LOG      the incoming request (agen-log)
2. LOAD     persistent memory (agen-memory read)
3. COMPOSE  the full context as stdin
4. CALL     the LLM (agen --system-file)
5. LOG      the response (agen-log)
6. EXTRACT  learnings and save to memory
7. SHARE    learnings to shared filesystem
8. OUTPUT   the result
```

Lore adds a 9th step: **GATHER team learnings** (inserted between LOAD and COMPOSE). This is a specialization, not a universal step — specialist agents like Data and Aurora work from their own memory; only synthesizers need cross-agent context.

No magic. Just bash calling bash calling an LLM.

## Directory Structure

```
shellclaw/
├── agents/              # Agent scripts (the orchestration logic)
│   ├── data.sh
│   ├── aurora.sh
│   └── lore.sh
├── souls/               # Agent personalities (system prompts)
│   ├── data.md
│   ├── aurora.md
│   └── lore.md
├── skills/              # Reusable capabilities (optional)
├── shared/              # Cross-agent coordination
│   ├── learnings/       # Each agent writes here
│   │   ├── data/
│   │   ├── aurora/
│   │   └── lore/
│   └── briefings/       # Generated summaries
├── logs/                # Execution logs (JSONL)
├── memory/              # Agent memories (Markdown)
├── cron/                # Scheduled tasks
│   └── morning-briefing.sh
└── demo.sh              # Interactive demonstration
```

### Key Directories

**logs/** — Every agent action is logged here as JSONL. One file per agent, plus `all.jsonl` for the combined view.

**memory/** — Each agent gets a folder. Memories are Markdown files. Read them with `cat`, search with `grep`, version with `git`.

**shared/learnings/** — Agents write what they learn here. Other agents can read it. This is how Lore knows what Data and Aurora discovered.

**souls/** — The personality files. These are the system prompts that define how each agent behaves.

## Observability

The entire point of Shellclaw is that everything is inspectable.

### See What Happened

```bash
# What did all agents do today?
agen-audit --today

# What commands were run?
agen-audit --today --event execution

# Did anything mention "error"?
agen-audit --today --grep "error"

# Raw logs
cat logs/all.jsonl | jq .
```

### Inspect Agent Memory

```bash
# What does Data remember?
cat memory/data/*.md

# List Aurora's memory keys
agen-memory list aurora

# Diff memory between runs
git diff memory/
```

### Review Shared Learnings

```bash
# What did agents learn today?
cat shared/learnings/*/$(date -I).md

# Yesterday vs today
diff shared/learnings/data/2024-01-14.md shared/learnings/data/2024-01-15.md
```

## Scheduled Coordination

The `cron/morning-briefing.sh` script shows how agents can coordinate on a schedule:

```bash
# Add to crontab: 0 6 * * * /path/to/shellclaw/cron/morning-briefing.sh

# What it does:
# 1. Data runs morning backup verification
# 2. Aurora runs morning health check
# 3. Lore synthesizes a briefing from their learnings
# 4. Briefing is saved to shared/briefings/
```

No daemon. No message queue. Just cron calling scripts that write files.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `AGEN_LOG_DIR` | Where logs are written | `./logs` |
| `AGEN_MEMORY_DIR` | Where memories are stored | `./memory` |
| `AGEN_BACKEND` | LLM backend (claude-code, llm, api) | `auto` |
| `AGEN_MODEL` | LLM model to use | `claude-sonnet-4-20250514` |

## Required Tools

Shellclaw requires the Shell Agentics primitives:

- **agen** — LLM inference primitive ([github.com/shellagentics/agen](https://github.com/shellagentics/agen))
- **agen-log** — Structured logger ([github.com/shellagentics/agen-log](https://github.com/shellagentics/agen-log))
- **agen-memory** — Filesystem-backed memory ([github.com/shellagentics/agen-memory](https://github.com/shellagentics/agen-memory))
- **agen-audit** — Log query tool ([github.com/shellagentics/agen-audit](https://github.com/shellagentics/agen-audit))

Plus standard Unix utilities: `bash`, `jq`, `date`, `cat`, `grep`.

## Comparison with OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is a 168K-star personal AI assistant with 13+ messaging platform integrations. Shellclaw achieves similar multi-agent coordination through different means:

| Aspect | OpenClaw | Shellclaw |
|--------|----------|-----------|
| Architecture | WebSocket gateway, RPC | Files and processes |
| State | Session objects via WebSocket | Directories and files |
| Agent communication | `sessions_send` API | Shared filesystem |
| Scheduling | Gateway-native cron | Just cron |
| Observability | Logging infrastructure | JSONL + grep |
| Daemon required | Yes (Gateway) | No |

Shellclaw is not better or worse — it's a different approach. OpenClaw solves real-time multi-platform chat. Shellclaw proves that Unix primitives are sufficient for agent coordination.

## The Shell Agentics Thesis

> The terminal is a 50-year-old prototype of an agentic interface.

Unix gave us:
- **Processes** for isolation (each agent invocation is a process)
- **Files** for state (memory is a directory)
- **Streams** for communication (stdin/stdout/pipes)
- **Exit codes** for verification (0 or not-0)

AI agents don't need new infrastructure. They need to compose with the infrastructure we have. Shellclaw is a proof of concept demonstrating this thesis.

## Security Considerations

Shell Agentics treats the LLM as an **oracle, not a driver**. The LLM answers questions; it doesn't make decisions about tool use. Decisions live in auditable shell scripts. This is a deliberate security architecture.

Research on inter-agent trust exploitation (Lupinacci et al., 2025) found that 82.4% of LLMs will execute malicious commands received from peer agents — commands they'd refuse from humans. In multi-agent systems where agents communicate through tool calls, this is catastrophic. In Shell Agentics, agents communicate through **text in files**, not tool calls through trust boundaries.

### Guidelines

**Never eval LLM output.** Skills should parse agen's output as data, not execute it as code. If the skill needs the LLM to choose an action, use a constrained vocabulary — the output must match one of N known strings.

**Treat soul files as immutable at runtime.** If an attacker can modify a soul file, they've modified the agent's identity. Mount `souls/` read-only in production, or checksum before use.

**Run agents with minimal privileges.** Each agent should be a separate Unix user with write access only to its own directories. This contains the blast radius of a compromised agent.

**Validate shared filesystem inputs.** Content in `shared/learnings/` crosses a trust boundary. A compromised agent can write content designed to manipulate peers. Consider signing or checksumming inter-agent messages.

## What's NOT Here

- **Web UI.** The interface is the terminal.
- **Database.** The filesystem is the database.
- **Plugin system.** Skills are executables. `chmod +x` is the plugin system.
- **Daemon.** Use cron, systemd, or launchd.
- **Framework.** No base classes, no middleware. Scripts call primitives.

## Contributing

This is a reference implementation. If you're interested in the thesis, read the [Shell Agentics manifesto](https://github.com/shellagentics/shellagentics). If you want to build real systems, take these ideas and make them yours.

## License

MIT

## Author

Part of the Shell Agentics project — https://github.com/shellagentics
