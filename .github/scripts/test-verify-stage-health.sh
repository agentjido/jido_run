#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir "$fixture_dir/bin"

cat > "$fixture_dir/bin/flyctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'machine list')
    if [[ "$SCENARIO" = missing ]]; then
      echo '[]'
    else
      echo '[{"id":"test-machine","config":{"metadata":{"fly_process_group":"app"}}}]'
    fi
    ;;
  'machine start')
    echo start >> "$TEST_CALLS"
    case "$SCENARIO" in
      transient)
        if [[ ! -f "$TEST_STATE" ]]; then
          touch "$TEST_STATE"
          echo 'failed_precondition: machine getting replaced, refusing to start' >&2
          exit 1
        fi
        ;;
      permanent)
        echo 'permission denied' >&2
        exit 1
        ;;
      replacing)
        echo 'failed_precondition: machine getting replaced, refusing to start' >&2
        exit 1
        ;;
    esac
    echo 'Machine started'
    ;;
  'checks list')
    if [[ "$SCENARIO" = no-checks ]]; then
      echo '{}'
    else
      echo '{"test-machine":[{"status":"passing"}]}'
    fi
    ;;
  *) exit 99 ;;
esac
MOCK
cat > "$fixture_dir/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$fixture_dir/bin/flyctl" "$fixture_dir/bin/sleep"

export PATH="$fixture_dir/bin:$PATH"
export TEST_STATE="$fixture_dir/state"
export TEST_CALLS="$fixture_dir/calls"
export STAGE_HEALTH_TIMEOUT_SECONDS=5

for scenario in healthy transient permanent missing replacing no-checks; do
  rm -f "$TEST_STATE" "$TEST_CALLS"
  export STAGE_HEALTH_TIMEOUT_SECONDS=5
  if [[ "$scenario" = replacing || "$scenario" = no-checks ]]; then
    export STAGE_HEALTH_TIMEOUT_SECONDS=1
  fi
  result=0
  SCENARIO="$scenario" bash "$script_dir/verify-stage-health.sh" > "$fixture_dir/output" 2>&1 || result=$?
  case "$scenario" in
    healthy|transient)
      [[ "$result" -eq 0 ]] || { cat "$fixture_dir/output"; exit 1; }
      ;;
    *) [[ "$result" -ne 0 ]] || { echo "Unexpected pass: $scenario"; exit 1; } ;;
  esac
  if [[ "$scenario" = transient ]]; then
    [[ "$(wc -l < "$TEST_CALLS" | tr -d ' ')" = 2 ]]
  elif [[ "$scenario" = permanent ]]; then
    [[ "$(wc -l < "$TEST_CALLS" | tr -d ' ')" = 1 ]]
  elif [[ "$scenario" = missing ]]; then
    [[ ! -e "$TEST_CALLS" ]]
  fi
  echo "PASS $scenario"
done
