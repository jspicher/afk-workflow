#!/usr/bin/env bash
set -euo pipefail
SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=lib/install.sh
source "$SOURCE/scripts/lib/install.sh"
TARGET=${1:-.}
[[ -d "$SOURCE/skills" ]] || { printf 'Run the installer from an AFK Workflow source checkout.\n' >&2; exit 1; }
TARGET=$(cd "$TARGET" && git rev-parse --show-toplevel)
cd "$TARGET"
manifest="$TARGET/.agents/afk-workflow-installed.json"
sync_preview "$SOURCE/skills" "$TARGET/.agents/skills" "$manifest"
runtime="$TARGET/.agents/skills/setup-afk-skills/assets/runtime"
runtime_manifest="$TARGET/.agents/afk-workflow-runtime.json"
sync_preview "$SOURCE/scripts" "$runtime" "$runtime_manifest"
if [[ ${2:-} != --apply ]]; then
  printf 'Preview: install project skills into %s/.agents/skills. Run again with --apply to write.\n' "$TARGET"; exit 0
fi
sync_apply "$SOURCE/skills" "$TARGET/.agents/skills" "$manifest"
sync_apply "$SOURCE/scripts" "$runtime" "$runtime_manifest"
# shellcheck disable=SC2016
printf 'Installed Codex skills v0.6.0. In a new Codex session run $setup-afk-skills.\n'
git check-ignore .agents/skills/setup-afk-skills/SKILL.md || true
