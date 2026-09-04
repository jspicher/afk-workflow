# Upstream sync analysis -- `mattpocock/skills`

**Date:** 2026-09-03
**Analyst:** Claude Opus 5 (session `016XzsADsUVB7RgPVxBn8u5P`)
**Status:** Research complete; plan not yet executed
**Our version at time of writing:** `afk-workflow` v0.5.0 (`a775bea`)
**Upstream version at time of writing:** `mattpocock-skills` v1.2.3 (`6654f6b`, 2026-08-24)

---

## Summary

`afk-workflow` forked `mattpocock/skills` at commit `ffb2fa6` (2026-06-12). Upstream
has landed **367 commits** since. Our customizations turn out to be almost entirely
mechanical (path and name rewrites), which means a re-sync is a *replay* rather than
a merge conflict.

The runner scripts (`afk.sh` / `once.sh` / `prompt.md`) have **no upstream updates**
to pull -- their true origin, `mattpocock/ai-hero-cli`'s `ralph/` directory, has been
frozen since 2026-03-11 and ours is substantially ahead of it.

Recommended: a Tier 1 re-sync pass (upstream content + replayed substitutions, which
also clears our 185 em-dashes), then selective Tier 2 adoption of `code-review` and
`implement`. Target release: **v0.6.0**.

---

## 1. Method

Everything below is reproducible:

```bash
# Upstream, full history
git clone https://github.com/mattpocock/skills.git mp-skills

# Our fork point: last upstream commit before our initial commit (2026-06-12 08:36 -0400)
FORK=ffb2fa662321045a8ace6f56f29ef8af11e19d3d
git -C mp-skills log -1 --format='%ci %s' $FORK
#   2026-06-12 09:25:19 +0100  feat: Add implement skill documentation for PRD-based work

# What upstream changed since
git -C mp-skills diff --stat -M $FORK HEAD -- skills/

# What WE changed relative to the fork point
git -C mp-skills archive $FORK | tar -x -C forkpoint/
diff -ru forkpoint/skills/engineering/triage skills/triage    # etc.

# Runner-script origin
git clone --depth 50 https://github.com/mattpocock/ai-hero-cli.git
git -C ai-hero-cli log --format='%ci %h %s' -- ralph/
#   2026-03-11 12:19:32 +0000  cd46745  (last touch -- predates our fork)
```

---

## 2. Divergence inventory

### 2.1 What we changed (measured against fork-point originals)

| Our skill | Upstream counterpart at fork point | Changed lines | Nature of our change |
|---|---|---:|---|
| `tdd` | `engineering/tdd` | 2 | rename only |
| `zoom-out` | `engineering/zoom-out` | 2 | rename only |
| `write-a-skill` | `productivity/write-a-skill` | 3 | rename only |
| `diagnose` | `engineering/diagnosing-bugs` | 6 | rename only |
| `grill-me` | `productivity/grill-me` | 7 | rename only |
| `to-issues` | `engineering/to-issues` | 12 | HITL/AFK slice tagging, paths |
| `to-prd` | `engineering/to-prd` | 13 | paths |
| `improve-codebase-architecture` | same | 28 | `docs/afk-workflow/*` paths; swapped `HTML-REPORT.md` for `DEEPENING.md` / `INTERFACE-DESIGN.md` / `LANGUAGE.md` |
| `triage` | `engineering/triage` | 29 | `docs/afk-workflow/out-of-scope/`, `/setup-afk-skills`, `/grill-with-docs` in place of `/grilling`+`/domain-modeling` |
| `grill-with-docs` | `engineering/grill-with-docs` | 57 | inlined `grilling` + `domain-modeling` (we never took those skills); added `ADR-FORMAT.md` / `CONTEXT-FORMAT.md` |
| `setup-afk-skills` | `engineering/setup-matt-pocock-skills` | 71 | rename, `docs/afk-workflow/config/` paths, runner-script vendoring step (step 5) |
| `qa` | `deprecated/qa` | 109 | genuinely ours -- upstream had already deprecated `qa` before we forked |
| `caveman` | (removed upstream in `7d3ada9`) | n/a | ours by inheritance; Matt deleted it |
| `to-prs` | (does not exist upstream) | n/a | entirely ours (`f1f74c3`) |

**The substitution set that reproduces nearly all of it:**

