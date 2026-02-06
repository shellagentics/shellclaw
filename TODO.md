# TODO: Update all references in `shellclaw`

Shellclaw is the reference multi-agent implementation. All of its scripts use the toolkit
tools that are being renamed. Every agent script, the demo, the cron job, and the README
need updating.

## Rename reference table

| Old | New |
|-----|-----|
| `agen` (tool) | `agent` |
| `agen-memory` | `amem` |
| `agen-log` | `alog` |
| `agen-audit` | `aaud` |
| `agen-skills` | `ascr` |
| "skills" (concept) | "scripts" |
| `AGEN_BACKEND` | `AGENT_BACKEND` |
| `AGEN_LOG_DIR` | `AGENT_LOG_DIR` |
| `AGEN_MEMORY_DIR` | `AGENT_MEMORY_DIR` |

---

## File-by-file instructions

### 1. Edit `README.md`

- Update all tool name references per the table above
- **Required tools section**: `agen, agen-log, agen-memory, agen-audit` → `agent, alog, amem, aaud`
- **Architecture/pattern description**: Update tool names in the 8-step pattern
- **GitHub URLs**: `shellagentics/agen` → `shellagentics/agent` etc.
- **Environment variables**: `AGEN_BACKEND` → `AGENT_BACKEND`, `AGEN_LOG_DIR` → `AGENT_LOG_DIR`, `AGEN_MEMORY_DIR` → `AGENT_MEMORY_DIR`
- **Observability section**: `agen-audit` → `aaud`, `agen-memory` → `amem`
- **Example commands**: Update all invocations
- References to "skills" → "scripts" if present
- **Comparison with OpenClaw**: Update tool names if referenced

### 2. Edit `agents/agent-1.sh`

- **Tool discovery**: Update PATH/command checks from `agen`, `agen-log`, `agen-memory` → `agent`, `alog`, `amem`
- **All invocations**:
  - `agen --system-file` → `agent --system-file`
  - `agen-log --agent` → `alog --agent`
  - `agen-memory read` → `amem read`
  - `agen-memory write` → `amem write`
  - `agen "extract key facts"` → `agent "extract key facts"` (the learning extraction call)
- **Comments**: Update tool names in comments explaining each step

### 3. Edit `agents/agent-2.sh`

Same changes as agent-1.sh, plus:
- **Cross-agent coordination section**: Tool invocations for reading shared learnings — update `agen-memory` → `amem` etc.
- **All invocations**:
  - `agen --system-file` → `agent --system-file`
  - `agen-log --agent` → `alog --agent`
  - `agen-memory read` → `amem read`
  - `agen-memory write` → `amem write`
  - `agen "extract"` → `agent "extract"`

### 4. Edit `demo.sh`

- **Tool discovery section**: Update tool names being searched for in PATH/sibling directories:
  - `agen-audit` → `aaud`
  - `agen-memory` → `amem`
  - `agen-log` → `alog` (if referenced)
  - Sibling directory names: `../agen-audit` → `../aaud`, `../agen-memory` → `../amem`
- **AGEN_BACKEND**: → `AGENT_BACKEND`
- **AGEN_LOG_DIR**: → `AGENT_LOG_DIR`
- **AGEN_MEMORY_DIR**: → `AGENT_MEMORY_DIR`
- **AGEN_STUB_FILE**: → `AGENT_STUB_FILE` (if present)
- **Audit trail display**: `agen-audit --today` → `aaud --today`
- **Memory display**: `agen-memory list` → `amem list`, `agen-memory read` → `amem read`
- **Echo/print statements**: Update any display text mentioning old tool names

### 5. Edit `cron/morning-briefing.sh`

- **AGEN_LOG_DIR**: → `AGENT_LOG_DIR`
- **AGEN_MEMORY_DIR**: → `AGENT_MEMORY_DIR`
- **AGEN_BACKEND**: → `AGENT_BACKEND` (if present)
- **Comments**: Update tool names

### 6. Edit `souls/agent-1.md` and `souls/agent-2.md`

- These are system prompt files. They probably don't reference tool names directly, but check. Update if they do.

---

## Verification

After all changes, run:

```bash
# Search for ANY remaining old references
grep -rn "agen-memory" --include="*.sh" --include="*.md" .
grep -rn "agen-log" --include="*.sh" --include="*.md" .
grep -rn "agen-audit" --include="*.sh" --include="*.md" .
grep -rn "agen-skills" --include="*.sh" --include="*.md" .
grep -rn "AGEN_" --include="*.sh" --include="*.md" .

# Check for standalone "agen" (not "agent")
grep -rn "agen[^t]" --include="*.sh" --include="*.md" .

# Verify all shell scripts are syntactically valid
find . -name "*.sh" -exec bash -n {} \;

# Run the demo (with stub backend)
AGENT_BACKEND=stub ./demo.sh
```

## Delete this file when done

Remove this TODO.md after completing all changes.
