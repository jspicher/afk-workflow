#!/usr/bin/env bash
# Shared runtime primitives. No eval, sourced project config, or shell-built commands.

fail() { printf 'AFK error: %s\n' "$*" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || fail "Required executable missing: $1"; }
hash_file() { git hash-object --no-filters -- "$1"; }
absolute() { (cd "$1" && pwd -P); }
repo_relative() {
  local path repo
  path="$(absolute "$(dirname "$1")")/$(basename "$1")" || return 1
  repo=$(absolute "$REPO") || return 1
  [[ "$path" == "$repo/"* ]] || return 1
  printf '%s\n' "${path#"$repo/"}"
}

load_config() {
  require git; require jq
  REPO=$(git rev-parse --show-toplevel) || fail 'Run inside the target Git repository.'
  cd "$REPO" || exit 1
  if [[ -z ${CONFIG:-} ]]; then
    if [[ -f "$RUNTIME/../config/workflow.json" ]]; then
      CONFIG="$RUNTIME/../config/workflow.json"
    else
      local pointer
      pointer=$(sed -n 's/^AFK_WORKFLOW_ROOT=//p' AGENTS.md CLAUDE.md 2>/dev/null | sort -u) || true
      [[ -n "$pointer" && "$pointer" != *$'\n'* ]] || fail 'Run setup-afk-skills first, or pass --config FILE.'
      CONFIG="$REPO/$pointer/config/workflow.json"
    fi
  fi
  [[ -f "$CONFIG" ]] || fail "Configuration not found: $CONFIG"
  CONFIG="$(absolute "$(dirname "$CONFIG")")/$(basename "$CONFIG")"
  jq -e '
    .schemaVersion == 1 and (.assetsDir | type == "string" and length > 0) and
    (.tracker.type | IN("local","github","gitlab","jira","other")) and
    (.roles.implementer.cli | IN("claude","codex")) and
    (.roles.reviewer.cli | IN("claude","codex")) and
    (.review.maxRepairAttempts | type == "number" and . >= 0 and . <= 10 and floor == .) and
    ([.roles[] | .model? | select(. != null) | type == "string"] | all)
  ' "$CONFIG" >/dev/null || fail 'Invalid workflow.json; run setup to review it.'
  ASSETS=$(jq -r '.assetsDir' "$CONFIG")
  ASSETS=${ASSETS#./}; ASSETS=${ASSETS%/}
  [[ "$ASSETS" != /* && "$ASSETS" != *:* && "/$ASSETS/" != */../* && "$ASSETS" != *$'\n'* ]] || fail 'assetsDir must be a repository-relative directory without .. components.'
  ROOT="$REPO/$ASSETS/afk-workflow"
  [[ -d "$ROOT" ]] || fail "Configured workflow root missing: $ROOT"
  ROOT=$(absolute "$ROOT")
  [[ "$ROOT" == "$(absolute "$REPO")/"* ]] || fail 'Workflow directory resolves outside the repository.'
  [[ "$CONFIG" == "$ROOT/config/workflow.json" ]] || fail 'Configuration location disagrees with assetsDir.'
  IMPL=${IMPL:-$(jq -r '.roles.implementer.cli' "$CONFIG")}
  REVIEWER=${REVIEWER:-$(jq -r '.roles.reviewer.cli' "$CONFIG")}
  [[ "$IMPL" =~ ^(claude|codex)$ && "$REVIEWER" =~ ^(claude|codex)$ ]] || fail 'Roles must be claude or codex.'
  TRACKER=$(jq -r '.tracker.type' "$CONFIG")
  [[ "$TRACKER" == local || "$TRACKER" == github ]] || fail "$TRACKER is configured for interactive use only; headless supports local and github."
  FORMAT=$(jq -r '.tracker.format // "markdown"' "$CONFIG")
  [[ "$FORMAT" == markdown || "$FORMAT" == fos-yaml ]] || fail "Unsupported local ticket format: $FORMAT"
  REPAIRS=$(jq -r '.review.maxRepairAttempts' "$CONFIG")
  if [[ "$TRACKER" == github ]]; then
    require gh
    GH_REPO=$(jq -r '.tracker.repository // empty' "$CONFIG")
    [[ "$GH_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'Set tracker.repository to owner/repo.'
    gh auth status >/dev/null 2>&1 || fail 'Sign into gh before launching the runner.'
  fi
}

parse_ticket() {
  local file=$1 id=$2 pairs
  pairs=$(awk -v format="$FORMAT" -f "$RUNTIME/lib/ticket.awk" "$file") || return 1
  jq -eRn --arg id "$id" --arg path "$file" --rawfile body "$file" '
    [inputs | split("\t") | {key:.[0], value:(.[1:]|join("\t"))}] as $fields |
    {id:$id,path:$path,body:$body,status:"",kind:"AFK",deps:[],approved:false} |
    reduce $fields[] as $f (.;
      if $f.key == "dep" then .deps += [$f.value]
      elif $f.key == "approved" then .approved = ($f.value == "true")
      elif $f.key == "blockers_declared" then .blockers_declared = ($f.value == "true")
      else .[$f.key] = $f.value end) |
    select(.status | IN("needs-triage","needs-info","ready-for-agent","ready-for-human","wontfix","done")) |
    select(.kind | IN("AFK","HITL"))
  ' <<< "$pairs"
}

label_for() { jq -r --arg state "$1" '.tracker.labels[$state] // $state' "$CONFIG"; }

set_status() {
  local task=$1 state=$2 note=$3 path number stamp tmp
  stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [[ "$TRACKER" == local ]]; then
    path=$(jq -r .path "$task")
    tmp=$(mktemp "$(dirname "$path")/.afk-status.XXXXXX")
    awk -v state="$state" -v format="$FORMAT" '
      BEGIN {front=0; changed=0}
      NR==1 && /^---\r?$/ {front=1; print; next}
      front && /^---\r?$/ {front=0}
      !changed && ((format=="fos-yaml" && front && /^status:/) || (format=="markdown" && /^(\*\*)?Status:(\*\*)?[[:space:]]/)) {
        print (format=="fos-yaml" ? "status: " : "Status: ") state; changed=1; next
      }
      {print}
      END {if (!changed) exit 2}
    ' "$path" > "$tmp" || { rm -f -- "$tmp"; return 1; }
    printf '\n## Progress\n\n%s: %s\n' "$stamp" "$note" >> "$tmp"
    if [[ "$state" == 'done' ]]; then cp -- "$tmp" "$TICKET_RUN/status-expected.md" || return 1; fi
    cat "$tmp" > "$path"; rm -f -- "$tmp"
    [[ $(parse_ticket "$path" "$(jq -r .id "$task")" | jq -r .status) == "$state" ]]
  else
    number=$(jq -r .number "$task")
    local marker
    marker="[afk-run:$RUN_ID:$(jq -r .id "$task"):$state]"
    local comments
    comments=$(gh api --paginate "repos/$GH_REPO/issues/$number/comments?per_page=100" --jq '.[].body') || return 1
    if [[ "$comments" != *"$marker"* ]]; then
      printf '%s\n\n%s: %s\n' "$marker" "$stamp" "$note" > "$RUN/comment.md"
      gh issue comment "$number" -R "$GH_REPO" --body-file "$RUN/comment.md" >/dev/null || return 1
    fi
    if [[ "$state" == 'done' ]]; then
      gh issue close "$number" -R "$GH_REPO" --reason completed >/dev/null || return 1
    fi
    local labels current desired
    labels=$(gh api "repos/$GH_REPO/issues/$number/labels" --jq '.[].name') || return 1
    for current in needs-triage needs-info ready-for-agent ready-for-human wontfix 'done'; do
      desired=$(label_for "$current")
      if [[ $current != "$state" ]] && grep -Fxq -- "$desired" <<< "$labels"; then
        gh issue edit "$number" -R "$GH_REPO" --remove-label "$desired" >/dev/null || return 1
      fi
    done
    if [[ "$state" == 'done' ]]; then
      [[ $(gh api "repos/$GH_REPO/issues/$number" --jq '.state + ":" + .state_reason') == closed:completed ]]
    else
      gh issue edit "$number" -R "$GH_REPO" --add-label "$(label_for "$state")" >/dev/null || return 1
      gh api "repos/$GH_REPO/issues/$number/labels" --jq '.[].name' | grep -Fxq -- "$(label_for "$state")"
    fi
  fi
}
