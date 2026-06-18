#!/bin/bash
# AFK loop -- repeatedly runs the Ralph cycle until the agent emits the
# <promise>NO MORE TASKS</promise> sentinel or max iterations is reached.
#
# Adapted from mattpocock/ai-hero-cli ralph/afk.sh. Differences from the
# Linux original:
#   1. Issues come from local markdown (cat <glob>) instead of `gh issue list`.
#   2. No `docker sandbox run claude` wrapper -- we use
#      --dangerously-skip-permissions directly. RUN ON A DEDICATED BRANCH OR
#      GIT WORKTREE; keep your main branch protected.
#   3. Prompt via stdin (here-string), not positional arg -- Windows
#      CreateProcess caps argv at ~32 KB and the combined context exceeds it.
#
# Run from your PROJECT ROOT.
#
# Usage: /path/to/afk.sh <max_iterations> [issues_glob]
#   max_iterations  required; hard cap on loop count
#   issues_glob     optional; defaults to "docs/afk-workflow/backlog/*/issues/*.md"
#
# Requires: jq, mktemp (Git Bash / WSL ship both).

# Resolve this script's own dir so prompt.md is found regardless of CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If invoked from WSL, re-exec under Git Bash (see once.sh for the why).
if [ -n "${WSL_DISTRO_NAME:-}" ] && [ -z "${MSYSTEM:-}" ]; then
  GITBASH="/mnt/c/Program Files/Git/bin/bash.exe"
  if [ ! -x "$GITBASH" ]; then
    echo "Error: Detected WSL ($WSL_DISTRO_NAME) but Git Bash not found at $GITBASH" >&2
    echo "Install Git for Windows or invoke this script from Git Bash directly." >&2
    exit 1
  fi
  exec "$GITBASH" "$(wslpath -w "$0")" "$@"
fi

# Non-interactive bash doesn't source ~/.bashrc; ensure claude is on PATH.
export PATH="$HOME/.local/bin:$PATH"

# Disable the Honcho memory plugin for this headless loop. Each iteration is a
# full `claude -p` session whose Honcho SessionEnd hook attempts a blocking bulk
# flush to api.honcho.dev; the parent process tears down first, so Claude Code
# kills the hook ("SessionEnd hook ... failed: Hook cancelled") before it can
# mark the queue uploaded. In a loop the queue never clears, so the same backlog
# is re-sent every iteration and trips Honcho's 600/min rate limit. Your
# interactive sessions' live capture is unaffected. Remove to re-enable.
export HONCHO_ENABLED=false

set -e

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <max_iterations> [issues_glob]"
  exit 1
fi

MAX_ITERATIONS=$1
ISSUES_GLOB="${2:-docs/afk-workflow/backlog/*/issues/*.md}"

# jq filter to extract streaming text from assistant messages
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
# jq filter to extract the final result
final_result='select(.type == "result").result // empty'

echo ""
echo "============================================"
echo "  Ralph AFK loop -- max $MAX_ITERATIONS iterations"
echo "  Issues glob: $ISSUES_GLOB"
echo "  Stop sentinel: <promise>NO MORE TASKS</promise>"
echo "============================================"
echo ""

for ((i=1; i<=MAX_ITERATIONS; i++)); do
  tmpfile=$(mktemp)
  # Single quotes so $tmpfile expands at trap-fire time, picking up the most
  # recent iteration's value rather than baking in the first (SC2064).
  trap 'rm -f "$tmpfile"' EXIT

  echo ""
  echo "============================================"
  echo "  Iteration $i of $MAX_ITERATIONS  ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo "============================================"
  echo ""

  issues=$(cat $ISSUES_GLOB 2>/dev/null || echo "No issues found")
  commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
  prompt=$(cat "$SCRIPT_DIR/prompt.md")

  # Prompt via stdin (here-string) to dodge Windows' ~32 KB argv cap.
  claude \
    --dangerously-skip-permissions \
    --verbose \
    --print \
    --output-format stream-json \
  <<< "Previous commits: $commits
$issues
$prompt" \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  echo ""
  echo "--- End iteration $i ---"

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo ""
    echo "============================================"
    echo "  Ralph complete after $i iteration(s)."
    echo "============================================"
    exit 0
  fi
done

echo ""
echo "============================================"
echo "  Iteration limit reached ($MAX_ITERATIONS)."
echo "  Sentinel not detected -- backlog may still have ready-for-agent issues."
echo "============================================"
