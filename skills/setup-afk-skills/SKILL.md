---
name: setup-afk-skills
description: Sets up an `## Agent skills` block in AGENTS.md/CLAUDE.md and `docs/afk-workflow/config/` so the engineering skills know this repo's issue tracker (GitHub or local markdown), triage label vocabulary, and domain doc layout, and copies the night-shift runner scripts into `docs/afk-workflow/scripts/`. Run before first use of `to-issues`, `to-prd`, `triage`, `diagnose`, `tdd`, `improve-codebase-architecture`, or `zoom-out` — or if those skills appear to be missing context about the issue tracker, triage labels, or domain docs.
disable-model-invocation: true
---

# Set up AFK workflow skills

Scaffold the per-repo configuration that the engineering skills assume:

- **Issue tracker** — where issues live (GitHub by default; local markdown is also supported out of the box)
- **Triage labels** — the strings used for the five canonical triage roles
- **Domain docs** — where `CONTEXT.md` and ADRs live, and the consumer rules for reading them

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## Process

### 1. Explore

Look at the current repo to understand its starting state. Read whatever exists; don't assume:

- `git remote -v` and `.git/config` — is this a GitHub repo? Which one?
- `AGENTS.md` and `CLAUDE.md` at the repo root — does either exist? Is there already an `## Agent skills` section in either?
- `docs/afk-workflow/context/CONTEXT.md` and `docs/afk-workflow/context/CONTEXT-MAP.md`
- `docs/afk-workflow/adr/` and any `src/*/docs/adr/` directories (multi-context)
- `docs/afk-workflow/config/` — does this skill's prior output already exist?
- `docs/afk-workflow/backlog/` — sign that a local-markdown issue tracker convention is already in use

### 2. Present findings and ask

Summarise what's present and what's missing. Then walk the user through the three decisions **one at a time** — present a section, get the user's answer, then move to the next. Don't dump all three at once.

Assume the user does not know what these terms mean. Each section starts with a short explainer (what it is, why these skills need it, what changes if they pick differently). Then show the choices and the default.

**Section A — Issue tracker.**

> Explainer: The "issue tracker" is where issues live for this repo. Skills like `to-issues`, `triage`, `to-prd`, and `qa` read from and write to it — they need to know whether to call `gh issue create`, write a markdown file under `docs/afk-workflow/backlog/`, or follow some other workflow you describe. Pick the place you actually track work for this repo.

Default posture: these skills were designed for GitHub. If a `git remote` points at GitHub, propose that. If a `git remote` points at GitLab (`gitlab.com` or a self-hosted host), propose GitLab. Otherwise (or if the user prefers), offer:

- **GitHub** — issues live in the repo's GitHub Issues (uses the `gh` CLI)
- **GitLab** — issues live in the repo's GitLab Issues (uses the [`glab`](https://gitlab.com/gitlab-org/cli) CLI)
- **Local markdown** — issues live as files under `docs/afk-workflow/backlog/<feature>/` in this repo (good for solo projects or repos without a remote)
- **Other** (Jira, Linear, etc.) — ask the user to describe the workflow in one paragraph; the skill will record it as freeform prose

**Section B — Triage label vocabulary.**

> Explainer: When the `triage` skill processes an incoming issue, it moves it through a state machine — needs evaluation, waiting on reporter, ready for an AFK agent to pick up, ready for a human, or won't fix. To do that, it needs to apply labels (or the equivalent in your issue tracker) that match strings *you've actually configured*. If your repo already uses different label names (e.g. `bug:triage` instead of `needs-triage`), map them here so the skill applies the right ones instead of creating duplicates.

The five canonical roles:

- `needs-triage` — maintainer needs to evaluate
- `needs-info` — waiting on reporter
- `ready-for-agent` — fully specified, AFK-ready (an agent can pick it up with no human context)
- `ready-for-human` — needs human implementation
- `wontfix` — will not be actioned

Default: each role's string equals its name. Ask the user if they want to override any. If their issue tracker has no existing labels, the defaults are fine.

**Section C — Domain docs.**

