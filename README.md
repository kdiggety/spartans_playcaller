# Claude Code subagents kit

Portable **`CLAUDE.md`** plus **`.claude/agents/`** discipline subagents (YAML frontmatter + prompts) for [Claude Code](https://code.claude.com/docs) — usable as **its own git repo** for proof-of-concept, or **copied into** an application repository.

## Contents

| Path | Purpose |
|------|---------|
| [`CLAUDE.md`](./CLAUDE.md) | Orchestration: role map, defaults, governance, conflict rules |
| [`.claude/agents/*.md`](./.claude/agents/) | Subagent definitions (`name`, `description`, `tools`, body) |
| [`.claude/agents/README.md`](./.claude/agents/README.md) | Agent index, **orchestration checklist** (Agent tool, SDK `setting_sources`) |
| [`.claude/rules/personas/README.md`](./.claude/rules/personas/README.md) | Stub: personas live as agents, not bulk rules |
| [`examples/smoke-prompts.md`](./examples/smoke-prompts.md) | prompts to **prove** subagent delegation |
| [`catalog/`](./catalog/) | Optional specialized agents (copy into `.claude/agents/` when needed) |
| [`PROJECT_CONTEXT.example.md`](./PROJECT_CONTEXT.example.md) | Optional template for `PROJECT_CONTEXT.md` |

## Prerequisites

1) [Claude Code](https://code.claude.com/docs) installed and authenticated (`claude` CLI works).

2) Subagent delegation requires the **`Agent`** tool to be available to the session ([docs](https://code.claude.com/docs/en/agent-sdk/subagents)). If delegation never happens, allow **`Agent`** and/or **name the subagent** in your prompt (see **`.claude/agents/README.md`** → **Orchestration**).

3) **Cursor / other IDEs** may not implement the same discovery path; **`@`-mention** agent files as a fallback ([`CLAUDE.md`](./CLAUDE.md)).

## Setup path A — Prove subagents in this repo (recommended)

Use this folder as the **git repository root** while you validate behavior.

1) From this directory:

```bash
cd /path/to/claude-subagents-kit
git init
git add CLAUDE.md .claude examples PROJECT_CONTEXT.example.md README.md .gitignore
git commit -m "Add Claude Code subagents kit"
```

2) Start Claude Code **from this same directory** so project `CLAUDE.md` and `.claude/` resolve correctly:

```bash
claude
```

3) Optional: copy `PROJECT_CONTEXT.example.md` → `PROJECT_CONTEXT.md` and customize (ignored by `.gitignore` if you name it `PROJECT_CONTEXT.md` — remove from `.gitignore` if you want it committed).

4) Run prompts from [`examples/smoke-prompts.md`](./examples/smoke-prompts.md) and confirm delegation or document what blocked it.

## Setup path B — Adopt inside another project

1) Copy **`CLAUDE.md`** and the **`.claude/`** directory into the **target project repository root** (merge carefully if that project already has `.claude/`).

2) Resolve duplicates (e.g. merge `settings.json`, combine agent folders).

3) Commit and open Claude Code from the **target** repo root. If Claude Code was already running during the copy, **exit the session and re-launch** — custom agents in `.claude/agents/` are discovered at session start and will not be available until restart.

4) Run smoke prompts adapted to that codebase.

## Maintaining this kit (workstation_setup users)

This directory is a **snapshot package** under `workstation_setup/claude-subagents-kit/`. Authoritative edits may continue under [`../CLAUDE.md`](../CLAUDE.md) and [`../.claude/`](../.claude/) in the parent workspace; **re-copy** into `claude-subagents-kit/` before publishing a new kit revision:

```bash
# From workstation_setup
cp CLAUDE.md claude-subagents-kit/CLAUDE.md
rm -rf claude-subagents-kit/.claude
cp -R .claude claude-subagents-kit/.claude
```

## References

- [Custom subagents](https://code.claude.com/docs/en/sub-agents)
- [Agent SDK subagents](https://code.claude.com/docs/en/agent-sdk/subagents)
- Orchestration checklist: [`.claude/agents/README.md`](./.claude/agents/README.md)
