#!/usr/bin/env bash
set -euo pipefail

stage_app="agentjido-stage"
stage_timeout="${STAGE_HEALTH_TIMEOUT_SECONDS:-300}"
stage_machine="$(flyctl machine list --app "$stage_app" --json | jq -r '[.[] | select(.config.metadata.fly_process_group == "app")] | first | .id // empty')"

if [[ -z "$stage_machine" ]]; then
  echo "No stage application machine exists." >&2
  exit 1
fi

flyctl machine start "$stage_machine" --app "$stage_app"
stage_deadline=$((SECONDS + stage_timeout))

while (( SECONDS < stage_deadline )); do
  stage_checks="$(flyctl checks list --app "$stage_app" --json)"
  if jq -e --arg machine "$stage_machine" '(.[$machine] // []) | length > 0 and all(.[]; .status == "passing")' <<< "$stage_checks" >/dev/null; then
    echo "Stage application started and all service checks pass."
    exit 0
  fi
  sleep 10
done

echo "Stage application did not pass its service checks." >&2
flyctl checks list --app "$stage_app"
exit 1
