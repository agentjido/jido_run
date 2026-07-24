#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/ralph_wiggum_loop.sh [options]

Runs one fresh Zclaude session for each ready Beadwork task. The shell loop
selects tasks, starts them, verifies the resulting commit, closes accepted
tasks, and then selects the next ready task.

Zclaude is required. The script passes an explicit GLM model so Claude Code
uses the Z.AI/ZLM configuration instead of an Anthropic model.

Options:
  --only ID                Run only one ready Beadwork task
  --max N                  Accept at most N tasks (default: unlimited)
  --id-regex REGEX         Select task IDs that match REGEX
                           (default: ^jido-e[0-9]+-t[0-9]+$)
  --model MODEL            Explicit Z.AI model (default: glm-5.2[1m])
  --runner PATH            Zclaude executable (default: zclaude)
  --verify-cmd CMD         Acceptance gate (default: test compile and format check)
  --max-fix-attempts N     Zclaude fix attempts after a failed gate (default: 2)
  --include-comment-blockers
                           Include tasks whose latest comment says they are
                           deferred, blocked, or waiting for a decision
  --push                   Push the current Git branch after each accepted task
  --remote NAME            Git remote used by --push (default: origin)
  --branch NAME            Git branch used by --push (default: current branch)
  --allow-main             Permit execution on main or master
  --dry-run                List eligible tasks without changing Beadwork or Git
  -h, --help               Show this help

Environment variables:
  ZCLAUDE_BIN              Default value for --runner
  ZCLAUDE_MODEL            Default value for --model
  VERIFY_CMD               Default value for --verify-cmd
  LOG_FILE                 Log file (default: tmp/ralph_wiggum_loop.log)
  RAW_LOG_FILE             Raw Zclaude JSONL trace
                           (default: tmp/ralph_wiggum_loop.raw.jsonl)
  LOCK_DIR                 Lock directory (default: tmp/ralph_wiggum_loop.lock)

Examples:
  scripts/ralph_wiggum_loop.sh --dry-run
  scripts/ralph_wiggum_loop.sh --only jido-e05-t10
  scripts/ralph_wiggum_loop.sh --max 5
  scripts/ralph_wiggum_loop.sh --max 3 --verify-cmd "mix test"
USAGE
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_value() {
  local option="$1"
  local count="$2"
  local value="${3:-}"

  if [ "$count" -lt 2 ] || [ -z "$value" ] || [[ "$value" == -* ]]; then
    fail "Option ${option} requires a value"
  fi
}

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "Required command is not available: ${command_name}"
  fi
}

assert_clean_tree() {
  local status
  status="$(git status --porcelain)"

  if [ -n "$status" ]; then
    fail "Working tree is not clean. Commit or stash changes before starting."
  fi
}

assert_safe_branch() {
  local branch="$1"

  if [ "$ALLOW_MAIN" -eq 0 ] && { [ "$branch" = "main" ] || [ "$branch" = "master" ]; }; then
    fail "Refusing to run on ${branch}. Use a feature branch or pass --allow-main."
  fi
}

task_json() {
  local task_id="$1"
  bw show "$task_id" --json
}

task_status() {
  local task_id="$1"
  task_json "$task_id" | jq -r '.status // ""'
}

