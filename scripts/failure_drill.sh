#!/usr/bin/env bash
#
# failure_drill.sh — run every documented failure drill in one command.
#
# The long-running reference architecture fixes seven failure drills
# (specs/operations-reference-architecture.md, "Failure drills"). Each
# documented failure is proved by a focused, acceptance-driven test, and the
# long-running reference application (jido-e07-t29) runs the whole linear
# path end to end against one deployment.
#
# This script is the single entry point the proof package ships
# (jido-e07-t31):
#
#   scripts/failure_drill.sh
#
# It runs every documented failure, prints a per-drill result, and exits
# non-zero if any documented failure does not pass.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v mix >/dev/null 2>&1; then
  echo "error: 'mix' is not on PATH — run from an Elixir project shell." >&2
  exit 2
fi

# Each documented failure drill, in spec order:
#   "<spec number>:<spec name>:<test path>"
# Order and wording mirror specs/operations-reference-architecture.md,
# "Failure drills (each must have an expected observation)".
DRILLS=(
  "1:Tool error + retry decision:test/agent_jido/demos/tool_error_retry_test.exs"
  "2:AgentServer crash:test/agent_jido/demos/agent_server_crash_test.exs"
  "3:Application restart:test/agent_jido/demos/persistence_storage_agent_test.exs"
  "4:Deployment restart:test/agent_jido/demos/deployment_restart_test.exs"
  "5:Duplicate Signal delivery:test/agent_jido/demos/idempotent_credit_agent_test.exs"
  "6:Provider timeout + fallback:test/agent_jido/demos/provider_timeout_fallback_test.exs"
  "7:Poison work / dead-letter:test/agent_jido/demos/poison_work_dead_letter_test.exs"
)

# The reference application runs the documented failures together against one
# deployment (the "Main target: Reference app" for this proof package).
REFERENCE_APP="test/agent_jido/demos/long_running_reference_test.exs"

passed=0
failed=0
failed_drills=()
log="$(mktemp -t failure_drill.XXXXXX)"
trap 'rm -f "$log"' EXIT

run_drill() {
  local label="$1"
  local path="$2"

  if [[ ! -f "$path" ]]; then
    printf '  x  %-30s  MISSING  %s\n' "$label" "$path"
    failed=$((failed + 1))
    failed_drills+=("${label} (missing ${path})")
    return
  fi

  if mix test "$path" >"$log" 2>&1; then
    printf '  v  %-30s  %s\n' "$label" "$path"
    passed=$((passed + 1))
  else
    printf '  x  %-30s  %s\n' "$label" "$path"
    failed=$((failed + 1))
    failed_drills+=("$label")
    echo "     --- output ---" >&2
    sed 's/^/     /' "$log" >&2
  fi
}

echo "Failure drills (jido-e07-t31)"
echo "Documented in specs/operations-reference-architecture.md"
echo

echo "Documented failures:"
for entry in "${DRILLS[@]}"; do
  rest="${entry#*:}"     # "<spec name>:<test path>"
  label="${rest%%:*}"    # "<spec name>"
  path="${rest##*:}"     # "<test path>"
  run_drill "$label" "$path"
done

echo
echo "Reference application (runs the documented failures together):"
run_drill "Long-running reference app" "$REFERENCE_APP"

echo
echo "summary: ${passed} passed, ${failed} failed"

if (( failed > 0 )); then
  echo
  echo "FAILED:"
  for name in "${failed_drills[@]}"; do
    printf '  - %s\n' "$name"
  done
  exit 1
fi

echo "All documented failures pass."
