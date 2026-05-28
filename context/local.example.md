# Local Developer Configuration (Template)

Copy this file to `context/local.md` and fill in your values.
`context/local.md` is gitignored and will not be committed.

```yaml
developer:
  name: "Your Name"
  git_user: "your.username"

paths:
  workspace: "/path/to/your/workspace"
  actions_runner: "/path/to/your/actions-runner"
  # The self-hosted GitHub Actions runner directory.
  # Used by the orchestrator to start/check the runner process.
  # Example: "$HOME/actions-runner"

runner:
  # Command to start the self-hosted runner (if not already running):
  start_command: "nohup /path/to/your/actions-runner/run.sh > /tmp/actions-runner.log 2>&1 &"
  # Command to check if the runner is active:
  check_command: "ps aux | grep Runner.Listener"
```

## Usage

The orchestrator references `context/local.md` for environment-specific values
(runner paths, workspace locations) instead of hardcoding them in tracked files.
