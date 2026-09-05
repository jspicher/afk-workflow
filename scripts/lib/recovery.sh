#!/usr/bin/env bash

source_fingerprint() {
  local index="$TICKET_RUN/fingerprint.index" tree
  GIT_INDEX_FILE="$index" git read-tree HEAD || return 1
  GIT_INDEX_FILE="$index" git add -A || return 1
  tree=$(GIT_INDEX_FILE="$index" git write-tree) || return 1
  rm -f -- "$index"
  printf '%s\n' "$tree"
}

preserve_and_restore() {
  [[ $(git rev-parse HEAD) == "$BASE" ]] || fail 'Unexpected commit: refusing restoration.'
  local file path backup="$TICKET_RUN/recovery"
  mkdir -p "$backup/new"
  git diff --binary --full-index "$BASE" > "$backup/changes.patch" || return 1
  git diff --name-only -z "$BASE" > "$backup/tracked.paths"
  git ls-files --others --exclude-standard -z > "$backup/new.paths"
  while IFS= read -r -d '' file; do
    [[ "$file" != /* && "/$file/" != */../* && ! -L "$file" ]] || return 1
    mkdir -p "$backup/new/$(dirname "$file")"
    cp -p -- "$file" "$backup/new/$file" || return 1
    [[ $(hash_file "$file") == "$(hash_file "$backup/new/$file")" ]] || return 1
  done < "$backup/new.paths"
  if [[ -s "$backup/changes.patch" ]]; then git apply --reverse --check "$backup/changes.patch" || return 1; fi
  while IFS= read -r -d '' path; do git restore --source="$BASE" --staged --worktree -- "$path" || return 1; done < "$backup/tracked.paths"
  while IFS= read -r -d '' file; do
    [[ $(hash_file "$file") == "$(hash_file "$backup/new/$file")" ]] || return 1
    rm -f -- "$file" || return 1
  done < "$backup/new.paths"
  [[ -z $(git status --porcelain --untracked-files=all) ]] || return 1
  printf 'Restored %s; recovery artifacts: %s\n' "$BASE" "$backup"
}

journal_write() {
  jq -n --arg phase "$1" --arg commit "${2:-}" --arg task "$TICKET_RUN/task.json" --arg run "$RUN_ID" \
    '{phase:$phase,commit:$commit,task:$task,run:$run}' > "$PENDING.tmp"
  mv -- "$PENDING.tmp" "$PENDING"
}

finish_status() {
  local task=$1 commit=$2 path already=false
  if [[ "$TRACKER" == local ]]; then
    path=$(jq -r .path "$task")
    if [[ -f "$TICKET_RUN/status-expected.md" ]] && cmp -s -- "$path" "$TICKET_RUN/status-expected.md"; then already=true; fi
  else
    local marker comments number
    number=$(jq -r .number "$task")
    marker="[afk-run:$RUN_ID:$(jq -r .id "$task"):done]"
    comments=$(gh api --paginate "repos/$GH_REPO/issues/$number/comments?per_page=100" --jq '.[].body') || return 1
    if [[ "$comments" == *"$marker"* ]]; then
      load_tickets
      # Hosted status is injected into body by load_tickets. Ignore only that
      # controller-owned line when comparing the already-completed snapshot.
      if jq -e --slurpfile original "$task" '
        def decision: .body | split("\n") | map(select(startswith("Status:")|not)) | join("\n");
        any(.[]; .id==$original[0].id and .status=="done" and
          decision==($original[0]|decision) and .deps==$original[0].deps and
          .kind==$original[0].kind and .approved==$original[0].approved)
      ' "$RUN/tickets.json" >/dev/null; then already=true; fi
    fi
  fi
  if [[ "$already" != true ]]; then
    assert_ticket_current "$task"
  fi
  if [[ "$already" != true || "$TRACKER" == github ]]; then
    set_status "$task" 'done' "Implementation committed; checks and independent review passed. Run $RUN_ID." || return 1
  fi
  if [[ "$TRACKER" == local ]]; then
    path=$(jq -r .path "$task")
    if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      if [[ $(git rev-parse HEAD) == "$commit" ]]; then
        git commit --only --amend --no-edit -- "$path" >/dev/null || return 1
      else
        [[ $(git rev-parse HEAD^) == "$(git rev-parse "$commit^")" ]] || return 1
      fi
      path=$(repo_relative "$path") || return 1
      git diff --quiet "$commit" HEAD -- . ":(exclude,literal)$path" || return 1
      [[ -z $(git status --porcelain --untracked-files=all) ]] || return 1
    fi
  fi
  journal_write complete "$(git rev-parse HEAD)"
  rm -f -- "$PENDING"
}

recover_pending() {
  [[ -f "$PENDING" ]] || return 0
  local phase commit task original_run
  phase=$(jq -r .phase "$PENDING"); commit=$(jq -r .commit "$PENDING"); task=$(jq -r .task "$PENDING")
  if [[ "$phase" == committed ]]; then
    [[ -n "$commit" && -f "$task" ]] || fail "Pending completion needs inspection: $PENDING"
    TICKET_RUN=$(dirname "$task")
    if [[ $(git rev-parse HEAD) != "$commit" ]]; then
      [[ "$TRACKER" == local && -f "$TICKET_RUN/status-expected.md" ]] || fail 'Pending completion HEAD changed.'
      local path
      path=$(jq -r .path "$task")
      cmp -s -- "$path" "$TICKET_RUN/status-expected.md" || fail 'Pending completion metadata changed.'
      path=$(repo_relative "$path") || fail 'Pending ticket escaped repository.'
      git diff --quiet "$commit" HEAD -- . ":(exclude,literal)$path" || fail 'Pending completion source changed.'
    fi
    original_run=$RUN_ID
    RUN_ID=$(jq -r .run "$PENDING")
    finish_status "$task" "$commit" || fail "Cannot reconcile tracker update: $PENDING"
    RUN_ID=$original_run
  elif [[ "$phase" == complete ]]; then rm -f -- "$PENDING"
  else fail "Interrupted ticket: inspect $PENDING and its artifacts before restarting."; fi
}

check_starting_state() {
  [[ -n $(git status --porcelain --untracked-files=all) ]] || return 0
  # The only recoverable dirty state is the exact saved local metadata write.
  local task expected path changed
  [[ "$TRACKER" == local && -f "$PENDING" && $(jq -r .phase "$PENDING") == committed ]] || fail 'Commit or isolate existing tracked/untracked work before running.'
  task=$(jq -r .task "$PENDING"); expected="$(dirname "$task")/status-expected.md"
  path=$(jq -r .path "$task")
  [[ -f "$expected" ]] && cmp -s -- "$path" "$expected" || fail 'Pending metadata differs from the saved completion write.'
  path=$(repo_relative "$path") || fail 'Pending ticket escaped repository.'
  while IFS= read -r -d '' changed; do
    [[ "$changed" == "$path" ]] || fail "Unrelated work during recovery: $changed"
  done < <({ git diff --name-only -z HEAD; git ls-files --others --exclude-standard -z; })
  # Also reject staged-only edits that cancel an unstaged change in the worktree.
  while IFS= read -r -d '' changed; do
    [[ "$changed" == "$path" ]] || fail "Unrelated staged work during recovery: $changed"
  done < <(git diff --cached --name-only -z)
}