| Upstream | Ours |
|---|---|
| `docs/agents/` | `docs/afk-workflow/config/` |
| `.scratch/<feature>/` | `docs/afk-workflow/backlog/<feature>/` |
| `.out-of-scope/` | `docs/afk-workflow/out-of-scope/` |
| root `CONTEXT.md` | `docs/afk-workflow/context/CONTEXT.md` |
| `docs/adr/` | `docs/afk-workflow/adr/` |
| `setup-matt-pocock-skills` | `setup-afk-skills` |
| `diagnosing-bugs` | `diagnose` |
| `/grilling` + `/domain-modeling` | `/grill-with-docs` (we inline both) |

### 2.2 Upstream skill inventory: fork point vs. now

Renamed:

| At fork point | Now | Notes |
|---|---|---|
| `to-prd` | `to-spec` | rename + prose polish only |
| `to-issues` | `to-tickets` | **substantive rewrite**, see 4.1 |
| `zoom-out` | `wayfinder` | **not a rename in substance** -- see "Skip" |
| `write-a-skill` | `writing-for-agents` | broadened scope, split out `SKILL-MECHANICS.md`, now model-invoked |
| `in-progress/review` | `engineering/code-review` | graduated + rewritten |

Added since our fork: `ask-matt`, `code-review`, `research`, `wizard`, `wayfinder`,
`to-questionnaire`, `wait-what`, plus in-progress `claude-handoff`, `implement-spec`,
`loop-me`, `retro`, `setup-ts-deep-modules`.

Removed since our fork: `deprecated/*` (incl. `qa`), `personal/*`, `tdd/refactoring.md`.

---

## 3. Runner scripts: nothing to pull

`afk.sh`, `once.sh` and `prompt.md` did **not** come from `mattpocock/skills`. They
come from `mattpocock/ai-hero-cli`, directory `ralph/`.

- Last upstream commit touching `ralph/`: **2026-03-11** (`cd46745`), three months
  before our fork.
- Upstream `once.sh` is still the 8-line original: `gh issue list` -> `claude
  --permission-mode acceptEdits "<positional prompt>"`.
- Upstream `afk.sh` still wraps in `docker sandbox run claude`.

Ours adds, on top of that baseline:

1. local-markdown issue glob instead of `gh issue list`
2. Git Bash re-exec when invoked under WSL (WSL keyring breaks `gh auth git-credential`)
3. `PATH` fix for non-interactive bash (`~/.local/bin`)
4. prompt via stdin here-string (Windows `CreateProcess` caps argv at ~32 KB)
5. `--print --output-format stream-json` (bare `claude` hangs on piped stdin)
6. `export HONCHO_ENABLED=false` (blocking `SessionEnd` flush killed mid-teardown)
7. sentinel reporting, iteration banners, SC2064-correct trap
8. a much longer `prompt.md`: canonical `Status:` vocabulary, allowed/forbidden
   status transitions, `/tdd` invocation, project pre-commit gate discovery

**Conclusion: no backport. Our runners are strictly ahead.**

---

## 4. What to pull

### Tier 1 -- upgrades to skills we already ship

#### 4.1 `to-issues` -> `to-tickets` (highest value)

Upstream replaced the linear breakdown with a **dependency DAG**:

- Every ticket declares its **blocking edges**; work proceeds at the **frontier**
  (any ticket whose blockers are all closed).
- On a real tracker the edges become **native blocking links** (GitHub issue
  dependencies / GitLab `/blocked_by`), so the tracker UI renders the frontier.
- Local markdown: strictly **one file per ticket** under
  `.scratch/<feature>/issues/<NN>-<slug>.md`, never a combined `tickets.md`.
- New: **wide-refactor expand -> migrate -> contract sequencing.** A mechanical change
  whose blast radius spans the codebase cannot land as a green vertical slice, so it
  is sequenced: expand (add new form beside old), migrate call sites in batches sized
  by blast radius (one ticket each, blocked by the expand), contract (delete old form,
  blocked by every batch). Where batches cannot stay green alone, they share an
  integration branch that blocks a final integrate-and-verify ticket.

**Why it matters to us:** `/to-prs` currently has to *infer* ordering from prose.
Explicit blocking edges make PR partitioning deterministic.

**Our bit to preserve:** the HITL/AFK slice tagging in step 4. Upstream has no
equivalent; it is what drives our night shift's skip logic.

#### 4.2 `tdd`

Rewritten (106 lines changed, mostly deletions -- it got *shorter and sharper*):

- Reorganized around **seams**: "a seam is the public boundary you test at."
  **Test only at pre-agreed seams** -- write down the seams under test and confirm
  them with the user *before writing any test*. No test at an unconfirmed seam.
- New anti-pattern: **tautological tests** -- the assertion recomputes the expected
  value the way the code does, so it passes by construction and can never disagree
  with the code. Worked before/after example added to `tests.md`.
