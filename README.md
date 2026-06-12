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
> adapts them for cross-repo reuse with Windows-specific runner fixes.

---

## The workflow

Pocock splits the work into a human **day shift** (planning) and an autonomous
**night shift** (AFK implementation). Solid arrows are the **required** path;
dashed branches are **optional** helpers you reach for when you need them.

```mermaid
flowchart TD
    A([New repo]) ==> B["/setup-matt-pocock-skills<br/>scaffold docs/afk-workflow/ config + CLAUDE.md block"]

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

| # | Step | Command | Required? |
|---|---|---|---|
| 1 | Set up the repo (once) | `/setup-matt-pocock-skills` | **Required** |
| 2 | Stress-test the plan | `/grill-me` or `/grill-with-docs` | Optional |
| 3 | Write a PRD | `/to-prd` | Optional |
| 4 | Create the backlog | `/to-issues` | **Required** \* |
| - | (alt) File bugs conversationally | `/qa` | Optional |
| 5 | Label the board | `/triage` (to `ready-for-agent`) | **Required** |
| 6 | Run the night shift | `scripts/afk.sh N` (or `/afk`, or `scripts/once.sh`) | **Required** |
| - | ...during build: a hard bug | `/diagnose` | Optional |
| - | ...during build: messy code | `/improve-codebase-architecture`, `/zoom-out`, `/caveman` | Optional |
| 7 | Re-enter the loop | you: QA, queue new issues, repeat | -- |

\* You need *some* issues in `ready-for-agent` state before the loop does
anything. Get them there with `/to-issues` (from a plan/PRD), `/qa` (from bug
reports), or by hand-writing files under `docs/afk-workflow/backlog/<feature>/issues/`.
Step 6's loop runs `/tdd` on each issue automatically -- you don't invoke it directly.

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

The skills become available immediately. The `once.sh` / `afk.sh` scripts live
under the installed plugin's `scripts/` dir (resolve it via the plugin path or
copy them into your project).

## First-time setup (per repo)

The engineering skills are **config-driven** -- they read `docs/afk-workflow/config/*.md`
in the consuming repo to learn your issue tracker, triage labels, and domain
doc layout. Run the setup skill once per repo before first use:

```
/setup-matt-pocock-skills
```

It walks you through three choices (issue tracker: GitHub / GitLab / local
markdown / other · triage label vocabulary · single- vs multi-context domain
docs) and scaffolds an `## Agent skills` block in `CLAUDE.md`/`AGENTS.md` plus
`docs/afk-workflow/config/{issue-tracker,triage-labels,domain}.md`.

## What it writes in a consuming repo

Everything the workflow creates or reads lives under a single, removable
`docs/afk-workflow/` directory -- plus one small pointer block in
`CLAUDE.md`/`AGENTS.md`:

```
docs/afk-workflow/
├── config/         # issue-tracker.md, triage-labels.md, domain.md  (from setup)
├── backlog/        # <feature>/PRD.md + <feature>/issues/NN-*.md     (to-prd, to-issues)
├── context/        # CONTEXT.md / CONTEXT-MAP.md   (domain glossary, grill-with-docs)
├── adr/            # 0001-*.md ...                 (architecture decision records)
└── out-of-scope/   # <concept>.md                 (rejected-feature records, triage)
```

To remove the workflow's footprint, delete `docs/afk-workflow/` and the
`## Agent skills` block from `CLAUDE.md`/`AGENTS.md`.

> **Multi-context monorepos:** per-context `CONTEXT.md` + ADRs stay co-located
> with their `src/<context>/` code; only `CONTEXT-MAP.md` and system-wide ADRs
> live under `docs/afk-workflow/`.

## Skills

| Skill | Stage | What it does |
|---|---|---|
| `grill-me` | Plan | Relentless one-question-at-a-time interview to reach shared understanding of a plan |
| `grill-with-docs` | Plan | Same, but for an existing codebase -- writes `CONTEXT.md` + ADRs as decisions land |
| `to-prd` | Plan | Synthesizes the conversation into a Product Requirements Document |
| `to-issues` | Plan | Breaks a PRD into independently-grabbable **vertical-slice** issues with DAG dependencies |
| `triage` | Plan | State-machine triage; applies the canonical label vocabulary to the whole board |
| `qa` | Plan | Interactive QA session — user reports bugs conversationally; files durable, tracker-agnostic issues |
| `tdd` | Build | Strict red-green-refactor loop (+ deep-modules / interface / mocking / refactoring refs) |
| `diagnose` | Build | Disciplined bug/perf diagnosis loop: reproduce → minimise → hypothesise → instrument → fix → regression-test |
| `improve-codebase-architecture` | Build | Ousterhout "deep module" refactoring, interface design, domain language |
| `zoom-out` | Build | Step back from the weeds to re-evaluate approach |
| `caveman` | Build | Dumb-it-down / simplify pass |
| `write-a-skill` | Meta | Author a new skill |
| `setup-matt-pocock-skills` | Setup | Scaffold the per-repo `docs/afk-workflow/config/*` config the other skills read |

## Runner scripts (the night shift)

Both run **from your project root** and require Git Bash on Windows (they
re-exec out of WSL automatically -- WSL's keyring breaks `gh` push auth).

**Single iteration (smoke test):**

```bash
bash /path/to/plugin/scripts/once.sh
# or target a specific feature's issues:
bash /path/to/plugin/scripts/once.sh "docs/afk-workflow/backlog/my-feature/issues/*.md"
```

**The AFK loop:**

```bash
bash /path/to/plugin/scripts/afk.sh 20                       # up to 20 iterations
bash /path/to/plugin/scripts/afk.sh 20 "docs/afk-workflow/backlog/my-feature/issues/*.md"
```

Each iteration concatenates your open issues + the last 5 commits + `prompt.md`,
pipes them into `claude --dangerously-skip-permissions`, and the agent picks the
next `ready-for-agent` issue, implements it with `/tdd`, runs your pre-commit
gate, commits, and updates the issue's `Status:`. The loop stops when the agent
emits `<promise>NO MORE TASKS</promise>` or hits the iteration cap.

> ⚠️ The loop runs with `--dangerously-skip-permissions`. **Use a dedicated
> branch or a git worktree and keep `main` protected.** Pocock's original
> sandboxes each agent in Docker (his "Sand Castle" lib); this lighter setup
> trades that for branch isolation.

**In-session alternative:** if you're already in a Claude Code session and want
to watch the agent work one task, use the bundled `/afk` command instead of the
terminal scripts.

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
