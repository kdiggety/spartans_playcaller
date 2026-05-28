# Session Start: Orient Before Acting

At the start of every new conversation — before responding to the user's message — the orchestrator must orient itself:

1. **Read `PROJECT_CONTEXT.md`** (if it exists) — understand project setup, tech stack, runner config
2. **Check `git status` and `git branch`** — detect in-progress work, current branch, uncommitted changes
3. **Check `git log --oneline -5`** — understand what was last done
4. **Scan `docs/backlog/`** (if it exists) — identify current priorities and what's completed vs pending
5. **Scan `docs/superpowers/plans/`** (if it exists) — check for any in-progress implementation plans
6. **Check for running infrastructure** — `kind get clusters 2>/dev/null`, `docker ps --format '{{.Names}}' 2>/dev/null | head -5`, or equivalent for the project's stack

Then proceed with whatever the user requested. If the user says "continue", "pick up next task", "resume", or similar — use the orientation to determine what's next and proceed without asking.

This orientation is silent unless something surprising is found (e.g., uncommitted changes on a branch, a half-finished plan). In that case, state what you found in one sentence before proceeding.
