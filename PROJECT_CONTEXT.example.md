# Project context (example)

Copy to **`PROJECT_CONTEXT.md`** in the same directory as `CLAUDE.md` and fill in. Optionally `@`-mention `PROJECT_CONTEXT.md` in Claude Code when starting substantive work.

```yaml
domain: "<your product domain>"
primary_users: "<who relies on this system>"
risk_profile: "<e.g. regulated | consumer scale | internal tooling>"
constraints:
  compliance: "<none | HIPAA | PCI | …>"
  regions_deployment: "<e.g. single region>"
tech_stack_summary: "<one line>"
non_goals: "<what we are not optimizing for>"
success_signals: "<SLOs, gates, cost ceilings>"

ci_runner:
  type: "<self-hosted | github-hosted>"
  path: "<absolute path to actions-runner directory, only if self-hosted>"
```

For subagent proof-of-concept you can leave placeholders or use minimal values.

## Field notes

- **`ci_runner.type`**: If `github-hosted`, devops-platform skips runner lifecycle management. If `self-hosted`, devops-platform checks for and starts the runner process before CI confirmation.
- **`ci_runner.path`**: The directory containing `run.sh` (the runner start script). Only required when `type: self-hosted`.