task_has_comment_blocker() {
  local task_id="$1"

  task_json "$task_id" |
    jq -e '
      (.comments // [] | last | .text // "") as $comment
      | $comment
      | test(
          "(^|[[:space:]])(Deferred:|Blocked on|Reopen when|Needs product confirmation|Needs user decision)";
          "i"
        )
    ' >/dev/null
}

ready_task_rows() {
  bw ready --json |
    jq -r --arg id_regex "$ID_REGEX" '
      if type == "array" then
        .[]
        | select(.type == "task")
        | select(.status == "open")
        | select(.id | test($id_regex))
        | [.id, (.priority // 2 | tostring), .title]
        | @tsv
      else
        empty
      end
    '
}

task_is_ready() {
  local task_id="$1"

  ready_task_rows | awk -F '\t' -v task_id="$task_id" '$1 == task_id { found = 1 } END { exit !found }'
}

select_next_task() {
  local row
  local task_id

  while IFS= read -r row; do
    [ -z "$row" ] && continue
    task_id="${row%%	*}"

    if [ "$INCLUDE_COMMENT_BLOCKERS" -eq 0 ] && task_has_comment_blocker "$task_id"; then
      log "Skipping ${task_id}: latest Beadwork comment records a blocker or deferral" >&2
      continue
    fi

    printf '%s\n' "$row"
    return 0
  done < <(ready_task_rows)

  return 1
}

list_dry_run_tasks() {
  local count=0
  local row
  local task_id

  if [ -n "$ONLY_TASK" ]; then
    if ! task_is_ready "$ONLY_TASK"; then
      fail "Task is not ready: ${ONLY_TASK}"
    fi

    if [ "$INCLUDE_COMMENT_BLOCKERS" -eq 0 ] && task_has_comment_blocker "$ONLY_TASK"; then
      fail "Task has a blocker or deferral in its latest comment: ${ONLY_TASK}"
    fi

    task_json "$ONLY_TASK" | jq -r '[.id, ("P" + (.priority | tostring)), .title] | @tsv'
    return 0
  fi

  while IFS= read -r row; do
    [ -z "$row" ] && continue
    task_id="${row%%	*}"

    if [ "$INCLUDE_COMMENT_BLOCKERS" -eq 0 ] && task_has_comment_blocker "$task_id"; then
      continue
    fi

    printf '%s\n' "$row"
    count=$((count + 1))

    if [ "$MAX_TASKS" -gt 0 ] && [ "$count" -ge "$MAX_TASKS" ]; then
      break
    fi
  done < <(ready_task_rows)
}

build_worker_prompt() {
  local task_id="$1"
  local prompt_file="$2"
  local task_details
  local parent_id
  local parent_details="No parent issue."

  task_details="$(task_json "$task_id")"
  parent_id="$(printf '%s' "$task_details" | jq -r '.parent // ""')"

  if [ -n "$parent_id" ]; then
    parent_details="$(task_json "$parent_id")"
  fi

  {
    cat <<PROMPT
You are one worker in an externally supervised Ralph Wiggum loop.

Repository: ${REPO_ROOT}
Task: ${task_id}

The shell supervisor already ran \`bw start ${task_id}\`.
Work only on this task. Do not select another task.
Do not use \`/goal\`, Ralph Loop, or another long-running loop.

Required workflow:
1. Run \`bw prime\`.
2. Read the exact task and parent epic below.
3. Quote the exact acceptance condition before you edit.
4. Inspect the current implementation and relevant tests.
5. Make only the changes required by this task.
6. Add or update focused tests.
7. Run the focused tests and any directly affected checks.
8. Review the final diff against every part of the acceptance condition.
9. Create a Conventional Commit that includes \`${task_id}\` in its subject or body.
10. Leave the Git working tree clean.

The shell supervisor owns final acceptance. Do not:
- close, defer, reopen, or otherwise change the Beadwork task status;
- run \`bw sync\`;
- push Git branches;
- start another Beadwork task.

If the task cannot be completed, do not invent evidence. Explain the exact
blocker and leave the work in the safest recoverable state.

Task JSON:
\`\`\`json
${task_details}
\`\`\`

Parent epic JSON:
\`\`\`json
${parent_details}
\`\`\`

At the end, report:
- exact acceptance condition;
- files changed;
- test commands and results;
- commit hash;
- any remaining gap.
PROMPT
  } >"$prompt_file"
}

build_fix_prompt() {
  local task_id="$1"
  local gate_log="$2"
  local prompt_file="$3"

  {
    cat <<PROMPT
You are fixing verification failures for Beadwork task ${task_id}.

Work only on this task. Inspect the current commits and working tree. Fix the
root cause of the failed gate below. Run the focused tests and the gate. Create
a Conventional Commit that references ${task_id}. Leave the working tree clean.

Do not change Beadwork status. Do not run \`bw sync\`. Do not push.

Latest verification output:
\`\`\`text
PROMPT
    tail -n 300 "$gate_log"
    cat <<'PROMPT'
```
PROMPT
  } >"$prompt_file"
}

render_zclaude_stream() {
  jq --unbuffered -Rr '
    . as $raw
    | (try fromjson catch null) as $event
    | if $event == null then
        $raw
      elif $event.type == "system" and $event.subtype == "init" then
        "[session] id=\($event.session_id // "unknown") model=\($event.model // "unknown")"
      elif $event.type == "assistant" then
        $event.message.content[]?
        | if .type == "text" then
            .text
          elif .type == "tool_use" then
            (.input.command // .input.file_path // .input.pattern // .input // "") as $detail
            | "[tool] \(.name // "unknown"): \(($detail | tostring)[0:1200])"
          else
            empty
          end
      elif $event.type == "user" then
        $event.message.content[]?
        | select(.type == "tool_result")
        | "[tool result] \(((.content // "") | tostring)[0:1600])"
      elif $event.type == "result" then
        "[session result] status=\($event.subtype // "unknown") duration_ms=\($event.duration_ms // "unknown")"
      elif $event.type == "rate_limit_event" then
        "[rate limit] \($event | tostring)"
      else
        empty
      end
  '
}

run_zclaude() {
  local prompt_file="$1"
  local context="$2"
  local exit_codes

  log "Starting fresh Zclaude/GLM session for ${context}"
  log "Live worker turns and tool calls follow. Raw trace: ${RAW_LOG_FILE}"

  set +e
  "$ZCLAUDE_BIN" \
    --print \
    --permission-mode auto \
    --model "$ZCLAUDE_MODEL" \
    --output-format stream-json \
    --verbose \
    <"$prompt_file" 2>&1 |
    tee -a "$RAW_LOG_FILE" |
    render_zclaude_stream |
    tee -a "$LOG_FILE"
  exit_codes=("${PIPESTATUS[@]}")
  set -e

  return "${exit_codes[0]}"
}

commit_references_task() {
  local before_head="$1"
  local task_id="$2"

  git log --format='%H%n%B%n---END-COMMIT---' "${before_head}..HEAD" |
    grep -F "$task_id" >/dev/null
}

verify_worker_result() {
  local before_head="$1"
  local task_id="$2"
  local gate_log="$3"
  local current_status

  if [ "$(git rev-parse HEAD)" = "$before_head" ]; then
    log "No commit was created for ${task_id}"
    return 1
  fi

  if ! commit_references_task "$before_head" "$task_id"; then
    log "No new commit references ${task_id}"
    return 1
  fi

  if [ -n "$(git status --porcelain)" ]; then
    log "Working tree is not clean after ${task_id}"
    return 1
  fi

  current_status="$(task_status "$task_id")"
  if [ "$current_status" != "in_progress" ]; then
    log "Task status changed outside the supervisor: ${task_id} is ${current_status}"
    return 1
  fi

  log "Running acceptance gate for ${task_id}: ${VERIFY_CMD}"
  if ! bash -lc "$VERIFY_CMD" >"$gate_log" 2>&1; then
    cat "$gate_log" >>"$LOG_FILE"
    log "Acceptance gate failed for ${task_id}"
    return 1
  fi

  cat "$gate_log" >>"$LOG_FILE"
  return 0
}

restore_open_if_safe() {
  local task_id="$1"
  local before_head="$2"

  if [ -n "$(git status --porcelain)" ] || [ "$(git rev-parse HEAD)" != "$before_head" ]; then
    log "Leaving ${task_id} in progress because recoverable Git work exists"
    return 1
  fi

  bw comment "$task_id" "Ralph loop worker did not produce an acceptable commit. Task returned to open. See ${LOG_FILE}."
  bw update "$task_id" --status open
  bw sync
  return 0
}

accept_task() {
  local task_id="$1"
  local before_head="$2"
  local accepted_head
  local commits

  accepted_head="$(git rev-parse HEAD)"
  commits="$(git log --format='%h' "${before_head}..${accepted_head}" | paste -sd ',' -)"

  bw comment "$task_id" "Accepted by the Zclaude Ralph supervisor. Commits: ${commits}. Verification: ${VERIFY_CMD}."
  bw close "$task_id"
  bw sync

  if [ "$DO_PUSH" -eq 1 ]; then
    log "Pushing ${TARGET_BRANCH} to ${REMOTE_NAME}"
    git push "$REMOTE_NAME" "$TARGET_BRANCH"
  fi
}

process_task() {
  local task_id="$1"
  local task_title="$2"
  local before_head
  local prompt_file
  local gate_log
  local fix_prompt
  local attempt=0

  assert_clean_tree
  before_head="$(git rev-parse HEAD)"
  prompt_file="$(mktemp "${TMPDIR:-/tmp}/ralph-worker.XXXXXX")"
  gate_log="$(mktemp "${TMPDIR:-/tmp}/ralph-gate.XXXXXX")"

  log "Starting ${task_id}: ${task_title}"
  bw start "$task_id" >>"$LOG_FILE"
  build_worker_prompt "$task_id" "$prompt_file"

  if ! run_zclaude "$prompt_file" "$task_id"; then
    log "Zclaude returned a failure for ${task_id}"
  fi

  while ! verify_worker_result "$before_head" "$task_id" "$gate_log"; do
    if [ "$attempt" -ge "$MAX_FIX_ATTEMPTS" ]; then
      log "Task ${task_id} failed verification after ${attempt} fix attempt(s)"
      rm -f "$prompt_file" "$gate_log"

      if restore_open_if_safe "$task_id" "$before_head"; then
        return 1
      fi

      fail "Manual recovery is required for ${task_id}; Git work was preserved"
    fi

    attempt=$((attempt + 1))
    fix_prompt="$(mktemp "${TMPDIR:-/tmp}/ralph-fix.XXXXXX")"
    build_fix_prompt "$task_id" "$gate_log" "$fix_prompt"
    log "Running fix attempt ${attempt}/${MAX_FIX_ATTEMPTS} for ${task_id}"

    if ! run_zclaude "$fix_prompt" "${task_id} fix attempt ${attempt}"; then
      log "Zclaude fix attempt ${attempt} returned a failure"
    fi

    rm -f "$fix_prompt"
  done

  rm -f "$prompt_file" "$gate_log"
  accept_task "$task_id" "$before_head"
  log "Accepted ${task_id}"
}

ONLY_TASK=""
MAX_TASKS=0
ID_REGEX='^jido-e[0-9]+-t[0-9]+$'
ZCLAUDE_BIN="${ZCLAUDE_BIN:-zclaude}"
ZCLAUDE_MODEL="${ZCLAUDE_MODEL:-glm-5.2[1m]}"
# The repository currently has dependency warnings and existing test failures.
# Keep stricter task-specific gates available through --verify-cmd.
VERIFY_CMD="${VERIFY_CMD:-MIX_ENV=test mix compile && MIX_ENV=test mix format --check-formatted}"
MAX_FIX_ATTEMPTS=2
INCLUDE_COMMENT_BLOCKERS=0
DO_PUSH=0
REMOTE_NAME="origin"
TARGET_BRANCH=""
ALLOW_MAIN=0
DRY_RUN=0
LOG_FILE="${LOG_FILE:-tmp/ralph_wiggum_loop.log}"
RAW_LOG_FILE="${RAW_LOG_FILE:-tmp/ralph_wiggum_loop.raw.jsonl}"
LOCK_DIR="${LOCK_DIR:-tmp/ralph_wiggum_loop.lock}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      require_value "$1" "$#" "${2:-}"
      ONLY_TASK="$2"
      shift 2
      ;;
    --max)
      require_value "$1" "$#" "${2:-}"
      MAX_TASKS="$2"
      shift 2
      ;;
    --id-regex)
      require_value "$1" "$#" "${2:-}"
      ID_REGEX="$2"
      shift 2
      ;;
    --model)
      require_value "$1" "$#" "${2:-}"
      ZCLAUDE_MODEL="$2"
      shift 2
      ;;
    --runner)
      require_value "$1" "$#" "${2:-}"
      ZCLAUDE_BIN="$2"
      shift 2
      ;;
    --verify-cmd)
      require_value "$1" "$#" "${2:-}"
      VERIFY_CMD="$2"
      shift 2
      ;;
    --max-fix-attempts)
      require_value "$1" "$#" "${2:-}"
      MAX_FIX_ATTEMPTS="$2"
      shift 2
      ;;
    --include-comment-blockers)
      INCLUDE_COMMENT_BLOCKERS=1
      shift
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --remote)
      require_value "$1" "$#" "${2:-}"
      REMOTE_NAME="$2"
      shift 2
      ;;
    --branch)
      require_value "$1" "$#" "${2:-}"
      TARGET_BRANCH="$2"
      shift 2
      ;;
    --allow-main)
      ALLOW_MAIN=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if ! is_non_negative_integer "$MAX_TASKS"; then
  fail "--max must be a non-negative integer"
