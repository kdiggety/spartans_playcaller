#!/usr/bin/env bash
set -euo pipefail

# setup.sh — Interactive/flag-driven project setup for claude-subagents-kit
# Generates PROJECT_CONTEXT.md and context/local.md from user input.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Defaults ---
DEFAULT_NAME="$(git config user.name 2>/dev/null || echo "")"
DEFAULT_GIT_USER="$(git config user.email 2>/dev/null | sed 's/@.*//' || echo "")"
DEFAULT_WORKSPACE="$REPO_ROOT"
DEFAULT_RUNNER_TYPE="github-hosted"
DEFAULT_RUNNER_PATH="$HOME/actions-runner"
DEFAULT_RISK="internal tooling"
DEFAULT_COMPLIANCE="none"
DEFAULT_REGIONS="single region"

# --- Variables (populated by flags or prompts) ---
OPT_NAME=""
OPT_GIT_USER=""
OPT_WORKSPACE=""
OPT_RUNNER_TYPE=""
OPT_RUNNER_PATH=""
OPT_DOMAIN=""
OPT_STACK=""
OPT_RISK=""
OPT_USERS=""
OPT_COMPLIANCE=""
OPT_REGIONS=""
OPT_NON_GOALS=""
OPT_SUCCESS_SIGNALS=""
OPT_FORCE=false

# --- Flag parsing ---
usage() {
    cat <<'USAGE'
Usage: setup.sh [OPTIONS]

Interactive project setup. Flags fill in values; missing ones are prompted.

Options:
  --name NAME             Developer name (default: git config user.name)
  --git-user USER         Git username (default: email prefix)
  --workspace PATH        Workspace path (default: repo root)
  --runner-type TYPE      CI runner: github-hosted | self-hosted (default: github-hosted)
  --runner-path PATH      Actions runner directory (required if self-hosted)
  --domain DOMAIN         Project domain (required)
  --stack STACK           Tech stack summary (required)
  --risk RISK             Risk profile (default: internal tooling)
  --users USERS           Primary users (required)
  --compliance VALUE      Compliance requirements (default: none)
  --regions VALUE         Deployment regions (default: single region)
  --non-goals VALUE       Non-goals (optional)
  --success-signals VALUE Success signals (optional)
  --force                 Overwrite existing files without prompting
  --help                  Show this help message

Examples:
  ./scripts/setup.sh
  ./scripts/setup.sh --name "Ken" --domain "chat app" --stack "Node/Express" --users "devs"
  ./scripts/setup.sh --force --runner-type self-hosted --runner-path "$HOME/actions-runner"
USAGE
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) OPT_NAME="$2"; shift 2 ;;
        --git-user) OPT_GIT_USER="$2"; shift 2 ;;
        --workspace) OPT_WORKSPACE="$2"; shift 2 ;;
        --runner-type) OPT_RUNNER_TYPE="$2"; shift 2 ;;
        --runner-path) OPT_RUNNER_PATH="$2"; shift 2 ;;
        --domain) OPT_DOMAIN="$2"; shift 2 ;;
        --stack) OPT_STACK="$2"; shift 2 ;;
        --risk) OPT_RISK="$2"; shift 2 ;;
        --users) OPT_USERS="$2"; shift 2 ;;
        --compliance) OPT_COMPLIANCE="$2"; shift 2 ;;
        --regions) OPT_REGIONS="$2"; shift 2 ;;
        --non-goals) OPT_NON_GOALS="$2"; shift 2 ;;
        --success-signals) OPT_SUCCESS_SIGNALS="$2"; shift 2 ;;
        --force) OPT_FORCE=true; shift ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; echo "Run with --help for usage."; exit 1 ;;
    esac
done

# --- Helpers ---

# Detect if stdin is a terminal (interactive)
if [[ -t 0 ]]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default="$3"
    local current_val="${!var_name}"

    if [[ -n "$current_val" ]]; then
        return
    fi

    # Non-interactive: accept default silently
    if [[ "$INTERACTIVE" == false ]]; then
        eval "$var_name=\"$default\""
        return
    fi

    if [[ -n "$default" ]]; then
        printf "%s [%s]: " "$prompt_text" "$default" >&2
    else
        printf "%s: " "$prompt_text" >&2
    fi

    local input
    read -r input
    if [[ -z "$input" ]]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