> Explainer: Some skills (`improve-codebase-architecture`, `diagnose`, `tdd`) read `docs/afk-workflow/context/CONTEXT.md` to learn the project's domain language, and `docs/afk-workflow/adr/` for past architectural decisions. They need to know whether the repo has one global context or multiple (e.g. a monorepo with separate frontend/backend contexts) so they look in the right place.

Confirm the layout:

- **Single-context** — one `docs/afk-workflow/context/CONTEXT.md` + `docs/afk-workflow/adr/`. Most repos are this.
- **Multi-context** — `docs/afk-workflow/context/CONTEXT-MAP.md` pointing to per-context `src/<context>/CONTEXT.md` files (typically a monorepo).

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` block to add to whichever of `CLAUDE.md` / `AGENTS.md` is being edited (see step 4 for selection rules)
- The contents of `docs/afk-workflow/config/issue-tracker.md`, `docs/afk-workflow/config/triage-labels.md`, `docs/afk-workflow/config/domain.md`

Let them edit before writing.

### 4. Write

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, ask the user which one to create — don't pick for them.

Never create `AGENTS.md` when `CLAUDE.md` already exists (or vice versa) — always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

The block:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/afk-workflow/config/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/afk-workflow/config/triage-labels.md`.

### Domain docs

[one-line summary of layout — "single-context" or "multi-context"]. See `docs/afk-workflow/config/domain.md`.
```

Then write the three docs files using the seed templates in this skill folder as a starting point:

- [issue-tracker-github.md](./issue-tracker-github.md) — GitHub issue tracker
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md) — GitLab issue tracker
- [issue-tracker-local.md](./issue-tracker-local.md) — local-markdown issue tracker
- [triage-labels.md](./triage-labels.md) — label mapping
- [domain.md](./domain.md) — domain doc consumer rules + layout

For "other" issue trackers, write `docs/afk-workflow/config/issue-tracker.md` from scratch using the user's description.

### 5. Install the runner scripts

Copy the night-shift runners out of this plugin into the repo so the loop can be
launched from the project root with a short, root-relative path
(`bash docs/afk-workflow/scripts/afk.sh N`) -- no absolute plugin path, no global
shortcut -- and so they sit alongside the repo's other workflow files (subject to
the repo's `.gitignore`; see the note below).

Resolve the plugin's `scripts/` directory, trying these in order:

1. `$CLAUDE_PLUGIN_ROOT/scripts` if `$CLAUDE_PLUGIN_ROOT` is set.
2. `~/.claude/plugins/marketplaces/afk-workflow/scripts` (the default install location).
3. As a last resort: `find ~/.claude/plugins -path '*afk-workflow*/scripts/afk.sh'` and use the directory it reports.

Then copy the three runners into `docs/afk-workflow/scripts/`, creating the
directory if needed, **always overwriting** so re-running this skill refreshes
them to the installed plugin version:

```bash
SRC="<resolved scripts dir>"
mkdir -p docs/afk-workflow/scripts
cp "$SRC/once.sh" "$SRC/afk.sh" "$SRC/prompt.md" docs/afk-workflow/scripts/
```

Then tell the user:

- These files belong to the repo's single removable `docs/afk-workflow/` footprint. They're meant to be **committed** so they travel with the branch -- but **check the repo's `.gitignore` first**: if it excludes `docs/` or `docs/afk-workflow/` (some repos ignore all of `docs/`), the runners (and your issue files) stay **local-only**. That's fine for running the loop on this machine; if you want them tracked and shared, `git add -f docs/afk-workflow/scripts/*` or add a `!docs/afk-workflow/` negation rule.
- Launch from the project root: `bash docs/afk-workflow/scripts/afk.sh 10` (the loop) or `bash docs/afk-workflow/scripts/once.sh` (a single smoke-test iteration).
- If the issue tracker is **GitHub or GitLab** (not local markdown), open the copied `afk.sh` + `once.sh` and swap the `issues=$(cat ...)` line for `gh issue list ...` / `glab issue list ...`, as the script comments describe. For local markdown, no edits are needed.

### 6. Done

Tell the user the setup is complete and which engineering skills will now read from these files. Mention they can edit `docs/afk-workflow/config/*.md` directly later, and re-run this skill to refresh the runner scripts or switch issue trackers.
