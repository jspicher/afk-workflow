---
description: Run one in-session AFK (Ralph) iteration -- pick the next ready-for-agent issue and implement it with TDD
argument-hint: "[issues-glob | issue-ref] (default docs/afk-workflow/backlog/*/issues/*.md)"
---

You are running one in-session AFK (Ralph) iteration. This is the interactive
equivalent of `scripts/once.sh` -- use it when you're already in a Claude Code
session and want the agent to grab and finish the next unblocked task, with you
able to watch and intervene.

## 1. Load the backlog

Read the open issues. If the user passed an argument, treat it as either a glob
of issue files or a single issue reference and load that. Otherwise default to
the local-markdown convention: read `docs/afk-workflow/backlog/*/issues/*.md`. If this
project uses a GitHub/GitLab tracker (see `docs/afk-workflow/config/issue-tracker.md`), list issues
from there instead.

Also review the last few commits (`git log -n 5`) to understand recent work.

## 2. Follow the Ralph loop

Follow the task-selection, implementation, feedback-loop, commit, and
issue-status rules defined in this plugin's `scripts/prompt.md`
(`${CLAUDE_PLUGIN_ROOT}/scripts/prompt.md`). In short:

- Work ONLY on issues whose `Status:` is `ready-for-agent`.
- Pick the single highest-priority unblocked task (critical bugfixes >
  dev infrastructure > tracer bullets > polish/quick wins > refactors).
- Implement it using the `/tdd` skill (red-green-refactor).
- Run the project's full pre-commit gate before committing. All steps must pass.
- Commit, then update the issue's `Status:` line and append a dated
  `## Progress` note.

## 3. Stop

Work on **a single task only**, then stop and report what you did. If no issue
is in `ready-for-agent` state, say so and output `<promise>NO MORE TASKS</promise>`.