prompt_required() {
    local var_name="$1"
    local prompt_text="$2"
    local default="${3:-}"
    local current_val="${!var_name}"

    if [[ -n "$current_val" ]]; then
        return
    fi

    # Non-interactive: accept default or fail
    if [[ "$INTERACTIVE" == false ]]; then
        if [[ -n "$default" ]]; then
            eval "$var_name=\"$default\""
        else
            echo "ERROR: Required value '$prompt_text' not provided via flags." >&2
            exit 1
        fi
        return
    fi

    while true; do
        prompt "$var_name" "$prompt_text" "$default"
        if [[ -n "${!var_name}" ]]; then
            break
        fi
        echo "  This value is required." >&2
    done
}

check_overwrite() {
    local filepath="$1"
    if [[ -f "$filepath" ]]; then
        if [[ "$OPT_FORCE" == true ]]; then
            return 0
        fi
        printf "File '%s' already exists. Overwrite? [y/N]: " "$filepath" >&2
        local answer
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) return 0 ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

# --- Collect values ---
echo "=== claude-subagents-kit: Project Setup ===" >&2
echo "" >&2

# Apply defaults to optional flags if provided empty
[[ -z "$OPT_NAME" ]] || DEFAULT_NAME="$OPT_NAME"
[[ -z "$OPT_GIT_USER" ]] || DEFAULT_GIT_USER="$OPT_GIT_USER"
[[ -z "$OPT_WORKSPACE" ]] || DEFAULT_WORKSPACE="$OPT_WORKSPACE"
[[ -z "$OPT_RUNNER_TYPE" ]] || DEFAULT_RUNNER_TYPE="$OPT_RUNNER_TYPE"
[[ -z "$OPT_RISK" ]] || DEFAULT_RISK="$OPT_RISK"
[[ -z "$OPT_COMPLIANCE" ]] || DEFAULT_COMPLIANCE="$OPT_COMPLIANCE"
[[ -z "$OPT_REGIONS" ]] || DEFAULT_REGIONS="$OPT_REGIONS"

# Prompt for values (skipped if already set via flags)
prompt "OPT_NAME" "Developer name" "$DEFAULT_NAME"
prompt "OPT_GIT_USER" "Git username" "$DEFAULT_GIT_USER"
prompt "OPT_WORKSPACE" "Workspace path" "$DEFAULT_WORKSPACE"
prompt "OPT_RUNNER_TYPE" "CI runner type (github-hosted | self-hosted)" "$DEFAULT_RUNNER_TYPE"

if [[ "$OPT_RUNNER_TYPE" == "self-hosted" ]]; then
    prompt "OPT_RUNNER_PATH" "Actions runner path" "$DEFAULT_RUNNER_PATH"
    # Validate runner path
    if [[ -n "$OPT_RUNNER_PATH" && ! -d "$OPT_RUNNER_PATH" ]]; then
        echo "" >&2
        echo "  WARNING: Runner path '$OPT_RUNNER_PATH' does not exist." >&2
        if [[ "$INTERACTIVE" == true ]]; then
            printf "  Continue anyway? [y/N]: " >&2
            read -r RUNNER_ANSWER
            case "$RUNNER_ANSWER" in
                [yY]|[yY][eE][sS]) ;;
                *) echo "Aborting." >&2; exit 1 ;;
            esac
        else
            echo "  Proceeding (non-interactive mode)." >&2
        fi
    fi
fi

prompt_required "OPT_DOMAIN" "Project domain (e.g., 'chat application', 'e-commerce platform')" ""
prompt_required "OPT_STACK" "Tech stack summary (e.g., 'Node/Express/React/Postgres')" ""
prompt "OPT_RISK" "Risk profile" "$DEFAULT_RISK"
prompt_required "OPT_USERS" "Primary users (e.g., 'developers', 'end consumers')" ""
prompt "OPT_COMPLIANCE" "Compliance requirements" "$DEFAULT_COMPLIANCE"
prompt "OPT_REGIONS" "Deployment regions" "$DEFAULT_REGIONS"
prompt "OPT_NON_GOALS" "Non-goals (optional, press Enter to skip)" ""
prompt "OPT_SUCCESS_SIGNALS" "Success signals (optional, press Enter to skip)" ""

# --- Finalize values ---
FINAL_NAME="${OPT_NAME:-$DEFAULT_NAME}"
FINAL_GIT_USER="${OPT_GIT_USER:-$DEFAULT_GIT_USER}"
FINAL_WORKSPACE="${OPT_WORKSPACE:-$DEFAULT_WORKSPACE}"
FINAL_RUNNER_TYPE="${OPT_RUNNER_TYPE:-$DEFAULT_RUNNER_TYPE}"
FINAL_RUNNER_PATH="${OPT_RUNNER_PATH:-$DEFAULT_RUNNER_PATH}"
FINAL_DOMAIN="$OPT_DOMAIN"
FINAL_STACK="$OPT_STACK"
FINAL_RISK="${OPT_RISK:-$DEFAULT_RISK}"
FINAL_USERS="$OPT_USERS"
FINAL_COMPLIANCE="${OPT_COMPLIANCE:-$DEFAULT_COMPLIANCE}"
FINAL_REGIONS="${OPT_REGIONS:-$DEFAULT_REGIONS}"
FINAL_NON_GOALS="${OPT_NON_GOALS:-none specified}"
FINAL_SUCCESS_SIGNALS="${OPT_SUCCESS_SIGNALS:-none specified}"

