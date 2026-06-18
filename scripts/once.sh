#!/bin/bash
# Single AFK (Ralph) iteration -- runs ONE cycle of "pick the next
# ready-for-agent issue, implement it with /tdd, commit" non-interactively.
# Use this as a smoke test before launching the full afk.sh loop.
#
# Adapted from mattpocock/ai-hero-cli ralph/once.sh, with Windows-driven
# adaptations vs the Linux original:
#   1. Issues come from local markdown (cat <glob>) instead of `gh issue list`.
#   2. Prompt is fed via stdin (here-string) and runs with
#      --dangerously-skip-permissions instead of --permission-mode acceptEdits,
#      because combined issue bodies + commit log + prompt routinely exceed
#      Windows' ~32 KB CreateProcess argv limit. Stdin avoids the cap but
#      forecloses interactive permission prompts.
#
# Run from your PROJECT ROOT (so docs/afk-workflow/ and git history resolve correctly).
#
# Usage: /path/to/once.sh [issues_glob]
#   issues_glob  optional; defaults to "docs/afk-workflow/backlog/*/issues/*.md"
#                (the local-markdown convention from setup-afk-skills).
#                For GitHub/GitLab trackers, swap the `issues=` line below for
#                `gh issue list ...` / `glab issue list ...`.
#
# Requires: jq (Git Bash ships it) -- renders claude's stream-json output.

set -uo pipefail

# Resolve this script's own dir so prompt.md is found regardless of CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If invoked from WSL (e.g. via PowerShell where bash.exe resolves to the WSL
# launcher first), re-exec under Git Bash. Windows-side claude/gh/git auth
# works; WSL's libsecret/DBus keyring is broken on default WSL2 setups and
# breaks `gh auth git-credential`, which blocks git push during AFK runs.
# Skip if already in Git Bash (MSYSTEM is set inside MSYS2 / MINGW64).
if [ -n "${WSL_DISTRO_NAME:-}" ] && [ -z "${MSYSTEM:-}" ]; then
  GITBASH="/mnt/c/Program Files/Git/bin/bash.exe"
  if [ ! -x "$GITBASH" ]; then
    echo "Error: Detected WSL ($WSL_DISTRO_NAME) but Git Bash not found at $GITBASH" >&2
    echo "Install Git for Windows or invoke this script from Git Bash directly." >&2
    exit 1
  fi
  exec "$GITBASH" "$(wslpath -w "$0")" "$@"
fi

# Non-interactive bash (e.g. invoked from PowerShell) doesn't source ~/.bashrc,
# so the claude binary at ~/.local/bin may not be on PATH. Add it explicitly.
export PATH="$HOME/.local/bin:$PATH"

# Disable the Honcho memory plugin for this headless run. The Honcho SessionEnd
# hook attempts a blocking bulk flush to api.honcho.dev as `claude -p` exits; the
# parent tears down first, so the hook is killed ("SessionEnd hook ... failed:
# Hook cancelled") before it can mark the queue uploaded, leaving stale messages
# to be re-sent (and rate-limited) on the next run. Interactive capture is
# unaffected. Remove to re-enable.
export HONCHO_ENABLED=false

ISSUES_GLOB="${1:-docs/afk-workflow/backlog/*/issues/*.md}"

issues=$(cat $ISSUES_GLOB 2>/dev/null || echo "No issues found")
commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
prompt=$(cat "$SCRIPT_DIR/prompt.md")

# jq filter: pull the assistant's text out of the stream-json events.
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

# --print + --output-format stream-json run claude HEADLESS (one turn, then
# exit) and stream its output. WITHOUT --print, bare `claude` tries to launch
# the interactive TUI, which can't render over a piped stdin -- it hangs with a
# blank screen and never commits. --verbose surfaces tool activity in the stream.
claude \
  --dangerously-skip-permissions \
  --verbose \
  --print \
  --output-format stream-json \
  <<< "Previous commits: $commits
$issues
$prompt" \
| grep --line-buffered '^{' \
| jq --unbuffered -rj "$stream_text"