- `refactoring.md` deleted; `deep-modules.md` / `interface-design.md` content moved
  into the new `codebase-design` skill. We still carry all three under `tdd/` and
  `improve-codebase-architecture/`.

#### 4.3 `triage`

- **Redundancy check** added to step 1: search for an existing implementation *by
  domain concept, not by the request's wording*, and report where you looked.
- `wontfix` split into two outcomes:
  - **already implemented** -- point at where it lives, and do **NOT** write to
    `.out-of-scope/` (that KB is for *rejected* requests, not built ones)
  - **rejected** -- existing behaviour (polite close for bugs; `.out-of-scope/` entry
    for enhancements)
- Step 3 generalized from "Reproduce (bugs only)" to **"Verify the claim"**.
- **PRs as a triage surface** (opt-in flag in the tracker config, default off):
  a PR is an issue with attached code, same roles and states. Includes an
  external-author filter so a collaborator's in-flight PR is not triage work, and a
  worked "Good agent brief (PR)" example in `AGENT-BRIEF.md`.

#### 4.4 `setup-matt-pocock-skills` -> our `setup-afk-skills`

Materially less interrogation:

- Section B (triage labels) is **skipped entirely** if the `triage` skill is not
  installed; when it is, it is one recommended-yes question instead of an override
  interrogation.
- Section C (domain docs) **defaults to single-context without asking**; multi-context
  is offered only when monorepo signals are found (`pnpm-workspace.yaml`, a
  `workspaces` field, a populated `packages/*` with its own `src/`).
- Lead each section with the recommended answer so it can be accepted in one word.
- Tracker templates gained a **"PRs as a request surface"** flag (default off) and a
  **"Wayfinding operations"** section.
- `PRD.md` -> `spec.md` throughout.

**Our bit to preserve:** step 5, which vendors the runner scripts into
`docs/afk-workflow/scripts/`.

#### 4.5 `diagnosing-bugs` -> our `diagnose`

**Secret redaction** throughout. The skill has the agent show commands, outputs and
captured artifacts; redaction becomes the first move on each -- write `<REDACTED>`,
build loops against env vars so the credential stays in the environment, quote only
the signal-carrying lines of a captured artifact. Phase 1's completion criterion now
requires a *redacted* artifact. `scripts/hitl-loop.template.sh` notes that `capture`
echoes its value back to the terminal, so signing in stays a `step`, not a `capture`.

#### 4.6 `improve-codebase-architecture`

**YAGNI scoping filter** on the Explore step: instead of scanning the repo evenly, it
scopes to where change is actually landing. If you name a direction it takes it;
otherwise it reads the last ~20 commit messages to bias exploration toward
actively-developed paths. Rationale: a deepening opportunity in code nobody touches
is a refactor you will never cash in.

### Tier 2 -- new skills that fill real gaps

| Skill | Size | Why we want it |
|---|---:|---|
| **`code-review`** | 87 lines | Two parallel sub-agents: **Standards** (repo standards + a 12-item Fowler smell baseline from *Refactoring* ch.3) and **Spec** (does the diff faithfully implement the originating issue). Reported side by side, deliberately never merged or reranked, because a change can pass one axis and fail the other. This is exactly the post-loop review phase we flagged as a gap in `1ecd155`. |
| **`implement`** | 15 lines | The per-ticket driver: drive `/tdd` at pre-agreed seams, typecheck regularly, full suite once at the end, `/code-review`, commit. It is the interactive twin of our `prompt.md`. Adopting it gives the night shift and manual runs **one shared contract**. |
| **`wizard`** | 44 lines + `template.sh` | Generates an interactive bash script for steps only a human can perform (provisioning, credentials, CI secrets, one-off cutover). Cross-platform URL opening incl. WSL, hidden secret entry, idempotent `.env` upserts, `gh secret` writes. Fits our HITL slices directly. |
| **`research`** | 12 lines | Background agent; investigates against primary sources and leaves a cited Markdown file in the repo. |
| **`retro`** (in-progress) | 44 lines | Session retrospective, incl. an "Information access" category. Relevant to closing our loop's feedback cycle. |
| `wait-what`, `to-questionnaire`, `handoff` | 7-16 lines each | Productivity; optional. |

### Tier 3 -- conventions and documentation

#### 3.1 `.agents/invocation.md` (correctness, not style)

