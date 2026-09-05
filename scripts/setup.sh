#!/usr/bin/env bash
# Non-interactive apply helper. The setup skill owns the one-question-at-a-time interview.
set -euo pipefail
RUNTIME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/install.sh
source "$RUNTIME/lib/install.sh"
REPO=$(git rev-parse --show-toplevel); cd "$REPO"
assets=docs; tracker=local; implementer=claude; reviewer=codex; format=markdown; repository=''; checks=''; apply=false
pointer=$(sed -n 's/^AFK_WORKFLOW_ROOT=//p' AGENTS.md CLAUDE.md 2>/dev/null | sort -u) || true
[[ "$pointer" != *$'\n'* ]] || { printf 'Conflicting AFK pointers; reconcile first.\n' >&2; exit 1; }
[[ -z "$pointer" ]] || assets=${pointer%/afk-workflow}
updates='{}'
while (($#)); do
  case "$1" in
    --apply) apply=true; shift;;
    --assets|--tracker|--implementer|--reviewer|--format|--repository|--checks-file)
      (($#>=2)) || exit 1
      case "$1" in
        --assets) assets=$2;;
        --tracker) tracker=$2; updates=$(jq --arg v "$2" '.tracker.type=$v' <<< "$updates");;
        --implementer) implementer=$2; updates=$(jq --arg v "$2" '.roles.implementer.cli=$v' <<< "$updates");;
        --reviewer) reviewer=$2; updates=$(jq --arg v "$2" '.roles.reviewer.cli=$v' <<< "$updates");;
        --format) format=$2; updates=$(jq --arg v "$2" '.tracker.format=$v' <<< "$updates");;
        --repository) repository=$2; updates=$(jq --arg v "$2" '.tracker.repository=$v' <<< "$updates");;
        --checks-file) checks=$2;;
      esac; shift 2;;
    *) printf 'Unknown setup argument: %s\n' "$1" >&2; exit 1;;
  esac
done
if command -v cygpath >/dev/null 2>&1; then assets=$(cygpath -m "$assets"); fi
case "$assets" in "$REPO/"*) assets=${assets#"$REPO/"};; esac
assets=${assets#./}; assets=${assets%/}
[[ -n "$assets" && "$assets" != /* && "$assets" != *:* && "/$assets/" != */../* && "$assets" != *$'\n'* ]] || { printf 'Use a repository-relative assets directory.\n' >&2; exit 1; }
[[ "$tracker" =~ ^(local|github|gitlab|jira|other)$ && "$implementer" =~ ^(claude|codex)$ && "$reviewer" =~ ^(claude|codex)$ ]] || exit 1
root="$REPO/$assets/afk-workflow"
[[ -z "$pointer" || "$pointer" == "$assets/afk-workflow" ]] || { printf 'Use migrate.sh to relocate the configured AFK root.\n' >&2; exit 1; }
safe_destination "$root"
config="$root/config/workflow.json"
for existing in docs .docs; do
  if [[ "$existing" != "$assets" && -d "$REPO/$existing/afk-workflow/config" ]]; then
    printf 'Existing layout: %s. Select it or run migrate.sh explicitly.\n' "$existing" >&2; exit 1
  fi
done
[[ -f "$config" || -n "$checks" ]] || { printf 'Pass --checks-file containing an array of command argument arrays.\n' >&2; exit 1; }
tmp=$(mktemp)
trap 'rm -f -- "$tmp" "$tmp.next"' EXIT
if [[ -f "$config" ]]; then cp "$config" "$tmp"
else
  jq -n --arg assets "./$assets" --arg tracker "$tracker" --arg format "$format" --arg repository "$repository" --arg implementer "$implementer" --arg reviewer "$reviewer" \
    '{schemaVersion:1,assetsDir:$assets,tracker:{type:$tracker,format:$format},roles:{implementer:{cli:$implementer},reviewer:{cli:$reviewer}},review:{maxRepairAttempts:2}} | if $repository!="" then .tracker.repository=$repository else . end' > "$tmp"
fi
 jq --argjson updates "$updates" 'reduce ["implementer","reviewer"][] as $role (.; if $updates.roles[$role].cli != null and $updates.roles[$role].cli != .roles[$role].cli then del(.roles[$role].model) else . end) | . * $updates' "$tmp" > "$tmp.next"
 mv "$tmp.next" "$tmp"
if [[ -n "$checks" ]]; then jq --slurpfile checks "$checks" '.checks=$checks[0]' "$tmp" > "$tmp.next"; mv "$tmp.next" "$tmp"; fi
jq -e '.checks|type=="array" and length>0 and all(.[]; type=="array" and length>0 and all(.[]; type=="string"))' "$tmp" >/dev/null
sync_preview "$RUNTIME" "$root/scripts" "$root/config/installed-runtime.json"
printf 'Configuration preview (%s):\n' "$config"; cat "$tmp"
[[ "$apply" == true ]] || { printf 'No changes. Add --apply after reviewing the configuration.\n'; exit 0; }
mkdir -p "$root/config"
cp "$tmp" "$config"
sync_apply "$RUNTIME" "$root/scripts" "$root/config/installed-runtime.json"
for doc in issue-tracker triage-labels domain; do
  if [[ ! -f "$root/config/$doc.md" ]]; then
    # shellcheck disable=SC2016
    printf '# %s\n\nCanonical runtime settings: [workflow.json](workflow.json).\nWorkflow assets: `%s/afk-workflow/`.\n\nPreserve and document project-specific conventions here.\n' "$doc" "$assets" > "$root/config/$doc.md"
  fi
done
write_pointer AGENTS.md "$assets/afk-workflow"
if [[ ! -f CLAUDE.md ]] || ! grep -Eq '^@?AGENTS.md$' CLAUDE.md; then write_pointer CLAUDE.md "$assets/afk-workflow"; fi
printf 'Configured %s. Review/commit the setup files unless intentionally ignored.\n' "$root"
git check-ignore "$assets/afk-workflow/config/workflow.json" || true
