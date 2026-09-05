#!/usr/bin/env bash
set -euo pipefail
SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
printf 'Fixture directory: %s\n' "$TEST_ROOT"
# Keep failed fixtures for diagnosis. Successful fixtures are also local temp artifacts.
mkdir -p "$TEST_ROOT/bin"
cp "$SOURCE/tests/mock-engine.sh" "$TEST_ROOT/bin/claude"
cp "$SOURCE/tests/mock-engine.sh" "$TEST_ROOT/bin/codex"
chmod +x "$TEST_ROOT/bin/claude" "$TEST_ROOT/bin/codex"
export PATH="$TEST_ROOT/bin:$PATH"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
COUNT=0

fixture() {
  COUNT=$((COUNT+1)); target="$TEST_ROOT/case $COUNT"
  mkdir -p "$target"; cd "$target"
  if [[ -d "$TEST_ROOT/seed" ]]; then cp -a "$TEST_ROOT/seed/." "$target/"; return; fi
  git init -q
  git config user.name 'AFK Fixture'; git config user.email fixture@example.invalid
  printf '.docs/\n.agents/\n' > .gitignore
  printf '0\n' > answer.txt
  # shellcheck disable=SC2016
  printf '%s\n' '[["bash","-c","test \"$(cat answer.txt)\" = 42"]]' > "$TEST_ROOT/checks.json"
  bash "$SOURCE/scripts/install-codex.sh" "$target" --apply > "$TEST_ROOT/setup.log"
  bash "$SOURCE/scripts/setup.sh" --assets .docs --checks-file "$TEST_ROOT/checks.json" --apply >> "$TEST_ROOT/setup.log"
  mkdir -p .docs/afk-workflow/backlog/fixture/issues
  cat > .docs/afk-workflow/backlog/fixture/issues/01-answer.md <<'TICKET'
# Answer
Status: ready-for-agent
Type: AFK

## What to build
Make answer.txt contain the literal 42.

## Acceptance criteria
- The answer is 42.

## Blocked by
None

## Approved test seams
Approval: approved
- Read answer.txt and compare with the independently specified literal 42.
TICKET
  git add -A; git commit -qm baseline
  mkdir -p "$TEST_ROOT/seed"
  cp -a "$target/." "$TEST_ROOT/seed/"
}

run_expect() {
  local expected=$1; shift
  local code=0
  bash .docs/afk-workflow/scripts/afk.sh "$@" > "$TEST_ROOT/run-$COUNT.log" 2>&1 || code=$?
  if [[ "$code" != "$expected" ]]; then cat "$TEST_ROOT/run-$COUNT.log"; printf 'Expected %s got %s\n' "$expected" "$code" >&2; exit 1; fi
}

for pairing in 'claude codex' 'codex claude' 'claude claude' 'codex codex'; do
  fixture
  read -r implementer reviewer <<< "$pairing"
  run_expect 0 1 --implementer "$implementer" --reviewer "$reviewer"
  [[ $(cat answer.txt) == 42 && $(git rev-list --count HEAD) == 2 ]]
  grep -q '^Status: done' .docs/afk-workflow/backlog/fixture/issues/01-answer.md
  printf 'PASS roles %s\n' "$pairing"
