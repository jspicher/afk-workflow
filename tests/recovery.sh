#!/usr/bin/env bash
set -euo pipefail
RUNTIME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)
source "$RUNTIME/lib/common.sh"
source "$RUNTIME/lib/store.sh"
source "$RUNTIME/lib/recovery.sh"
TEST_ROOT=$(mktemp -d)
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
for scenario in tracked ignored amended; do
  mkdir -p "$TEST_ROOT/$scenario"; cd "$TEST_ROOT/$scenario"
  git init -q; git config user.name Fixture; git config user.email fixture@example.invalid
  REPO=$PWD; ROOT="$REPO/docs/afk-workflow"; TRACKER=local; FORMAT=markdown; ISSUES_GLOB=''
  RUN_ID=original; RUN="$REPO/.git/afk-workflow/runs/$RUN_ID"; TICKET_RUN="$RUN/ticket-1"; PENDING="$REPO/.git/afk-workflow/pending.json"
  mkdir -p "$ROOT/backlog/f/issues" "$TICKET_RUN"
  path="$ROOT/backlog/f/issues/01.md"
  printf '# Ticket\nStatus: ready-for-agent\nType: AFK\n## Blocked by\nNone\n## Approved test seams\nApproval: approved\n' > "$path"
  [[ "$scenario" != ignored ]] || printf 'docs/\n' > .gitignore
  printf '0\n' > answer.txt; git add -A; git commit -qm baseline
  load_tickets; select_ticket; cp "$RUN/selected.json" "$TICKET_RUN/task.json"
  printf '42\n' > answer.txt; git add answer.txt; git commit -qm implementation
  commit=$(git rev-parse HEAD); journal_write committed "$commit"
  # Crash after the status write, or after its amendment but before journal cleanup.
  set_status "$TICKET_RUN/task.json" 'done' 'Original completion.'
  [[ "$scenario" != amended ]] || git commit --only --amend --no-edit -- "$path" >/dev/null
  RUN_ID=restart
  check_starting_state; recover_pending
  [[ ! -f "$PENDING" && $(git rev-list --count HEAD) == 2 && -z $(git status --porcelain) ]]
  [[ $(grep -c 'Original completion.' "$path") == 1 ]]
  printf 'PASS local %s interrupted completion reconciliation\n' "$scenario"
done

mkdir -p "$TEST_ROOT/github"; cd "$TEST_ROOT/github"
git init -q; git config user.name Fixture; git config user.email fixture@example.invalid
printf '42\n' > answer.txt; git add answer.txt; git commit -qm implementation
REPO=$PWD; ROOT=$PWD; TRACKER=github; FORMAT=markdown; GH_REPO=owner/repo; CONFIG="$PWD/.git/config.json"
printf '{"tracker":{}}\n' > "$CONFIG"
gh() {
  local endpoint='' arg
  if [[ "$1" == api ]]; then
    for arg in "$@"; do [[ "$arg" != repos/* ]] || endpoint=$arg; done
    case "$endpoint" in
      *'/issues?state='*) jq '[{number:1,state:.state,state_reason:"completed",labels:(.labels|map({name:.})),body:"Type: AFK\n## Approved test seams\nApproval: approved"}]' .git/hosted.json;;
      *'/dependencies/'*) printf '[]\n';;
      *'/comments?'*)
        if [[ " $* " == *' --jq '* ]]; then jq -r '.comments[].body' .git/hosted.json; else jq .comments .git/hosted.json; fi;;
      *'/labels') jq -r '.labels[]' .git/hosted.json;;
      'repos/owner/repo/issues/1') jq -r '.state+":completed"' .git/hosted.json;;
      *) return 8;;
    esac
  elif [[ "$1 $2" == 'issue comment' ]]; then
    jq --rawfile body "${@: -1}" '.comments += [{body:$body}]' .git/hosted.json > .git/next.json; mv .git/next.json .git/hosted.json
  elif [[ "$1 $2" == 'issue close' ]]; then
    [[ ! -f .git/fail-close ]] || { rm .git/fail-close; return 9; }
    jq '.state="closed"' .git/hosted.json > .git/next.json; mv .git/next.json .git/hosted.json
  elif [[ "$1 $2" == 'issue edit' ]]; then
    [[ ! -f .git/fail-edit ]] || { rm .git/fail-edit; return 9; }
    jq --arg value "${@: -1}" '.labels -= [$value]' .git/hosted.json > .git/next.json; mv .git/next.json .git/hosted.json
  else return 8; fi
}
for failure in close edit; do
  printf '{"state":"open","labels":["ready-for-agent"],"comments":[]}\n' > .git/hosted.json
  RUN_ID="original-$failure"; RUN="$PWD/.git/afk-workflow/runs/$RUN_ID"; TICKET_RUN="$RUN/ticket-1"; PENDING="$PWD/.git/afk-workflow/pending.json"
  mkdir -p "$TICKET_RUN"
  load_tickets; select_ticket; cp "$RUN/selected.json" "$TICKET_RUN/task.json"
  commit=$(git rev-parse HEAD); journal_write committed "$commit"
  touch ".git/fail-$failure"
  if finish_status "$TICKET_RUN/task.json" "$commit"; then printf 'Expected injected failure\n' >&2; exit 1; fi
  RUN_ID=restart
  check_starting_state; recover_pending
  [[ ! -f "$PENDING" ]]
  jq -e '.state=="closed" and (.comments|length)==1 and (.labels|length)==0' .git/hosted.json >/dev/null
  printf 'PASS GitHub interrupted %s reconciles without duplicate comments\n' "$failure"
done
printf 'All recovery checks passed.\n'
