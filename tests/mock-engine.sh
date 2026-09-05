#!/usr/bin/env bash
set -euo pipefail
engine=$(basename "$0")
case "${1:-}" in auth|login) exit 0;; --help) printf '%s\n' '--permission-prompts'; exit 0;; esac
output=''
while (($#)); do
  if [[ "$1" == --output-last-message ]]; then output=$2; shift 2; else shift; fi
done
prompt=$(cat)
if [[ "$prompt" == *'AFK ROLE: reviewer'* ]]; then
  count_file=$(git rev-parse --git-path mock-review-count)
  count=0; [[ ! -f "$count_file" ]] || count=$(cat "$count_file")
  count=$((count+1)); printf '%s' "$count" > "$count_file"
  [[ ${MOCK_REVIEW_MUTATE:-0} != 1 ]] || printf 'review mutation\n' > answer.txt
  if [[ ${MOCK_TICKET_CHANGE:-0} == 1 ]]; then sed -i 's/^Status: ready-for-agent$/Status: needs-info/' .docs/afk-workflow/backlog/fixture/issues/01-answer.md; fi
  [[ ${MOCK_REVIEW_ERROR:-0} != 1 ]] || exit 7
  if [[ ${MOCK_REJECT:-0} == 1 || (${MOCK_REPAIR:-0} == 1 && $count == 1) ]]; then
    result='{"verdict":"changes_requested","summary":"Fix requirement","standards":[],"spec":[{"finding":"Expected behavior missing","blocking":true}]}'
  else result='{"verdict":"pass","summary":"Both axes assessed","standards":[],"spec":[]}'; fi
else
  [[ ${MOCK_IMPL_ERROR:-0} != 1 ]] || exit 8
  printf '42\n' > answer.txt
  if [[ ${MOCK_BINARY:-0} == 1 ]]; then printf '\000\001\377' > new.bin; fi
  result='{"outcome":"ready","summary":"Implemented fixture","commit_message":"feat: implement fixture answer"}'
fi
if [[ "$engine" == claude ]]; then
  jq -nc --argjson data "$result" '{type:"result",is_error:false,structured_output:$data,session_id:"fixture-claude"}'
else
  printf '%s\n' "$result" > "$output"
  printf '%s\n' '{"type":"thread.started","thread_id":"fixture-codex"}' '{"type":"turn.completed"}'
fi