Upstream standardized how a skill invokes another skill. **Dependencies must be
phrased as an explicit Skill-tool call** -- `Call the Skill tool with "grilling"` --
not a bare `/grilling` left in prose for the model to interpret, and not a deep
`../other-skill/FILE.md` cross-reference. The reasoning: most harnesses expose skill
invocation as a tool the model calls, and naming the tool gets a materially higher
hit rate than dropping a slash-name into prose and hoping it reads as a command.

Two corollaries:

- The Skill tool takes **one skill per call**. A step needing two is *"call the Skill
  tool twice, for X and Y"*, never "call it with X and Y".
- A **user-invoked** skill can never be reached this way. Where a step's precondition
  is user-invoked (e.g. `setup-afk-skills`), phrase it as an instruction to the human:
  *"tell the user to run `/setup-afk-skills`"*.

**Action for us:** audit our skills for bare `/skill` mentions in operative steps.
Our `triage` step 4 (`run a /grill-with-docs session`) is one such case.

#### 3.2 The workflow pages

Upstream now ships 23 long-form per-skill documentation pages under
`docs/engineering/` and `docs/productivity/` (the aihero.dev pages). Each covers:
what it does, when to reach for it, prerequisites, and a routing table of
"the work is X -> reach for Y".

We have no equivalent. Our README's flow table is the closest thing.

Also new and genuinely useful: **`ask-matt/PHASE-BOUNDARIES.md`** -- an ordered
decision tree for what to do with context at a phase boundary. Five options in
order: **continue** (rule it out first, the only move that keeps the conversation as
a primary source rather than a summary of one), **`/clear`**, **`/handoff`** (narrow:
new harness, new directory, a colleague, or forking a side task mid-phase --
what it buys is portability), **subagent**, **`/compact`** (the default, at the
*bottom* of the tree, not the first reach). Smart-zone estimate revised 120k -> ~150k
tokens.

#### 3.3 Em-dash purge

Upstream stripped em-dashes repo-wide in `3216582` and added guidance steering future
writing away from them.

**We currently have 185 em-dashes across `skills/`:**

| File | Count |
|---|---:|
| `skills/setup-afk-skills/SKILL.md` | 33 |
| `skills/improve-codebase-architecture/SKILL.md` | 21 |
| `skills/triage/SKILL.md` | 21 |
| `skills/diagnose/SKILL.md` | 17 |
| `skills/qa/SKILL.md` | 16 |
| `skills/triage/OUT-OF-SCOPE.md` | 14 |
| `skills/grill-with-docs/ADR-FORMAT.md` | 11 |
| `skills/improve-codebase-architecture/INTERFACE-DESIGN.md` | 9 |
| `skills/grill-with-docs/SKILL.md` | 8 |
| (9 more files) | 35 |

This violates the global house rule (`--`, never `—`). A Tier 1 re-sync clears it as
a side effect, since upstream's current content is already em-dash-free.

#### 3.4 `agents/openai.yaml`

Every upstream skill now carries a sibling `agents/openai.yaml` holding Codex UI
metadata (`interface.display_name`, `interface.short_description`) and, for
user-invoked skills, `policy.allow_implicit_invocation: false` -- the Codex analog of
`disable-model-invocation: true`. The two must stay in sync: a skill is user-invoked
in both harnesses or neither.

Relevant to us given Codex participates in the multi-role review council.

**Known upstream gotcha:** a `description:` containing an unquoted colon breaks the
YAML front-matter parse (upstream fix `5c89081`). **Audited: none of our 14 skill
descriptions contain a colon. We are clean.**

---

## 5. What to skip

| Item | Reason |
|---|---|
| **`wayfinder`** | Upstream renamed the `zoom-out` *folder* to `wayfinder`, but they are unrelated in substance. Ours is a 1-line "go up a layer, map the modules and callers." Wayfinder is a 128-line fog-of-war planning map for efforts too big for one session (destination, decision tickets, blocking edges, "Not yet specified", "Out of scope"). **Keep `zoom-out` as-is**; treat wayfinder as a separate adoption decision if we ever need multi-session planning. |
| **`caveman`** | Was upstream; Matt deleted it (`7d3ada9`, "streamline productivity skills"). Keeping it is a deliberate divergence and it is fine. |
| **`to-prd` -> `to-spec`** | Rename plus prose polish only (20 lines, mostly em-dash removal). Not worth the churn to our README, `prompt.md` and `setup-afk-skills` unless we are re-syncing everything anyway -- in which case take it. |
| **`domain-modeling` / `grilling` / `codebase-design` as separate skills** | We deliberately inlined these into `grill-with-docs`, `tdd` and `improve-codebase-architecture` to keep the plugin at 14 skills. Revisit only if the inlined copies start drifting badly. |
| **Changesets / release CI** | Upstream uses `@changesets/cli` + a release workflow. Our single-author `master` pattern does not need it. |

