# Subagents (discipline personas)

These Markdown files define **Claude Code subagents** in `.claude/agents/`: each has YAML frontmatter (`name`, `description` with `<example>` triggers, `model`, `color`, `tools`) and a body that acts as the subagent system prompt.

Official references: [Custom subagents](https://code.claude.com/docs/en/sub-agents), [Agent SDK subagents](https://code.claude.com/docs/en/agent-sdk/subagents).

## Agent files

| File | Role |
|------|------|
| [infra-engineer.md](./infra-engineer.md) | Infrastructure, platforms, IaC, reliability, security baselines |
| [architecture-system-design.md](./architecture-system-design.md) | Boundaries, trade-offs, evolution, failure modes |
| [devops-platform.md](./devops-platform.md) | CI/CD, releases, observability, runbooks |
| [software-engineer.md](./software-engineer.md) | Implementation, maintainability, bounded changes |
| [sdet.md](./sdet.md) | Test strategy, automation, flake discipline |
| [technical-researcher.md](./technical-researcher.md) | Evidence-based comparison and synthesis |
| [technical-writer.md](./technical-writer.md) | Docs, ADRs, runbooks, clarity |
| [ux-designer.md](./ux-designer.md) | Flows, IA, usability, accessibility-aware UX guidance |
| [product-owner.md](./product-owner.md) | Value, backlog ordering, acceptance criteria, stakeholder trade-offs |
| [scrum-master.md](./scrum-master.md) | Facilitation, agile flow, ceremonies, impediments, retrospectives |
| [project-manager.md](./project-manager.md) | Milestones, dependencies, RAID/status, steering comms—not PO backlog or SM facilitation |
| [auditor.md](./auditor.md) | Oversight of agent outputs vs policies and role boundaries—not penetration testing |
| [security-engineer.md](./security-engineer.md) | Infra + app security, threat-informed review, hardening |
| [performance-engineer.md](./performance-engineer.md) | Profiling, capacity, latency/throughput optimization, benchmark rigor—not CI gate wiring alone (see **sdet**) |
| [data-architect.md](./data-architect.md) | Schema design, data modeling, migrations, indexing, database selection, data lifecycle—not DB platform provisioning (**infra-engineer**) or deep query profiling (**performance-engineer**) |
| [ai-engineer.md](./ai-engineer.md) | LLM/AI API integration, prompt engineering, model selection, RAG, token/cost management—not ML training or general app code |

**Implementation scope:** By default **`software-engineer`** covers **full-stack** work in unified repos; split dedicated FE/BE agents only when repos or team boundaries justify it—see root **`CLAUDE.md`** → **Full-stack vs front-end / back-end only**.

## How to dispatch (Claude Code)

Use the `Agent` tool with the **`subagent_type`** parameter set to the persona name. The value matches the file name without `.md` (e.g., `software-engineer`, `devops-platform`, `sdet`). **Never omit `subagent_type`** — omitting it spawns a generic agent without the persona’s system prompt, tools, or constraints.

The orchestrator (root `CLAUDE.md`) maps tasks to personas via the "Reach for it when" column. The dispatch rule is simple: match the task → set `subagent_type` → delegate.

## Alternative clients

- **Cursor / Copilot** — `@.claude/agents/<file>.md` to attach a persona as context. These clients may not support `subagent_type` natively.
- **Agent SDK** — Include `Agent` in `allowed_tools` and set `setting_sources: ["project"]` so `.claude/agents/` files load automatically.

## Tools field

Each agent lists **allowed tools** (Read, Write, Edit, Grep, Glob, Bash). Tight lists reduce risk; expand per agent as needed (e.g., MCP tools—add only when your Claude Code version documents them in agent `tools`).

## Packaged kit (optional layout)

These files are often kept in a **standalone repository** for Claude Code POC, then **copied** into an application repo. If your kit includes a root **`README.md`** with `git init` / ingest steps, follow that for first-time setup.

## Copying to another project

Copy **`CLAUDE.md`** (repo root) and the entire **`.claude/`** directory. Optional: **`PROJECT_CONTEXT.md`** (see `PROJECT_CONTEXT.example.md` in the kit). Do not resurrect bulk persona rules under `.claude/rules/personas/` except the stub README.
