#!/usr/bin/env bash
set -euo pipefail
SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
mkdir -p "$TEST_ROOT/bin"
cp "$SOURCE/tests/mock-engine.sh" "$TEST_ROOT/bin/claude"
cp "$SOURCE/tests/mock-engine.sh" "$TEST_ROOT/bin/codex"
chmod +x "$TEST_ROOT/bin/claude" "$TEST_ROOT/bin/codex"
export PATH="$TEST_ROOT/bin:$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
for scenario in normal staged-only escalation; do
  mkdir -p "$TEST_ROOT/$scenario"; cd "$TEST_ROOT/$scenario"
  git init -q; git config user.name Fixture; git config user.email fixture@example.invalid
  mkdir -p docs/afk-workflow/config docs/afk-workflow/backlog/f/issues .agents/skills/implement .agents/skills/code-review
  touch .agents/skills/implement/SKILL.md .agents/skills/code-review/SKILL.md
  printf '0\n' > answer.txt
  cat > docs/afk-workflow/config/workflow.json <<'CONFIG'
{"schemaVersion":1,"assetsDir":"./docs","tracker":{"type":"local","format":"markdown"},"roles":{"implementer":{"cli":"claude"},"reviewer":{"cli":"codex"}},"review":{"maxRepairAttempts":0},"checks":[["bash","-c","test \"$(cat answer.txt)\" = 42"]]}
CONFIG
  printf '# Ticket\nStatus: ready-for-agent\nType: AFK\n## Blocked by\nNone\n## Approved test seams\nApproval: approved\n' > docs/afk-workflow/backlog/f/issues/01.md
  git add -A; git commit -qm baseline
  if [[ "$scenario" == staged-only ]]; then
    cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
printf 'unreviewed\n' > .git/hook-content
blob=$(git hash-object -w .git/hook-content)
git update-index --cacheinfo "100644,$blob,answer.txt"
HOOK
  elif [[ "$scenario" == escalation ]]; then
    cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
printf 'unreviewed\n' > answer.txt
git add answer.txt
HOOK
  fi
  [[ ! -f .git/hooks/pre-commit ]] || chmod +x .git/hooks/pre-commit
  code=0
  if [[ "$scenario" == escalation ]]; then
    MOCK_REJECT=1 bash "$SOURCE/scripts/once.sh" --config docs/afk-workflow/config/workflow.json > .git/run.log 2>&1 || code=$?
  else
    bash "$SOURCE/scripts/once.sh" --config docs/afk-workflow/config/workflow.json > .git/run.log 2>&1 || code=$?
  fi
  if [[ "$scenario" == normal ]]; then
    [[ $code == 0 && $(cat answer.txt) == 42 && -z $(git status --porcelain) ]]
  else
    [[ $code == 1 && -f .git/afk-workflow/pending.json ]]
    if grep -q '^Status: done' docs/afk-workflow/backlog/f/issues/01.md; then exit 1; fi
  fi
  printf 'PASS %s commit-tree guard\n' "$scenario"
done