---

## 6. Plan

### Phase 1 -- Tier 1 re-sync (target: v0.6.0)

For each skill: take upstream's current file, replay our substitution set (2.1), then
re-apply our genuinely-ours additions.

- [ ] `to-issues` <- `to-tickets`. Take the blocking-edge model and the wide-refactor
      expand/contract section. **Preserve our HITL/AFK slice tagging.** Decide
      whether to rename our skill to `to-tickets` (breaking for anyone with muscle
      memory, and it touches README, `prompt.md`, `setup-afk-skills`) or keep
      `to-issues` as the name with upstream's body.
- [ ] `tdd` <- upstream. Take the seams reframing and the tautological-test
      anti-pattern (incl. the `tests.md` example). Decide the fate of our
      `refactoring.md` / `deep-modules.md` / `interface-design.md` now that upstream
      has moved that material into `codebase-design`.
- [ ] `triage` <- upstream. Take the redundancy check and the already-implemented vs
      rejected `wontfix` split. **Skip the PR-triage surface** on the first pass
      (default-off upstream anyway); revisit if we start taking external PRs.
- [ ] `setup-afk-skills` <- upstream. Take the section-skipping and
      recommendation-first flow. **Preserve step 5 (runner-script vendoring).**
- [ ] `diagnose` <- upstream. Take the redaction section wholesale.
- [ ] `improve-codebase-architecture` <- upstream. Take the YAGNI scoping filter.
- [ ] Verify 0 em-dashes: `grep -ro $'—' skills commands README.md scripts | wc -l`
      (excludes `docs/`, since this file quotes the character deliberately)
- [ ] Update README skills table + flow table for any renames.
- [ ] Bump `.claude-plugin/plugin.json` to `0.6.0`.

### Phase 2 -- Tier 2 adoption

- [ ] Add `code-review`. Wire it into the post-loop review phase documented in the
      README (`## After the loop`).
- [ ] Add `implement`. Reconcile it with `scripts/prompt.md` so the night shift and a
      manual `/implement` run follow one contract.
- [ ] Re-evaluate `wizard`, `research`, `retro` once 1 and 2 have settled.

### Phase 3 -- conventions (can run in parallel with 2)

- [ ] Audit operative steps for bare `/skill` mentions; convert to explicit
      `Call the Skill tool with "<name>"` phrasing. Known offender: `triage` step 4.
- [ ] Decide on `agents/openai.yaml` sidecars for Codex parity.
- [ ] Decide whether to write our own `docs/` workflow pages, or keep the README flow
      table as the single source.

---

## 7. Open questions

1. **Rename `to-issues` -> `to-tickets`?** Upstream's naming is better (a "ticket" is
   the unit; an "issue" is the tracker artifact) but it ripples into `prompt.md`,
   `setup-afk-skills`, `to-prs` and the README.
2. **Do we adopt `codebase-design` as a real skill** (making 15), or keep its material
   inlined across `tdd` and `improve-codebase-architecture`?
3. **`implement` vs `prompt.md`:** one contract or two? The night shift is headless
   and issue-driven; `/implement` is interactive and ticket-driven. They should agree
   on the pre-commit gate and the `Status:` transitions at minimum.
4. **Do we track upstream at all going forward,** or is v0.6.0 the last sync and we
   diverge deliberately from here?

---

## Appendix: upstream references

- Repo: <https://github.com/mattpocock/skills>
- Runner origin: <https://github.com/mattpocock/ai-hero-cli> (`ralph/`)
- Fork point: `ffb2fa662321045a8ace6f56f29ef8af11e19d3d` (2026-06-12)
- Head analysed: `6654f6b` (2026-08-24), plugin v1.2.3
- Notable upstream commits:
  - `3216582` -- remove all em-dashes repo-wide
  - `5c89081` -- quote SKILL.md descriptions with unquoted colons (YAML parse fix)
  - `1dab982` -- stop skills from calling other user-invoked skills
  - `d28dfdc` -- standardize cross-skill invocation on explicit "call the Skill tool"
  - `447ca70` -- clarify multi-skill steps as multiple Skill tool calls
  - `44eed54` (PR #502) -- friendlier `setup-matt-pocock-skills`
  - `45afd80` (PR #533) -- YAGNI scoping in `improve-codebase-architecture`
  - `697d4ce` (PR #551) -- Codex `agents/openai.yaml` metadata
  - `efce423` (PR #779) -- `diagnosing-bugs` secret redaction
