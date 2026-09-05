#!/usr/bin/env bash
# Relocate an AFK-owned tree and literal references. Preview is the default.
set -euo pipefail
REPO=$(git rev-parse --show-toplevel); cd "$REPO"
RUNTIME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/install.sh
source "$RUNTIME/lib/install.sh"
from=''; to=''; apply=false
while (($#)); do
  case "$1" in
    --from|--to) (($#>=2)) || exit 1; if [[ "$1" == --from ]]; then from=$2; else to=$2; fi; shift 2;;
    --apply) apply=true; shift;;
    *) printf 'Usage: migrate.sh --from docs --to .docs [--apply]\n' >&2; exit 1;;
  esac
done
from=${from#./}; from=${from%/}; to=${to#./}; to=${to%/}
for path in "$from" "$to"; do
  [[ -n "$path" && "$path" != /* && "$path" != *:* && "/$path/" != */../* && "$path" != *$'\n'* ]] || exit 1
  safe_destination "$REPO/$path/afk-workflow" || exit 1
done
old="$from/afk-workflow"; new="$to/afk-workflow"
[[ "$old" != "$new" && -d "$old" && ! -e "$new" && "$new/" != "$old/"* ]] || { printf 'Source missing, destination exists, or locations overlap.\n' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -f -- "$tmp/files" "$tmp/refs" "$tmp/replace"; rmdir "$tmp" 2>/dev/null || true' EXIT
{ git ls-files --cached --others --exclude-standard -z; find "$old" -type f -print0; } | sort -zu > "$tmp/files"
: > "$tmp/refs"
while IFS= read -r -d '' file; do
  [[ -f "$file" && ! -L "$file" ]] || continue
  if grep -Iq . "$file" && grep -Fq -- "$old" "$file"; then printf '%s\0' "$file" >> "$tmp/refs"; fi
done < "$tmp/files"
printf 'Move %s -> %s\nUpdate literal references in:\n' "$old" "$new"
while IFS= read -r -d '' file; do printf '  %s\n' "$file"; done < "$tmp/refs"
[[ "$apply" == true ]] || { printf 'Preview only; add --apply after reviewing.\n'; exit 0; }
backup=$(git rev-parse --git-path "afk-workflow/migrations/$(date -u +%Y%m%dT%H%M%SZ)-$$")
mkdir -p "$backup/references" "$(dirname "$new")"
backup=$(cd "$backup" && pwd -P)
cp -a -- "$old" "$backup/tree"
diff -qr -- "$old" "$backup/tree" >/dev/null || { printf 'Backup verification failed.\n' >&2; exit 1; }
while IFS= read -r -d '' file; do
  mkdir -p "$backup/references/$(dirname "$file")"
  cp -p -- "$file" "$backup/references/$file"
done < "$tmp/refs"
mv -- "$old" "$new"
while IFS= read -r -d '' file; do
  case "$file" in "$old/"*) file="$new/${file#"$old/"}";; esac
  awk -v old="$old" -v new="$new" '{line=$0; out=""; while((pos=index(line,old))>0) {prefix=substr(line,1,pos-1); previous=substr(prefix,length(prefix),1); replacement=(previous ~ /[[:alnum:]_.-]/ ? old : new); out=out prefix replacement; line=substr(line,pos+length(old))} print out line}' "$file" > "$tmp/replace"
  cat "$tmp/replace" > "$file"
  if ! cmp -s -- "$tmp/replace" "$file"; then printf 'Reference verification failed: %s. Backup: %s\n' "$file" "$backup" >&2; exit 1; fi
done < "$tmp/refs"
if [[ -f "$new/config/workflow.json" ]]; then
  jq --arg dir "./$to" '.assetsDir=$dir' "$new/config/workflow.json" > "$tmp/replace"
  cat "$tmp/replace" > "$new/config/workflow.json"
fi
printf 'Moved successfully. Recovery copy: %s\nReview git diff and git check-ignore before committing.\n' "$backup"
