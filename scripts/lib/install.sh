#!/usr/bin/env bash
# Verify the entire copy set before writing any destination file.
safe_destination() {
  local cursor=$1 parent
  while [[ "$cursor" != / && "$cursor" != . && -n "$cursor" ]]; do
    [[ ! -L "$cursor" ]] || { printf 'Refusing symlink path: %s\n' "$cursor" >&2; return 1; }
    parent=${cursor%/*}
    [[ "$parent" != "$cursor" ]] || break
    cursor=$parent
  done
}

sync_preview() {
  local src=$1 dest=$2 manifest=$3 file rel expected current incoming
  safe_destination "$dest" || return 1
  while IFS= read -r -d '' file; do
    rel=${file#"$src/"}; incoming=$(git hash-object --no-filters "$file")
    safe_destination "$dest/$rel" || return 1
    if [[ -e "$dest/$rel" || -L "$dest/$rel" ]]; then
      [[ -f "$dest/$rel" && ! -L "$dest/$rel" ]] || return 1
      current=$(git hash-object --no-filters "$dest/$rel")
      expected=''
      if [[ -f "$manifest" ]]; then expected=$(jq -r --arg rel "$rel" '.files[$rel] // empty' "$manifest"); fi
      if [[ "$current" != "$incoming" && "$current" != "$expected" ]]; then
        printf 'CONFLICT: preserve and reconcile %s\n' "$dest/$rel" >&2; return 1
      fi
    fi
  done < <(find "$src" -type f -print0)
}

sync_apply() {
  local src=$1 dest=$2 manifest=$3 file rel tmp
  sync_preview "$src" "$dest" "$manifest" || return 1
  mkdir -p "$dest" "$(dirname "$manifest")"
  tmp=$(mktemp)
  printf '{}\n' > "$tmp"
  while IFS= read -r -d '' file; do
    rel=${file#"$src/"}
    mkdir -p "$dest/$(dirname "$rel")"
    if [[ ! "$file" -ef "$dest/$rel" ]]; then cp -- "$file" "$dest/$rel"; fi
    jq --arg rel "$rel" --arg hash "$(git hash-object --no-filters "$file")" '.[$rel]=$hash' "$tmp" > "$tmp.next"
    mv -- "$tmp.next" "$tmp"
  done < <(find "$src" -type f -print0)
  jq '{version:"0.6.0",files:.}' "$tmp" > "$manifest"
  rm -f -- "$tmp"
}

write_pointer() {
  local file=$1 root=$2 tmp
  tmp=$(mktemp)
  if [[ -f "$file" ]]; then
    awk '/^<!-- afk-workflow:start -->$/ {inside=1;next} /^<!-- afk-workflow:end -->$/ {inside=0;next} !inside {lines[++n]=$0} END {while(n>0 && lines[n]=="") n--; for(i=1;i<=n;i++) print lines[i]}' "$file" > "$tmp"
  fi
  printf '\n<!-- afk-workflow:start -->\n## AFK Workflow\n\nAFK_WORKFLOW_ROOT=%s\n\nRead %s/config/workflow.json for roles, storage and checks. Read the config Markdown files for project conventions.\n<!-- afk-workflow:end -->\n' "$root" "$root" >> "$tmp"
  cat "$tmp" > "$file"; rm -f -- "$tmp"
}
