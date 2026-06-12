# ISSUES

Issue files are provided at the start of context as concatenated markdown from the project's local issue directory (by default `docs/afk-workflow/backlog/<feature>/issues/*.md`). Parse it to get the open issues with their bodies and any inline comments. If this project uses a GitHub/GitLab tracker instead, the issues will have been passed in from `gh issue list` / `glab issue list`.

You will work on the AFK issues only -- those whose `Status:` line is `ready-for-agent`. Skip any issue in any other canonical state: `needs-triage`, `needs-info`, `ready-for-human`, `wontfix`, or `done`. The full canonical vocabulary lives in `docs/afk-workflow/config/triage-labels.md`.

You've also been passed the last few commits. Review these to understand what work has been done.

If all AFK tasks are complete, output <promise>NO MORE TASKS</promise>.

# TASK SELECTION

Pick the next task. Prioritize tasks in this order:

1. Critical bugfixes
2. Development infrastructure

Getting development infrastructure like tests and types and dev scripts ready is an important precursor to building features.

3. Tracer bullets for new features

Tracer bullets are small slices of functionality that go through all layers of the system, allowing you to test and validate your approach early. This helps in identifying potential issues and ensures that the overall architecture is sound before investing significant time in development.

TL;DR -- build a tiny, end-to-end slice of the feature first, then expand it out.

4. Polish and quick wins
5. Refactors

# EXPLORATION

Explore the repo. See `CLAUDE.md` / `AGENTS.md` for architecture, conventions, and the project's design-system primitives and shared utilities before writing new code.

# IMPLEMENTATION

Use the `/tdd` skill (red-green-refactor). The skill enforces:

## RED: Write a single failing test

## GREEN: Write the minimal implementation

## RED: Write another failing test

Repeat until implementation is complete.

# FEEDBACK LOOPS

Before committing, run the project's full pre-commit gate. Find it in `CLAUDE.md` / `AGENTS.md`, the `scripts` block of `package.json`, or the project's CI config. A typical gate is:

- type check (e.g. `tsc --noEmit`)
- lint (e.g. `eslint` / `biome`)
- unit tests (e.g. `vitest run` / `jest`)
- build (e.g. `next build`)

All gate steps must pass. If any fail, fix or revert before committing.

# COMMIT

Make a git commit. The commit message must:

1. Include key decisions made
2. Include files changed
3. Blockers or notes for next iteration

Follow the project's commit conventions (check `CLAUDE.md` / `AGENTS.md` for attribution rules before adding any Co-Authored-By or "Generated with" footers).

# THE ISSUE FILE

Always update the issue file's `Status:` line and append a `## Progress` note (with a date stamp) describing what was done, what remains, and any blockers. The canonical vocabulary lives in `docs/afk-workflow/config/triage-labels.md`. Pick the status that best matches the outcome:

**You may set:**

- `done` -- task fully complete, all feedback loops green, committed. Nothing left.
- `ready-for-human` -- agent-doable work is finished, but a human must take it from here. Use this when:
  - design / UX / copy decisions need eyeball review before merge
  - a judgment call was made between two valid approaches and confirmation is wanted
  - the remaining work is human-only (stakeholder sign-off, manual QA on a device, production cutover authorization)
  - the agent hit something it cannot resolve: failing test requiring an architectural decision, missing API access, external dependency, environment / credentials it doesn't have
  - the agent thinks the issue is invalid or a duplicate (do NOT set `wontfix` yourself; escalate via `ready-for-human` with a Progress note explaining why and let the human decide)
- `ready-for-agent` -- partial work; the next loop iteration can pick this up and continue without human input. Use sparingly -- prefer to finish in one iteration.
- `needs-info` -- blocked on missing requirements, ambiguous spec, or a clarifying question that only a human can answer.

**You must NEVER set:**

- `needs-triage` -- entry state for un-evaluated issues. The agent only picks up already-triaged work; pushing back to triage is out of scope.
- `wontfix` -- maintainer judgment call. If you believe an issue should be `wontfix`, use `ready-for-human` and explain in the Progress note.

The `<promise>NO MORE TASKS</promise>` sentinel should only fire when zero issues remain in `ready-for-agent` state. Issues in any other state (`ready-for-human`, `needs-info`, `done`, `wontfix`, `needs-triage`) do not block the sentinel.

# FINAL RULES

ONLY WORK ON A SINGLE TASK.
