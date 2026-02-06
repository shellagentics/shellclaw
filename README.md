# Shellclaw

## What Is This?

Shellclaw is a reference implementation showing how the `agen-*` primitives compose into a working multi-agent system. Agents coordinate by writing files to a shared folder — no framework, no daemon, just bash scripts calling composable tools.

Everything is inspectable. Every action is logged. Every memory is a file you can read. Every decision is traceable. You can `grep` through what your agents did, `diff` their memories between runs, and `cat` their execution traces.

## Shell Agentics

Part of the [Shell Agentics](https://github.com/shellagentics/shell-agentics) toolkit - small programs that compose via pipes and text streams to build larger agentic structures using Unix primitives. No frameworks. No magic. Total observability.

---

## Quick Start

```bash
git clone https://github.com/shellagentics/shellclaw
cd shellclaw

# Run the demo (uses stub backend — no LLM calls, no API keys)
./demo.sh

# Run with a real LLM
AGEN_BACKEND=claude-code ./demo.sh
```

The demo runs agent-1, then agent-2 (which reads agent-1's shared learnings), and shows you the audit trail, memory state, and shared learnings.

## The Agents

Shellclaw ships two generic agents that demonstrate the architecture. The agents are deliberately minimal — the point is the *pattern*, not the persona.

### agent-1 — The Basic Pattern

**Soul:** `souls/agent-1.md`
**Script:** `agents/agent-1.sh`

The 8-step agent pattern: log, remember, think, log, learn, share, output.

```bash
./agents/agent-1.sh "Describe what you would check to verify system health."
```

### agent-2 — Cross-Agent Coordination

**Soul:** `souls/agent-2.md`
**Script:** `agents/agent-2.sh`

Same 8-step pattern, plus reads other agents' shared learnings before composing context. This is how filesystem coordination works: agent-2 reads files that agent-1 wrote.

```bash
./agents/agent-2.sh "Summarize what other agents have reported today."
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

Agent-2 adds a step between LOAD and COMPOSE: **GATHER team learnings** from the shared filesystem. This is a specialization — only agents that need cross-agent context do this.

No magic. Just bash calling bash calling an LLM.

## Stub Backend

The `stub` backend makes the entire system runnable without LLM calls:

```bash
# Default — demo.sh uses stub automatically
./demo.sh

# Explicit
AGEN_BACKEND=stub ./agents/agent-1.sh "test request"
```

The stub returns `"LLM return N"` with an incrementing counter. This lets you explore the architecture, verify the audit trail, and test scripts without API costs.

## Directory Structure

```
shellclaw/
├── agents/              # Agent scripts (orchestration logic)
│   ├── agent-1.sh       # Basic 8-step pattern
│   └── agent-2.sh       # 8-step + cross-agent coordination
├── souls/               # Agent personalities (system prompts)
│   ├── agent-1.md
│   └── agent-2.md
├── shared/              # Cross-agent coordination
│   ├── learnings/       # Each agent writes here
│   │   ├── agent-1/
│   │   └── agent-2/
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

**shared/learnings/** — Agents write what they learn here. Other agents can read it. This is how agent-2 knows what agent-1 discovered.

**souls/** — The personality files. These are the system prompts that define how each agent behaves. They're deliberately minimal to show that soul files are a *parameter*, not an identity.

## Observability

The entire point of Shellclaw is that everything is inspectable.

### See What Happened

```bash
# What did all agents do today?
agen-audit --today

# Raw logs
cat logs/all.jsonl | jq .
```

### Inspect Agent Memory

```bash
# What does agent-1 remember?
cat memory/agent-1/*.md

# List memory keys
agen-memory list agent-1

# Diff memory between runs
git diff memory/
```

### Review Shared Learnings

```bash
# What did agents learn today?
cat shared/learnings/*/$(date -I).md
```

## Scheduled Coordination

The `cron/morning-briefing.sh` script shows how agents coordinate on a schedule:

```bash
# Add to crontab: 0 6 * * * /path/to/shellclaw/cron/morning-briefing.sh

# What it does:
# 1. agent-1 runs a morning check
# 2. agent-2 synthesizes learnings into a briefing
# 3. Briefing is saved to shared/briefings/
```

No daemon. No message queue. Just cron calling scripts that write files.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `AGEN_LOG_DIR` | Where logs are written | `./logs` |
| `AGEN_MEMORY_DIR` | Where memories are stored | `./memory` |
| `AGEN_BACKEND` | LLM backend (claude-code, llm, api, stub) | `auto` |

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

**Never eval LLM output.** Agent scripts should parse agen's output as data, not execute it as code. If the script needs the LLM to choose an action, use a constrained vocabulary — the output must match one of N known strings.

**Treat soul files as immutable at runtime.** If an attacker can modify a soul file, they've modified the agent's identity. Mount `souls/` read-only in production, or checksum before use.

**Run agents with minimal privileges.** Each agent should be a separate Unix user with write access only to its own directories. This contains the blast radius of a compromised agent.

**Validate shared filesystem inputs.** Content in `shared/learnings/` crosses a trust boundary. A compromised agent can write content designed to manipulate peers. Consider signing or checksumming inter-agent messages.

## What's NOT Here

- **Web UI.** The interface is the terminal.
- **Database.** The filesystem is the database.
- **Plugin system.** Scripts are executables. `chmod +x` is the plugin system.
- **Daemon.** Use cron, systemd, or launchd.
- **Framework.** No base classes, no middleware. Scripts call primitives.

## Contributing

This is a reference implementation. If you're interested in the thesis, read the [Shell Agentics manifesto](https://github.com/shellagentics/shellagentics). If you want to build real systems, take these ideas and make them yours.

## License

MIT

## Author

Part of the Shell Agentics project — https://github.com/shellagentics
