# afk-workflow

A portable Claude Code **marketplace plugin** that packages Matt Pocock's
"real engineer's" agentic workflow -- grill → PRD → vertical-slice issues →
triage → TDD -- plus a headless **Ralph** AFK (Away-From-Keyboard) loop, so you
can drop the whole pipeline into any repo with one install.

It bundles **13 skills**, two terminal runner scripts (`once.sh` / `afk.sh`),
an in-session `/afk` command, and a per-repo `setup` skill that teaches the
skills where your issues, triage labels, and domain docs live.

> Credit: the skills are derived from [`mattpocock/skills`](https://github.com/mattpocock/skills)
> and the runner scripts from `mattpocock/ai-hero-cli`, both MIT. This repo
> adapts them for cross-repo reuse with Windows-specific runner fixes and
> **vendors them into this plugin** -- there is nothing to install from those
> upstream repos.

---

## The workflow

Pocock splits the work into a human **day shift** (planning) and an autonomous
**night shift** (AFK implementation). Solid arrows are the **required** path;
dashed branches are **optional** helpers you reach for when you need them.

```mermaid
flowchart TD
    A([New repo]) ==> B["/setup-afk-skills<br/>scaffold docs/afk-workflow/ config + CLAUDE.md block"]

    B ==> C{{"DAY SHIFT - plan with a human"}}

    C -. optional .-> D["/grill-me or /grill-with-docs<br/>stress-test the plan; write CONTEXT.md + ADRs"]
    C -. optional .-> E["/to-prd<br/>turn the conversation into a PRD"]
    C -. report bugs .-> F["/qa<br/>conversational bug intake, files issues"]
    D -.-> G
    E -.-> G
    C ==> G["/to-issues<br/>plan or PRD into vertical-slice issues"]
    F -.-> H
    G ==> H["/triage<br/>label the board, move issues to ready-for-agent"]

    H ==> I{{"NIGHT SHIFT - AFK implementation"}}
    I ==> J["scripts/afk.sh N (terminal loop)<br/>or /afk (one in-session pass) or scripts/once.sh (smoke test)"]
    J ==> K["each iteration: pick a ready-for-agent issue,<br/>/tdd, pre-commit gate, commit, update Status"]
    K -. hard bug .-> L["/diagnose"]
    K -. refactor or reset .-> M["/improve-codebase-architecture<br/>/zoom-out, /caveman"]
    L -.-> K
    M -.-> K
    K ==> N{"&lt;promise&gt;NO MORE TASKS&lt;/promise&gt;<br/>or iteration cap reached?"}
    N -. not yet .-> K
    N == done ==> O["YOU: QA, impose taste, queue new issues"]
    O -. next cycle .-> C

    classDef req fill:#1f6feb,stroke:#0b3d91,color:#ffffff;
    classDef opt fill:#ffffff,stroke:#9aa0a6,stroke-dasharray:5 5,color:#202124;
    class B,G,H,J,K,O req;
    class D,E,F,L,M opt;
```

### Commands, in order

| # | Step | Command | Required? | Run in |
|---|---|---|---|---|
| 1 | Set up the repo (once) | `/setup-afk-skills` | **Required** | **Fresh** -- once per repo |
| 2 | Stress-test the plan | `/grill-me` or `/grill-with-docs` | Optional | **Fresh** -- starts the planning session |
| 3 | Write a PRD | `/to-prd` | Optional | **Same session** -- synthesizes the grill |
| 4 | Create the backlog | `/to-issues` | **Required** \* | **Either** -- same session, or fresh from the saved PRD |
| - | (alt) File bugs conversationally | `/qa` | Optional | **Fresh** -- starts a QA session |
| 5 | Label the board | `/triage` (to `ready-for-agent`) | **Required** | **Fresh** -- reads the board; resumable |
| 6 | Run the night shift | `docs/afk-workflow/scripts/afk.sh N` (or `/afk`, or `once.sh`) | **Required** | **Terminal** from repo root, fresh per iteration (or `/afk` in-session) |
| - | ...during build: a hard bug | `/diagnose` | Optional | **Either** -- fresh on a bug, or mid-build |
| - | ...during build: messy code | `/improve-codebase-architecture`, `/zoom-out`, `/caveman` | Optional | **Same session** -- acts on current work |
| 7 | Re-enter the loop | you: QA, queue new issues, repeat | -- | -- |

\* You need *some* issues in `ready-for-agent` state before the loop does
anything. Get them there with `/to-issues` (from a plan/PRD), `/qa` (from bug
reports), or by hand-writing files under `docs/afk-workflow/backlog/<feature>/issues/`.
Step 6's loop runs `/tdd` on each issue automatically -- you don't invoke it directly.

### Fresh session vs. continue?

The single rule: **start a fresh session** for anything that begins a new thread
(`/grill-me`, `/grill-with-docs`, `/qa`) or reads only durable state -- files or
the issue tracker (`/triage`, `/to-issues` from a saved `PRD.md`, the night-shift
scripts, `/setup-afk-skills`). **Continue in the same session** only for skills
that work off the live conversation you just had: `/to-prd` (synthesizes the
grill) and `/zoom-out` (maps the code you're already looking at). `/to-issues`
is the one that goes both ways -- same session if the plan lives only in the
current chat, fresh if you already saved a PRD with `/to-prd` (the cleaner path).
(`/caveman` is orthogonal -- an output-style toggle you can flip in any session.)
The night shift is fresh-by-design: every `afk.sh` iteration spawns a brand-new
`claude` whose only memory is the issue *files*.

### Step 6 -- the literal commands

`/setup-afk-skills` copies the runners into `docs/afk-workflow/scripts/`, so from
your **project root** (where the issue glob and `git log` resolve) it's just:

```bash
bash docs/afk-workflow/scripts/once.sh        # one iteration (smoke test)
bash docs/afk-workflow/scripts/afk.sh 20      # the loop, up to 20 iterations
```

`/afk` is the in-session equivalent of a single iteration -- type it inside a
Claude Code session, no path needed.

## Install

This repo is a single-plugin marketplace. From any project (or globally):

```
/plugin marketplace add jspicher/afk-workflow
/plugin install afk-workflow@afk-workflow
```

Or point at a local clone during development:

```
/plugin marketplace add C:/path/to/afk-workflow
/plugin install afk-workflow@afk-workflow
```

**That single install is everything** -- all 13 skills (including the ones
derived from `mattpocock/skills`) are bundled inside this plugin, so they become
available immediately. You do **not** install `mattpocock/skills`, the
`ai-hero-cli`, or anything else separately.

The `once.sh` / `afk.sh` night-shift scripts are copied into your repo at
`docs/afk-workflow/scripts/` by `/setup-afk-skills`, then run from a terminal
(not as slash commands) -- see
[Runner scripts (the night shift)](#runner-scripts-the-night-shift----cli-usage)
for how to run them.

## First-time setup (per repo)

The engineering skills are **config-driven** -- they read `docs/afk-workflow/config/*.md`
in the consuming repo to learn your issue tracker, triage labels, and domain
doc layout. Run the setup skill once per repo before first use:

```
/setup-afk-skills
```

It walks you through three choices (issue tracker: GitHub / GitLab / local
markdown / other · triage label vocabulary · single- vs multi-context domain
docs), scaffolds an `## Agent skills` block in `CLAUDE.md`/`AGENTS.md` plus
`docs/afk-workflow/config/{issue-tracker,triage-labels,domain}.md`, and copies
the night-shift runner scripts into `docs/afk-workflow/scripts/` so you can launch
the loop from your project root.

## What it writes in a consuming repo

Everything the workflow creates or reads lives under a single, removable
`docs/afk-workflow/` directory -- plus one small pointer block in
`CLAUDE.md`/`AGENTS.md`:

```
docs/afk-workflow/
├── config/         # issue-tracker.md, triage-labels.md, domain.md  (from setup)
├── scripts/        # once.sh, afk.sh, prompt.md     (night-shift runners, from setup)
├── backlog/        # <feature>/PRD.md + <feature>/issues/NN-*.md     (to-prd, to-issues)
├── context/        # CONTEXT.md / CONTEXT-MAP.md   (domain glossary, grill-with-docs)
├── adr/            # 0001-*.md ...                 (architecture decision records)
└── out-of-scope/   # <concept>.md                 (rejected-feature records, triage)
```

To remove the workflow's footprint, delete `docs/afk-workflow/` and the
`## Agent skills` block from `CLAUDE.md`/`AGENTS.md`.

> **`.gitignore` note:** these files are meant to be committed so they travel
> with the branch. But **check your `.gitignore` first** -- some repos ignore all
> of `docs/` (e.g. a `/docs/*` rule), which silently excludes the runner scripts
> **and** your issue files. That's fine for running the loop locally (the scripts
> and `afk.sh`'s issue glob read from disk, not git), but if you want them tracked
> and shared, `git add -f docs/afk-workflow/...` or add a `!docs/afk-workflow/`
> negation rule.

> **Multi-context monorepos:** per-context `CONTEXT.md` + ADRs stay co-located
> with their `src/<context>/` code; only `CONTEXT-MAP.md` and system-wide ADRs
> live under `docs/afk-workflow/`.

## Skills

| Skill | Stage | Run in | What it does |
|---|---|---|---|
| `grill-me` | Plan | Fresh | Relentless one-question-at-a-time interview to reach shared understanding of a plan |
| `grill-with-docs` | Plan | Fresh | Same, but for an existing codebase -- writes `CONTEXT.md` + ADRs as decisions land |
| `to-prd` | Plan | Same session | Synthesizes the conversation into a Product Requirements Document |
| `to-issues` | Plan | Either | Breaks a PRD into independently-grabbable **vertical-slice** issues with DAG dependencies |
| `triage` | Plan | Fresh | State-machine triage; applies the canonical label vocabulary to the whole board |
| `qa` | Plan | Fresh | Interactive QA session -- user reports bugs conversationally; files durable, tracker-agnostic issues |
| `tdd` | Build | Auto (in loop) | Strict red-green-refactor loop (+ deep-modules / interface / mocking / refactoring refs) |
| `diagnose` | Build | Either | Disciplined bug/perf diagnosis loop: reproduce → minimise → hypothesise → instrument → fix → regression-test |
| `improve-codebase-architecture` | Build | Fresh or same | Ousterhout "deep module" refactoring, interface design, domain language |
| `zoom-out` | Build | Same session | Map an unfamiliar area of code one layer up (relevant modules + callers) |
| `caveman` | Build | Any (mode) | Ultra-terse output mode -- ~75% fewer tokens; stays on until you say "normal mode" |
| `write-a-skill` | Meta | Fresh | Author a new skill |
| `setup-afk-skills` | Setup | Fresh (once) | Scaffold the per-repo `docs/afk-workflow/config/*` config the other skills read |

## Runner scripts (the night shift) -- CLI usage

The night shift runs from a **normal terminal** (Git Bash on Windows), not from
inside a Claude Code session. Both scripts must be run **from your project root**
so `docs/afk-workflow/` and git history resolve, and both re-exec themselves out
of WSL automatically (WSL's keyring breaks `gh` push auth).

| Script | Signature | Purpose |
|---|---|---|
| `once.sh` | `once.sh [issues_glob]` | Run **one** Ralph iteration. Smoke test before committing to the loop. |
| `afk.sh` | `afk.sh <max_iterations> [issues_glob]` | Run the loop until the stop sentinel fires or the iteration cap is hit. |

In both, `issues_glob` is optional and defaults to
`docs/afk-workflow/backlog/*/issues/*.md` (the local-markdown convention from
`/setup-afk-skills`). For a GitHub/GitLab tracker, edit the `issues=`
line in the script to use `gh issue list` / `glab issue list`.

### Where they live

`/setup-afk-skills` copies `once.sh`, `afk.sh`, and `prompt.md` into your repo at
`docs/afk-workflow/scripts/`, so every example below uses that short,
root-relative path. (Haven't run setup, or want to run straight from the plugin?
Copy those three files out of the installed plugin -- typically
`~/.claude/plugins/marketplaces/afk-workflow/scripts/`, or run
`find ~/.claude/plugins -path '*afk-workflow*/scripts/afk.sh'` to locate them.)

### `once.sh` -- a single iteration (smoke test)

```bash
# default: every issue under docs/afk-workflow/backlog/*/issues/*.md
bash docs/afk-workflow/scripts/once.sh

# scope to one feature's backlog:
bash docs/afk-workflow/scripts/once.sh "docs/afk-workflow/backlog/checkout-redesign/issues/*.md"
```

It concatenates your open issues + the last 5 commits + `prompt.md`, pipes them
into `claude --dangerously-skip-permissions`, and the agent picks one
`ready-for-agent` issue, implements it with `/tdd`, runs your pre-commit gate,
commits, and updates that issue's `Status:`. Then it exits. No `jq` required --
this is the lightest way to confirm the plumbing works before you let the loop
run unattended.

### `afk.sh` -- the loop

`max_iterations` is **required** -- a hard cap so a runaway agent can't loop
forever. The optional second arg is the issues glob (same default as `once.sh`).

```bash
# up to 20 iterations over the default backlog glob
bash docs/afk-workflow/scripts/afk.sh 20

# 50 iterations, scoped to one feature
bash docs/afk-workflow/scripts/afk.sh 50 "docs/afk-workflow/backlog/checkout-redesign/issues/*.md"

# a single pass, but with the loop's stream-json output + sentinel check
bash docs/afk-workflow/scripts/afk.sh 1
```

Each iteration runs the same pick → `/tdd` → gate → commit → update-`Status:`
cycle as `once.sh`, but streams the agent's output as `stream-json` and inspects
the final result. The loop **stops early** the moment the agent emits
`<promise>NO MORE TASKS</promise>` (i.e. zero issues left in `ready-for-agent`);
otherwise it runs until `max_iterations`. Requires `jq` + `mktemp` (Git Bash
ships both).

> ⚠️ Both scripts run with `--dangerously-skip-permissions` -- the agent edits
> files, runs your gate, and commits with **no approval prompts**. **Run on a
> dedicated branch or a git worktree and keep `main`/`master` protected.**
> Pocock's original sandboxes each agent in Docker (his "Sand Castle" lib); this
> lighter setup trades that for branch isolation.

### End-to-end CLI example

```bash
# from your project root, on a throwaway branch
git switch -c afk/checkout-redesign
GLOB="docs/afk-workflow/backlog/checkout-redesign/issues/*.md"

# 1. smoke-test a single issue
bash docs/afk-workflow/scripts/once.sh "$GLOB"

# 2. happy with it? let it run the backlog down, up to 30 passes
bash docs/afk-workflow/scripts/afk.sh 30 "$GLOB"

# 3. review the commits the agent made
git log --oneline master..HEAD
```

**In-session alternative:** if you're already in a Claude Code session and want
to watch the agent work one task interactively, use the bundled `/afk` command
instead of these terminal scripts.

## Prerequisites

- **Claude Code CLI** on `PATH` (`claude`)
- **Git Bash** (Windows) -- ships `jq`, `mktemp`, `grep`
- A **test + type + build feedback loop** in the target repo (the agent codes
  blind without one)
- Issues created via `/to-issues` and labelled via `/triage` before launching
  the loop

## Layout

```
afk-workflow/
├── .claude-plugin/
│   ├── marketplace.json     # single-plugin marketplace manifest
│   └── plugin.json          # plugin manifest
├── skills/                  # 13 skills (verbatim Pocock + helpers)
├── commands/
│   └── afk.md               # /afk -- one in-session iteration
├── scripts/
│   ├── once.sh              # single headless iteration
│   ├── afk.sh               # the headless loop
│   └── prompt.md            # the Ralph task-selection prompt
└── docs/
    └── triage-labels.md     # canonical status vocabulary reference
```

## License

MIT. See [LICENSE](./LICENSE) and the attribution note within it.
