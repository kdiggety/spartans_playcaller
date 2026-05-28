# Smoke prompts (subagent delegation POC)

Run these from **Claude Code** with this directory as the **project root** (so `CLAUDE.md` and `.claude/agents/` load).

Use verbatim or adapt slightly. If Claude does **not** delegate, name the agent explicitly (e.g. “Using the **security-engineer** subagent defined in `.claude/agents/`…”).

---

## 1) Explicit delegation (recommended first test)

```
Use the security-engineer subagent to review CLAUDE.md for anything that could confuse agents about scope boundaries. List only substantive findings.
```

## 2) Routing by task shape

```
Our CI YAML is under .github if present; otherwise scan for Jenkinsfile or similar. Use the devops-platform subagent to summarize how a release would flow and what is missing for rollback clarity.
```

## 3) Product vs delivery boundary

```
Draft three backlog bullets for improving this kit’s README setup steps (value-focused). Use the product-owner subagent; do not edit files unless I confirm.
```

## 4) Audit pass (after another agent acted)

```
After any substantive edit from Claude, use the auditor subagent to check the reply against root CLAUDE.md instruction priority and list any gaps.
```

## 5) Performance vs SDET boundary

```
Compare performance-engineer vs sdet responsibilities using only what’s in .claude/agents/*.md—no external docs. Use the technical-researcher subagent.
```

---

**Success criteria**

1) Claude invokes the **`Agent`** tool (or UI equivalent) and you see work attributed to the named subagent, **or**
2) You get a clear denial / capability gap—then verify **`Agent`** is allowed and you launched Claude Code from this repo root.

See root **`README.md`** for prerequisites and troubleshooting links in **`.claude/agents/README.md`** → **Orchestration**.
