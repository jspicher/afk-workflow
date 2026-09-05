#!/usr/bin/env bash
set -euo pipefail
RUNTIME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/common.sh
source "$RUNTIME/lib/common.sh"
# shellcheck source=lib/store.sh
source "$RUNTIME/lib/store.sh"
# shellcheck source=lib/engine.sh
source "$RUNTIME/lib/engine.sh"
# shellcheck source=lib/recovery.sh
source "$RUNTIME/lib/recovery.sh"

usage() { printf 'Usage: afk.sh N [issues_glob] [--config FILE] [--implementer claude|codex] [--reviewer claude|codex]\n'; }
[[ ${1:-} != --help && ${1:-} != -h ]] || { usage; exit 0; }
[[ ${1:-} =~ ^[1-9][0-9]*$ ]] || { usage >&2; exit 1; }
LIMIT=$1; shift
CONFIG=''; IMPL=''; REVIEWER=''; ISSUES_GLOB=''; ONCE=false
while (($#)); do
  case "$1" in
    --config|--implementer|--reviewer)
      (($# >= 2)) || fail "Missing value for $1"
      case "$1" in --config) CONFIG=$2;; --implementer) IMPL=$2;; --reviewer) REVIEWER=$2;; esac; shift 2;;
    --once) ONCE=true; shift;;
    --*) fail "Unknown argument: $1";;
    *) [[ -z "$ISSUES_GLOB" ]] || fail 'Only one issue glob is supported.'; ISSUES_GLOB=$1; shift;;
  esac
done
load_config
[[ "$TRACKER" == local || -z "$ISSUES_GLOB" ]] || fail 'Issue globs apply only to local storage.'
STATE=$(git rev-parse --git-path afk-workflow)
mkdir -p "$STATE"
STATE=$(absolute "$STATE")
LOCK="$STATE/lock"
mkdir "$LOCK" 2>/dev/null || fail "Another run or stale lock exists: $LOCK. Verify its PID before removing it."
printf '%s\n' "$$" > "$LOCK/pid"
trap 'rm -f -- "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null || true' EXIT
trap 'printf "Interrupted; inspect run artifacts before restarting.\n" >&2; exit 130' INT TERM
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN="$STATE/runs/$RUN_ID"
mkdir -p "$RUN"
PENDING="$STATE/pending.json"
check_starting_state
recover_pending
engine_preflight
jq -e '.checks | type == "array" and length > 0' "$CONFIG" >/dev/null || fail 'Configure the project checks first.'
printf 'AFK: implementer=%s reviewer=%s tracker=%s root=%s\nArtifacts: %s\n' "$IMPL" "$REVIEWER" "$TRACKER" "$ROOT" "$RUN"
ESCALATED=0

escalate() {
  local state=$1 note=$2
  assert_ticket_current "$TICKET_RUN/task.json"
  preserve_and_restore || fail "Recovery not verified. Inspect $TICKET_RUN"
  set_status "$TICKET_RUN/task.json" "$state" "$note Recovery: $TICKET_RUN/recovery" || fail 'Cannot record escalation.'
  if [[ "$TRACKER" == local ]]; then
    local path
    path=$(jq -r .path "$TICKET_RUN/task.json")
    if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      git commit --only -m "chore(afk): record blocked ticket $(jq -r .id "$TICKET_RUN/task.json")" -- "$path" >/dev/null || fail 'Cannot commit ticket bookkeeping.'
      path=$(repo_relative "$path") || fail 'Ticket escaped repository.'
      git diff --quiet "$BASE" HEAD -- . ":(exclude,literal)$path" || fail 'Bookkeeping hook changed source.'
      [[ -z $(git status --porcelain --untracked-files=all) ]] || fail 'Bookkeeping hook left unreviewed changes.'
    fi
  fi
  rm -f -- "$PENDING"
  ESCALATED=$((ESCALATED+1))
}

