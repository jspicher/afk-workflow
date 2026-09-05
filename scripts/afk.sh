#!/usr/bin/env bash
set -euo pipefail
if [[ -n ${WSL_DISTRO_NAME:-} && -z ${MSYSTEM:-} ]]; then
  gitbash='/mnt/c/Program Files/Git/bin/bash.exe'
  [[ -x "$gitbash" ]] || { printf 'Install Git for Windows or use Git Bash.\n' >&2; exit 1; }
  exec "$gitbash" "$(wslpath -w "$0")" "$@"
fi
export PATH="$PATH:$HOME/.local/bin"
RUNTIME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
exec bash "$RUNTIME/run.sh" "$@"
