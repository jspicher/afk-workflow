#!/usr/bin/env bash
# Explicitly invoked, bounded real CLI integration check. Never uses a project backlog.
set -euo pipefail
SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
IMPLEMENTER=${1:-claude}; REVIEWER=${2:-codex}
TEST_ROOT=$(mktemp -d)
printf 'Live smoke fixture: %s\n' "$TEST_ROOT"
cd "$TEST_ROOT"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
git init -q
git config user.name 'AFK Smoke'; git config user.email smoke@example.invalid
printf '.docs/\n.agents/\ngraft/.cache/\n' > .gitignore
printf '0\n' > answer.txt
printf '# Smoke repository\n\nOnly change answer.txt to the required literal. No dependencies, network or additional tests are needed.\n' > AGENTS.md
cat > checks.json <<'CHECKS'
[["bash","-c","test \"$(cat answer.txt)\" = 42"]]
CHECKS
bash "$SOURCE/scripts/install-codex.sh" "$PWD" --apply > setup.log
bash "$SOURCE/scripts/setup.sh" --assets .docs --checks-file checks.json --implementer "$IMPLEMENTER" --reviewer "$REVIEWER" --apply >> setup.log
mkdir -p .docs/afk-workflow/backlog/smoke/issues
cat > .docs/afk-workflow/backlog/smoke/issues/01-answer.md <<'TICKET'
# Answer literal
Status: ready-for-agent
Type: AFK
## What to build
Replace the contents of answer.txt with exactly 42 followed by a newline.
## Blocked by
None
## Acceptance criteria
- answer.txt contains exactly 42 followed by a newline.
- No other source files change.
## Approved test seams
Approval: approved
- Existing full check compares the file with 42. This trivial fixture needs no additional tests. Do not ask further questions.
TICKET
git add -A; git commit -qm baseline
export AFK_CLAUDE_PLUGIN_DIR="$SOURCE"
timeout 600 bash .docs/afk-workflow/scripts/once.sh > .git/live-smoke.log 2>&1 || {
  code=$?; cat .git/live-smoke.log; exit "$code";
}
[[ $(cat answer.txt) == 42 && $(git rev-list --count HEAD) == 2 && -z $(git status --porcelain) ]]
[[ $(git diff --name-only HEAD^ HEAD) == answer.txt ]]
grep -qx 'Status: done' .docs/afk-workflow/backlog/smoke/issues/01-answer.md
printf 'PASS real %s implementer / %s reviewer; logs: %s/.git/live-smoke.log\n' "$IMPLEMENTER" "$REVIEWER" "$TEST_ROOT"
