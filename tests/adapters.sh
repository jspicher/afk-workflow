#!/usr/bin/env bash
set -euo pipefail
RUNTIME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd -P)
source "$RUNTIME/lib/common.sh"
source "$RUNTIME/lib/store.sh"
TEST_ROOT=$(mktemp -d)
cd "$TEST_ROOT"
git init -q
REPO=$PWD; ROOT="$REPO/docs/afk-workflow"; RUN="$REPO/artifacts"
mkdir -p "$ROOT/backlog/sample/issues" "$RUN"
CONFIG="$REPO/config.json"
printf '{"tracker":{}}\n' > "$CONFIG"
TRACKER=local; FORMAT=markdown; ISSUES_GLOB=''
ticket="$ROOT/backlog/sample/issues/01.md"
cat > "$ticket" <<'TICKET'
# Fixture
Status: ready-for-agent
Type: AFK
## Blocked by
02
## Approved test seams
Approval: approved
- Observable fixture behavior.
TICKET
sed 's/ready-for-agent/done/;s/^02$/None/' "$ticket" > "$ROOT/backlog/sample/issues/02.md"
ISSUES_GLOB='docs/afk-workflow/backlog/sample/issues/01.md'
load_tickets; select_ticket
jq -e '.id=="sample/01"' "$RUN/selected.json" >/dev/null
printf 'PASS selected glob retains external dependency context\n'
sed -i 's/^Status: done$/Status: ready-for-agent/;s/^None$/01/' "$ROOT/backlog/sample/issues/02.md"
load_tickets; select_ticket
[[ ! -s "$RUN/selected.json" ]]
printf 'PASS cycle blocks execution\n'
FORMAT=fos-yaml
cat > "$RUN/yaml.md" <<'TICKET'
---
id: "FOS-42"
status: ready-for-agent
depends_on: ["FOS-41", 'FOS-40']
custom_field: retained
---
## Approved test seams
Approval: approved
TICKET
parse_ticket "$RUN/yaml.md" fixture > "$RUN/parsed.json"
jq -e '.local_id=="FOS-42" and .deps==["FOS-41","FOS-40"] and .approved' "$RUN/parsed.json" >/dev/null
RUN_ID=fixture
set_status "$RUN/parsed.json" needs-info 'Need clarification.'
grep -qx 'custom_field: retained' "$RUN/yaml.md"
grep -qx 'status: needs-info' "$RUN/yaml.md"
printf 'PASS FoS YAML parsing and lossless metadata update\n'
printf '\nstatus: done\n' >> "$RUN/yaml.md"
sed -i 's/^status: needs-info$/status: unknown-state/' "$RUN/yaml.md"
if parse_ticket "$RUN/yaml.md" fixture >/dev/null; then exit 1; fi
printf 'PASS invalid status fails closed\n'

TRACKER=github; FORMAT=markdown; GH_REPO=owner/repo; ISSUES_GLOB=''
gh() {
  local endpoint='' arg
  for arg in "$@"; do [[ "$arg" != repos/* ]] || endpoint=$arg; done
  case "$endpoint" in
    'repos/owner/repo/issues?state=all&per_page=100')
      jq -nc '[{number:1,state:"open",labels:[{name:"ready-for-agent"}],body:"Type: AFK\n## Approved test seams\nApproval: approved"}]'
      jq -nc '[{number:2,state:"closed",state_reason:"completed",labels:[],body:""},{number:3,pull_request:{},state:"open"}]';;
    *'/1/dependencies/'*) jq -nc --arg repo "${DEPENDENCY_REPO:-elsewhere/repo}" '[{number:2,repository_url:("https://api.github.com/repos/"+$repo)}]';;
    *'/dependencies/'*|*'/comments?'*) printf '[]\n';;
    *) return 9;;
  esac
}
load_tickets
jq -e 'length==2 and ([.[]|select(.id=="#1")][0].runnable==false)' "$RUN/tickets.json" >/dev/null
DEPENDENCY_REPO=owner/repo load_tickets
jq -e '[.[]|select(.id=="#1")][0].runnable' "$RUN/tickets.json" >/dev/null
printf 'PASS GitHub pagination, PR exclusion, and repository-qualified blockers\n'
source "$RUNTIME/lib/install.sh"
mkdir -p "$TEST_ROOT/incoming" "$TEST_ROOT/installed"
printf 'upstream\n' > "$TEST_ROOT/incoming/skill.md"
printf 'customized\n' > "$TEST_ROOT/installed/skill.md"
if sync_preview "$TEST_ROOT/incoming" "$TEST_ROOT/installed" "$TEST_ROOT/manifest.json" > "$RUN/conflict.log" 2>&1; then exit 1; fi
grep -qx customized "$TEST_ROOT/installed/skill.md"
cp "$TEST_ROOT/incoming/skill.md" "$TEST_ROOT/installed/skill.md"
printf 'unmanaged\n' > "$TEST_ROOT/installed/custom.md"
sync_apply "$TEST_ROOT/incoming" "$TEST_ROOT/installed" "$TEST_ROOT/manifest.json"
grep -qx unmanaged "$TEST_ROOT/installed/custom.md"
printf 'PASS managed installation refuses conflicts and preserves custom files\n'
printf 'All adapter checks passed.\n'
