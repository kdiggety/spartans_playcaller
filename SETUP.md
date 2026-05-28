# Project Setup Guide

This document is an AI-readable onboarding guide. Any AI assistant (Claude Code, Cursor, Copilot, Codex) can follow it to walk a user through first-time setup of this kit repo.

## Goal

Generate two configuration files that personalize this kit for a specific project and developer:

1. **`PROJECT_CONTEXT.md`** (repo root) — project-level context: domain, stack, risk profile, CI runner config.
2. **`context/local.md`** (gitignored) — developer-specific: name, paths, runner commands.

Templates exist at `PROJECT_CONTEXT.example.md` and `context/local.example.md` for reference.

## State Machine

### Step 1: Detect Current State

Check which files already exist:

- Does `PROJECT_CONTEXT.md` exist in the repo root?
- Does `context/local.md` exist?

If both exist, ask the user: "Both configuration files already exist. Would you like to overwrite them?" If the user declines, stop. If only one exists, proceed to generate the missing one (and ask about overwriting the existing one).

### Step 2: Collect Values

Gather the following values from the user. Use the listed defaults when the user accepts them or does not provide a value.

| Value | Default | Target File |
|-------|---------|-------------|
| Developer name | Output of `git config user.name` | `context/local.md` |
| Git username | Prefix of `git config user.email` before the `@` | `context/local.md` |
| Workspace path | Current working directory (`$PWD`) | `context/local.md` |
| CI runner type | `github-hosted` | `PROJECT_CONTEXT.md` |
| Runner path | `$HOME/actions-runner` (only ask if runner type is `self-hosted`) | Both files |
| Domain | Required, no default — ask the user | `PROJECT_CONTEXT.md` |
| Tech stack summary | Required, no default — ask the user | `PROJECT_CONTEXT.md` |
| Risk profile | `internal tooling` | `PROJECT_CONTEXT.md` |
| Primary users | Required, no default — ask the user | `PROJECT_CONTEXT.md` |
| Compliance | `none` | `PROJECT_CONTEXT.md` |
| Deployment regions | `single region` | `PROJECT_CONTEXT.md` |
| Non-goals | Optional, leave blank if user skips | `PROJECT_CONTEXT.md` |
| Success signals | Optional, leave blank if user skips | `PROJECT_CONTEXT.md` |

Presentation: Show each value with its default in brackets (e.g., "Risk profile [internal tooling]:") and let the user press Enter to accept the default or type a custom value.

### Step 3: Validate Inputs

- If CI runner type is `self-hosted`, verify that the runner path directory exists on disk. If it does not exist, warn the user and ask them to confirm or provide a different path.
- Domain, tech stack summary, and primary users must not be empty.

### Step 4: Write `PROJECT_CONTEXT.md`

Write to the repo root. Use this structure:

```markdown
# Project context

```yaml
domain: "<domain>"
primary_users: "<primary users>"
risk_profile: "<risk profile>"
constraints:
  compliance: "<compliance>"
  regions_deployment: "<deployment regions>"
tech_stack_summary: "<tech stack summary>"
non_goals: "<non-goals or 'none specified'>"
success_signals: "<success signals or 'none specified'>"

ci_runner:
  type: "<runner type>"
  path: "<runner path, only if self-hosted>"
```

## Field notes

- **`ci_runner.type`**: If `github-hosted`, devops-platform skips runner lifecycle management. If `self-hosted`, devops-platform checks for and starts the runner process before CI confirmation.
- **`ci_runner.path`**: The directory containing `run.sh` (the runner start script). Only required when `type: self-hosted`.
```

If runner type is `github-hosted`, omit the `path` field entirely from the YAML block.

### Step 5: Write `context/local.md`

Write to `context/local.md`. Use this structure:

```markdown
# Local Developer Configuration

```yaml
developer:
  name: "<developer name>"
  git_user: "<git username>"

paths:
  workspace: "<workspace path>"
  actions_runner: "<runner path, only if self-hosted>"

runner:
  start_command: "nohup <runner path>/run.sh > /tmp/actions-runner.log 2>&1 &"
  check_command: "ps aux | grep Runner.Listener"
```

## Usage

The orchestrator references `context/local.md` for environment-specific values
(runner paths, workspace locations) instead of hardcoding them in tracked files.
```

If runner type is `github-hosted`, omit the `paths.actions_runner` field and the entire `runner:` block.

### Step 5.5: Configure Permissions

Create (or overwrite) `.claude/settings.json` in the target project with the following contents:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Bash(*)"
    ],
    "deny": [
      "Bash(rm -rf *)"
    ]
  }
}
```

This grants the subagents broad tool access while preventing destructive `rm -rf` commands. The file is committed to the repo so all collaborators share the same permission baseline.

### Step 5.6: Restart Claude Code session

If Claude Code was already running when the kit was copied in, the user **must** exit the session (`/exit` or close the terminal) and re-launch `claude` from the project root. Custom agents in `.claude/agents/` are discovered at session start — they will not be available as `subagent_type` values until the next launch.

If this is a fresh setup (Claude Code was not running), this step is a no-op.

### Step 6: Print Summary

Tell the user which files were created and remind them:
- `PROJECT_CONTEXT.md` is tracked by git (commit it).
- `.claude/settings.json` is tracked by git (commit it).
- `context/local.md` is gitignored (it stays local).
- If Claude Code was already running, **restart the session** for agent discovery.

## Alternative: Script

For terminal-native setup without an AI assistant, run:

```bash
./scripts/setup.sh
```

The script supports interactive prompts, flag-based input, or a mix of both. Run `./scripts/setup.sh --help` for flag documentation.