done
fixture
MOCK_REPAIR=1 run_expect 0 1
[[ $(cat .git/mock-review-count) == 2 ]]
printf 'PASS repair and re-review\n'
fixture
MOCK_REJECT=1 MOCK_BINARY=1 run_expect 2 1
[[ $(cat answer.txt) == 0 && ! -f new.bin && $(git rev-list --count HEAD) == 1 ]]
grep -q '^Status: ready-for-human' .docs/afk-workflow/backlog/fixture/issues/01-answer.md
[[ $(find .git/afk-workflow -name new.bin | wc -l) -eq 1 ]]
[[ $(cat .git/mock-review-count) == 3 ]]
printf 'PASS exhausted repairs preserve binary/new files and restore source\n'
fixture
sed -i 's/^None$/missing-ticket/' .docs/afk-workflow/backlog/fixture/issues/01-answer.md
run_expect 2 1
[[ ! -f .git/mock-review-count && $(cat answer.txt) == 0 ]]
printf 'PASS unresolved blocker never runs\n'
fixture
sed -i '/^Approval: approved$/d' .docs/afk-workflow/backlog/fixture/issues/01-answer.md
run_expect 2 1
grep -q '^Status: needs-info' .docs/afk-workflow/backlog/fixture/issues/01-answer.md
printf 'PASS missing approval escalates\n'
fixture
printf 'unrelated\n' > unrelated.txt
run_expect 1 1
[[ $(cat unrelated.txt) == unrelated && $(cat answer.txt) == 0 ]]
printf 'PASS unrelated work preserved\n'
fixture
MOCK_REVIEW_ERROR=1 run_expect 1 1
[[ $(git rev-list --count HEAD) == 1 && -f .git/afk-workflow/pending.json ]]
printf 'PASS reviewer error cannot complete\n'
fixture
MOCK_REVIEW_MUTATE=1 run_expect 1 1
[[ $(git rev-list --count HEAD) == 1 ]]
printf 'PASS reviewer mutation detected\n'
fixture
bash "$SOURCE/scripts/migrate.sh" --from .docs --to 'working docs' > "$TEST_ROOT/migrate-preview.log"
[[ -d .docs/afk-workflow && ! -d 'working docs/afk-workflow' ]]
bash "$SOURCE/scripts/migrate.sh" --from .docs --to 'working docs' --apply > "$TEST_ROOT/migrate.log"
[[ -d 'working docs/afk-workflow' && ! -d .docs/afk-workflow ]]
[[ $(jq -r .assetsDir 'working docs/afk-workflow/config/workflow.json') == './working docs' ]]
grep -q '^AFK_WORKFLOW_ROOT=working docs/afk-workflow' AGENTS.md
printf 'PASS relocation with spaces and reference updates\n'
fixture
MOCK_TICKET_CHANGE=1 run_expect 1 1
grep -q '^Status: needs-info' .docs/afk-workflow/backlog/fixture/issues/01-answer.md
[[ $(git rev-list --count HEAD) == 1 ]]
printf 'PASS changed readiness preserved\n'
fixture
git add -f .docs/afk-workflow/backlog/fixture/issues/01-answer.md
git commit -qm 'track ticket'
run_expect 0 1
[[ $(git rev-list --count HEAD) == 3 && -z $(git status --porcelain) ]]
printf 'PASS tracked ticket completion\n'
fixture
git add -f .docs/afk-workflow/backlog/fixture/issues/01-answer.md
git commit -qm 'track ticket'
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
if grep -q '^Status: done' .docs/afk-workflow/backlog/fixture/issues/01-answer.md; then
  printf 'hook mutation\n' > answer.txt
  git add answer.txt
fi
HOOK
chmod +x .git/hooks/pre-commit
run_expect 1 1
[[ -f .git/afk-workflow/pending.json ]]
printf 'PASS metadata commit hook mutation blocks completion\n'
fixture
mkdir -p .git/afk-workflow/old
cp .docs/afk-workflow/backlog/fixture/issues/01-answer.md .git/afk-workflow/old/ticket.md
jq -n --arg path "$PWD/.docs/afk-workflow/backlog/fixture/issues/01-answer.md" --rawfile body .git/afk-workflow/old/ticket.md '{id:"fixture/01-answer",path:$path,body:$body}' > .git/afk-workflow/old/task.json
jq -n --arg commit "$(git rev-parse HEAD)" --arg task "$PWD/.git/afk-workflow/old/task.json" '{phase:"committed",commit:$commit,task:$task,run:"original"}' > .git/afk-workflow/pending.json
printf 'unrelated\n' > staged.txt; git add staged.txt
run_expect 1 1
git diff --cached --name-only | grep -qx staged.txt
[[ $(git rev-list --count HEAD) == 1 ]]
printf 'PASS recovery refuses unrelated staged work\n'
fixture
bash "$SOURCE/scripts/setup.sh" --assets .docs --implementer codex --reviewer claude --apply > "$TEST_ROOT/rerun.log"
[[ $(jq -r .roles.implementer.cli .docs/afk-workflow/config/workflow.json) == codex ]]
cp AGENTS.md "$TEST_ROOT/pointer.md"
bash "$SOURCE/scripts/setup.sh" --assets .docs --apply >> "$TEST_ROOT/rerun.log"
cmp -s AGENTS.md "$TEST_ROOT/pointer.md"
[[ $(jq -r .roles.reviewer.cli .docs/afk-workflow/config/workflow.json) == claude ]]
printf 'PASS setup explicit overrides and idempotent pointers\n'
fixture
bash "$SOURCE/scripts/migrate.sh" --from .docs --to docs --apply > "$TEST_ROOT/migration-direction.log"
printf 'Existing target .docs/afk-workflow, source docs/afk-workflow\n' > mixed.md
bash "$SOURCE/scripts/migrate.sh" --from docs --to .docs --apply >> "$TEST_ROOT/migration-direction.log"
grep -Fxq 'Existing target .docs/afk-workflow, source .docs/afk-workflow' mixed.md
[[ $(jq -r .assetsDir .docs/afk-workflow/config/workflow.json) == ./.docs ]]
printf 'PASS docs to .docs migration preserves existing target references\n'
printf 'All %s fixture groups passed.\n' "$COUNT"
