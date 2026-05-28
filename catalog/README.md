# Agent Catalog

Optional, specialized agents that are **not** included in `.claude/agents/` by default. These cover domains that many projects won't need — copy them into `.claude/agents/` when your project requires them.

## Why a catalog?

Claude Code discovers agents from `.claude/agents/` at session start. Every file there becomes a routing option for the orchestrator. Keeping specialized agents in a catalog avoids noise in projects that don't need them, while making them discoverable and easy to activate.

## Available agents

| File | Domain | Activate when your project… |
|------|--------|-----------------------------|
| [mobile-engineer.md](./agents/mobile-engineer.md) | Mobile development (cross-platform + native) | …builds iOS/Android apps or has a mobile client |

## How to adopt a catalog agent

1. Copy the agent file into your project's `.claude/agents/` directory:

   ```bash
   cp catalog/agents/mobile-engineer.md .claude/agents/
   ```

2. Add the agent to the subagent map in `CLAUDE.md` (follow the existing table format).

3. If Claude Code is already running, **restart the session** — agents are discovered at launch.

## How to contribute a new catalog agent

1. Create the agent file in `catalog/agents/` using the same YAML frontmatter + body format as `.claude/agents/` files.

2. Add an entry to the table above.

3. Keep agents **domain-agnostic** — project-specific constraints belong in `PROJECT_CONTEXT.md`, not the agent file.

## When should an agent be in the catalog vs `.claude/agents/`?

| `.claude/agents/` (always active) | `catalog/agents/` (opt-in) |
|------------------------------------|----------------------------|
| Universally useful across most software projects | Domain-specific or platform-specific |
| Software engineer, SDET, DevOps, Security, etc. | Mobile, game dev, embedded, ML training, etc. |
| Needed for the orchestration templates to function | Extends the kit for specialized workflows |