fi

if ! is_non_negative_integer "$MAX_FIX_ATTEMPTS"; then
  fail "--max-fix-attempts must be a non-negative integer"
fi

if [[ "$ZCLAUDE_MODEL" != glm-* ]]; then
  fail "--model must name a GLM model so the worker stays on Z.AI/ZLM"
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "Not inside a Git repository"
cd "$REPO_ROOT"
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$RAW_LOG_FILE")" "$(dirname "$LOCK_DIR")"

require_command git
require_command jq
require_command bw

if [ "$DRY_RUN" -eq 1 ]; then
  log "Dry run: eligible Beadwork tasks"
  list_dry_run_tasks
  exit 0
fi

require_command "$ZCLAUDE_BIN"
require_command mix

if [ "$(basename "$ZCLAUDE_BIN")" != "zclaude" ]; then
  fail "--runner must resolve to the zclaude wrapper"
fi

TARGET_BRANCH="${TARGET_BRANCH:-$(git branch --show-current)}"
[ -n "$TARGET_BRANCH" ] || fail "Could not determine the current Git branch"
assert_safe_branch "$TARGET_BRANCH"
assert_clean_tree

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  fail "Another Ralph loop may be active: ${LOCK_DIR}"
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

log "Repository: ${REPO_ROOT}"
log "Branch: ${TARGET_BRANCH}"
log "Runner: ${ZCLAUDE_BIN}"
log "Forced Z.AI model: ${ZCLAUDE_MODEL}"
log "Verification: ${VERIFY_CMD}"
log "Raw Zclaude trace: ${RAW_LOG_FILE}"