for ((attempt=1; attempt<=LIMIT; attempt++)); do
  load_tickets
  select_ticket
  if [[ ! -s "$RUN/selected.json" ]]; then
    if ((ESCALATED>0)) || jq -e 'any(.[]; .status=="ready-for-agent")' "$RUN/tickets.json" >/dev/null; then
      printf 'BLOCKED: no runnable tickets; inspect dependencies and human handoffs.\n'; exit 2
    fi
    printf '<promise>NO MORE TASKS</promise>\n'; exit 0
  fi
  TICKET_RUN="$RUN/ticket-$attempt"
  mkdir -p "$TICKET_RUN"
  cp "$RUN/selected.json" "$TICKET_RUN/task.json"
  BASE=$(git rev-parse HEAD)
  printf '%s\n' "$BASE" > "$TICKET_RUN/base"
  journal_write implementing
  printf 'Ticket %s: %s\n' "$attempt" "$(jq -r .id "$TICKET_RUN/task.json")"
  if ! jq -e .approved "$TICKET_RUN/task.json" >/dev/null; then
    escalate needs-info 'Missing approved test seams. Triage must record Approval: approved in the Approved test seams section.'
    continue
  fi
  session=''; previous=''; success=false
  for ((round=0; round<=REPAIRS; round++)); do
    write_prompt implementer implement "$TICKET_RUN/task.json" "$TICKET_RUN/implement.prompt" "$previous"
    engine_run implementer "$TICKET_RUN/implement.prompt" "$TICKET_RUN/implementation.json" "$RUNTIME/schemas/implementation.json" "$session" || fail "Implementer failed; inspect $TICKET_RUN"
    session=$(cat "$TICKET_RUN/implementation.json.session")
    [[ $(git rev-parse HEAD) == "$BASE" ]] || fail 'Implementer committed before review. Preserving state.'
    outcome=$(jq -er '.outcome | select(IN("ready","needs-info","ready-for-human"))' "$TICKET_RUN/implementation.json") || fail 'Invalid implementation result.'
    if [[ "$outcome" != ready ]]; then
      escalate "$outcome" "$(jq -r .summary "$TICKET_RUN/implementation.json")"
      break
    fi
    : > "$TICKET_RUN/checks.log"
    if ! check_gate; then previous="$TICKET_RUN/checks.log"; continue; fi
    before=$(source_fingerprint)
    write_prompt reviewer review "$TICKET_RUN/task.json" "$TICKET_RUN/review.prompt"
    review="$TICKET_RUN/review-$round.json"
    engine_run reviewer "$TICKET_RUN/review.prompt" "$review" "$RUNTIME/schemas/review.json" || fail "Reviewer failed; inspect $TICKET_RUN"
    [[ $(git rev-parse HEAD) == "$BASE" && $(source_fingerprint) == "$before" ]] || fail 'Reviewer changed source state. Preserving state.'
    jq -e '(.verdict|IN("pass","changes_requested","blocked")) and (.standards|type=="array") and (.spec|type=="array") and ([.standards[],.spec[]] | all(.[]; (.blocking|type=="boolean") and (.finding|type=="string")))' "$review" >/dev/null || fail 'Malformed review result.'
    if jq -e '.verdict=="pass" and ([.standards[],.spec[]]|all(.[]; .blocking==false))' "$review" >/dev/null; then success=true; break; fi
    previous="$review"
    [[ $(jq -r .verdict "$review") != blocked ]] || break
  done
  [[ -f "$PENDING" ]] || continue
  if [[ "$success" != true ]]; then
    escalate ready-for-human 'Checks or review did not pass within the repair limit.'
    continue
  fi
  [[ $(source_fingerprint) == "$before" ]] || fail 'Changes no longer match the reviewed state.'
  assert_ticket_current "$TICKET_RUN/task.json"
  jq -er '.commit_message | select(type=="string" and length>0)' "$TICKET_RUN/implementation.json" > "$TICKET_RUN/commit-message.txt" || fail 'Missing commit message.'
  git add -A
  if git diff --cached --quiet; then fail 'No implementation changes to commit; inspect manually.'; fi
  git commit --file "$TICKET_RUN/commit-message.txt" || fail 'Commit failed; preserving reviewed changes.'
  commit=$(git rev-parse HEAD)
  [[ $(git rev-parse 'HEAD^{tree}') == "$before" && $(source_fingerprint) == "$before" && -z $(git status --porcelain --untracked-files=all) ]] || fail 'A commit hook changed reviewed source; investigate before completion.'
  journal_write committed "$commit"
  finish_status "$TICKET_RUN/task.json" "$commit" || fail 'Implementation committed but tracker update failed; restart to reconcile.'
  if [[ "$ONCE" == true ]]; then printf 'Single ticket complete.\n'; exit 0; fi
done
load_tickets
if ((ESCALATED>0)); then printf 'BLOCKED: %s ticket(s) escalated.\n' "$ESCALATED"; exit 2; fi
if ! jq -e 'any(.[]; .status=="ready-for-agent")' "$RUN/tickets.json" >/dev/null; then printf '<promise>NO MORE TASKS</promise>\n'; exit 0; fi
printf 'LIMIT: %s ticket attempts reached; backlog remains.\n' "$LIMIT"
exit 3