# --- Write PROJECT_CONTEXT.md ---
PC_FILE="$REPO_ROOT/PROJECT_CONTEXT.md"
WRITE_PC=true

if ! check_overwrite "$PC_FILE"; then
    WRITE_PC=false
    echo "  Skipping PROJECT_CONTEXT.md" >&2
fi

if [[ "$WRITE_PC" == true ]]; then
    # Build ci_runner block
    if [[ "$FINAL_RUNNER_TYPE" == "self-hosted" ]]; then
        RUNNER_YAML=$(cat <<EOF
ci_runner:
  type: "self-hosted"
  path: "$FINAL_RUNNER_PATH"
EOF
)
    else
        RUNNER_YAML=$(cat <<EOF
ci_runner:
  type: "github-hosted"
EOF
)
    fi

    cat > "$PC_FILE" <<EOF
# Project context

\`\`\`yaml
domain: "$FINAL_DOMAIN"
primary_users: "$FINAL_USERS"
risk_profile: "$FINAL_RISK"
constraints:
  compliance: "$FINAL_COMPLIANCE"
  regions_deployment: "$FINAL_REGIONS"
tech_stack_summary: "$FINAL_STACK"
non_goals: "$FINAL_NON_GOALS"
success_signals: "$FINAL_SUCCESS_SIGNALS"

$RUNNER_YAML
\`\`\`

## Field notes

- **\`ci_runner.type\`**: If \`github-hosted\`, devops-platform skips runner lifecycle management. If \`self-hosted\`, devops-platform checks for and starts the runner process before CI confirmation.
- **\`ci_runner.path\`**: The directory containing \`run.sh\` (the runner start script). Only required when \`type: self-hosted\`.
EOF
    echo "  Created: $PC_FILE" >&2
fi

# --- Write context/local.md ---
LOCAL_FILE="$REPO_ROOT/context/local.md"
WRITE_LOCAL=true

if ! check_overwrite "$LOCAL_FILE"; then
    WRITE_LOCAL=false
    echo "  Skipping context/local.md" >&2
fi

if [[ "$WRITE_LOCAL" == true ]]; then
    mkdir -p "$REPO_ROOT/context"

    if [[ "$FINAL_RUNNER_TYPE" == "self-hosted" ]]; then
        cat > "$LOCAL_FILE" <<EOF
# Local Developer Configuration

\`\`\`yaml
developer:
  name: "$FINAL_NAME"
  git_user: "$FINAL_GIT_USER"

paths:
  workspace: "$FINAL_WORKSPACE"
  actions_runner: "$FINAL_RUNNER_PATH"

runner:
  start_command: "nohup $FINAL_RUNNER_PATH/run.sh > /tmp/actions-runner.log 2>&1 &"
  check_command: "ps aux | grep Runner.Listener"
\`\`\`

## Usage

The orchestrator references \`context/local.md\` for environment-specific values
(runner paths, workspace locations) instead of hardcoding them in tracked files.
EOF
    else
        cat > "$LOCAL_FILE" <<EOF
# Local Developer Configuration

\`\`\`yaml
developer:
  name: "$FINAL_NAME"
  git_user: "$FINAL_GIT_USER"

paths:
  workspace: "$FINAL_WORKSPACE"
\`\`\`

## Usage

The orchestrator references \`context/local.md\` for environment-specific values
(runner paths, workspace locations) instead of hardcoding them in tracked files.
EOF
    fi
    echo "  Created: $LOCAL_FILE" >&2
fi

# --- Summary ---
echo "" >&2
echo "=== Setup Complete ===" >&2
echo "" >&2
if [[ "$WRITE_PC" == true ]]; then
    echo "  PROJECT_CONTEXT.md  — tracked by git (commit this file)" >&2
fi
if [[ "$WRITE_LOCAL" == true ]]; then
    echo "  context/local.md    — gitignored (stays local to your machine)" >&2
fi
echo "" >&2
echo "Next steps:" >&2
echo "  1. Review the generated files" >&2
echo "  2. Commit PROJECT_CONTEXT.md to your repo" >&2
echo "  3. Start using the kit: the orchestrator reads both files automatically" >&2