processed=0

while true; do
  if [ "$MAX_TASKS" -gt 0 ] && [ "$processed" -ge "$MAX_TASKS" ]; then
    log "Reached --max ${MAX_TASKS}"
    break
  fi

  if [ -n "$ONLY_TASK" ]; then
    if [ "$processed" -gt 0 ]; then
      break
    fi

    if ! task_is_ready "$ONLY_TASK"; then
      fail "Task is not ready: ${ONLY_TASK}"
    fi

    if [ "$INCLUDE_COMMENT_BLOCKERS" -eq 0 ] && task_has_comment_blocker "$ONLY_TASK"; then
      fail "Task has a blocker or deferral in its latest comment: ${ONLY_TASK}"
    fi

    selected_row="$(ready_task_rows | awk -F '\t' -v task_id="$ONLY_TASK" '$1 == task_id { print; exit }')"
  else
    if ! selected_row="$(select_next_task)"; then
      log "No eligible ready Beadwork tasks remain"
      break
    fi
  fi

  selected_id="$(printf '%s' "$selected_row" | cut -f1)"
  selected_title="$(printf '%s' "$selected_row" | cut -f3-)"

  if ! process_task "$selected_id" "$selected_title"; then
    fail "Task failed without recoverable work: ${selected_id}"
  fi

  processed=$((processed + 1))
done

log "Ralph loop finished. Accepted tasks: ${processed}"
