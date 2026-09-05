#!/usr/bin/env bash
# Standalone pre-commit review for the interactive implement skill.
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
[[ $# -ge 2 ]] || fail 'Usage: review.sh BASE SPEC_FILE [--config FILE]'
base_ref=$1; spec_file=$2; shift 2
CONFIG=''; IMPL=''; REVIEWER=''
if (($#)); then [[ $# == 2 && "$1" == --config ]] || fail 'Expected --config FILE'; CONFIG=$2; fi
spec_file="$(absolute "$(dirname "$spec_file")")/$(basename "$spec_file")"
load_config
BASE=$(git rev-parse --verify "$base_ref^{commit}") || fail 'Invalid review baseline.'
engine_preflight
RUN_ID="review-$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN=$(git rev-parse --git-path "afk-workflow/runs/$RUN_ID")
mkdir -p "$RUN"; RUN=$(absolute "$RUN"); TICKET_RUN=$RUN
jq -n --rawfile body "$spec_file" '{id:"interactive",body:$body}' > "$RUN/task.json"
: > "$RUN/checks.log"
check_gate || fail "Project checks failed: $RUN/checks.log"
before=$(source_fingerprint)
review_head=$(git rev-parse HEAD)
write_prompt reviewer review "$RUN/task.json" "$RUN/review.prompt"
engine_run reviewer "$RUN/review.prompt" "$RUN/review.json" "$RUNTIME/schemas/review.json" || fail "Reviewer failed: $RUN"
[[ $(git rev-parse HEAD) == "$review_head" && $(source_fingerprint) == "$before" ]] || fail 'Reviewer changed source or commit state.'
cat "$RUN/review.json"
jq -e '.verdict=="pass" and (.standards|type=="array") and (.spec|type=="array") and ([.standards[],.spec[]]|all(.[]; .blocking==false))' "$RUN/review.json" >/dev/null || exit 2
