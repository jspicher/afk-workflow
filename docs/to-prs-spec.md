# `/to-prs` -- PR release-grouping skill (DESIGN SPEC, DRAFT for review)

Status: **BUILT 2026-06-13** -- skill authored at `skills/to-prs/SKILL.md`; plugin bumped 0.4.1 -> 0.5.0 (14 skills). This spec is retained as the design record.
Author: Anton (with Jeff), 2026-06-13.
Decisions locked: build = spec-first; name = `/to-prs`; risk = infer-only (v1); output = `PR-PLAN.md`; gating commands = inline + file; worked example = the 4-PR grouping (see Section 13).

---

## 1. Problem

The night-shift loop (`afk.sh`) emits **one atomic commit per issue onto one branch**. It has no notion of how those commits should be carved into pull requests -- that is a human integration concern the runner is deliberately blind to. Left unguided, the two default outcomes are both bad:

- **One giant PR** (all N issues) -- unreviewable; reviewers rubber-stamp. (BO-01 alone was ~791 lines; all 8 would be thousands.)
- **One PR per issue** -- the issues have a dependency DAG, so per-issue PRs become painful *stacked/dependent* PRs, and the overhead balloons.

There is currently only a prose heuristic in the README ("batch by risk tier"). Jeff wants this **baked into the plugin as an invokable system** that reads *his actual backlog* and emits *his actual batch commands*, not generic advice.

## 2. What `/to-prs` is (and is NOT)

**IS:** a planning skill. It reads the backlog issue files, builds the dependency DAG, partitions the issues into an **ordered sequence of PR-sized batches**, and writes a `RELEASE-PLAN.md`. Crucially, each batch in the plan includes the **exact board-gating commands** (the `Status:` flips + `afk.sh N`) to build that batch. So the PR plan *is* the night-shift batch schedule -- one artifact drives both planning and execution.

**IS NOT:** a git/GitHub actor. It does **not** open PRs, run `gh pr create`, branch, rebase, or touch git in any way. (The `/to-prs` name mirrors the `to-prd` / `to-issues` pipeline, but unlike issue creation it produces a *plan*, not the PRs themselves.) The skill description and the first line of its output must state this explicitly so the name does not mislead.

## 3. Pipeline position

```
/grill-me -> /to-prd -> /to-issues -> /triage -> /to-prs -> night shift (afk.sh, one PR per group) -> review/merge -> re-run /to-prs for the next batch
```

`/to-prs` sits between triage and the night shift. It is **re-runnable**: as issues reach `done`/merged, re-running re-partitions the remainder, so it stays accurate across the multi-batch workflow.

Run in: **fresh session** (reads durable state -- the issue files on disk).

## 4. Inputs (the data model)

Read every issue under `docs/afk-workflow/backlog/<feature>/issues/*.md`. For each issue extract:

| Field | Source | Use |
|---|---|---|
| `id` / title | H1 / filename | labelling |
| `Status:` | header line | drop `done`/`wontfix`/merged from the plan; only plan un-shipped work |
| `Type:` (AFK/HITL) | header line | risk signal + gate signal |
| **dependency edges** | `## Blocked by` **AND prose** (see 4.1) | hard topo constraint (C1) |
| **merge gate?** | HITL prose ("review must PASS before merge", "sign-off") | hard isolation (C2) |
| inferred **risk tier** | signals (see 5) | grouping (H1) |
| inferred **size** | AC count + scope signals (see 6) | split tie-breaker (H3) |
| theme / surface / deep-module | `## What to build` | cohesion (H2) |

### 4.1 Dependency extraction must read the WHOLE issue

Dependencies are **not** confined to the `## Blocked by` section. In the real BO set, BO-07's dependencies ("depends on BO-02 + BO-05") appear in its `Type:` line and triage prose, not only in `## Blocked by`. The skill MUST extract edges from the entire issue body (Blocked-by section + Type annotations + triage notes + "Blocked by:" mentions in prose). This semantic extraction is precisely why `/to-prs` is a **skill (model-driven), not a regex script** -- a naive parser keyed on one heading would miss edges and produce an unmergeable plan.

## 5. Risk inference (infer-only, v1)

No explicit `Risk:` field in v1. Infer a tier per issue from existing signals, then let the human correct it in the quiz (Section 8). Tiers: `low` / `medium` / `high` / `critical`.

Signals (strongest first):
1. **Explicit merge gate** in the issue (security review, risk sign-off) -> `critical`.
2. **Type: HITL** -> at least `medium` (human-gated for a reason).
3. **Keyword classes** in title/What-to-build:
   - `critical`/`high`: auth, session, impersonation, refund, payment, money, Stripe, delete/deletion/purge, migration, RLS, permissions, PII.
   - `medium`: schema, write/mutation endpoints, money-adjacent, cross-service (Medusa/Stripe).
   - `low`: read-only views, list/detail display, nav/shell, copy, styling, pure UI.
4. **Self-labels** ("highest-risk capability", "destructive") -> honor them.
5. Default when no signal -> `low`.

State in the skill that inference is heuristic and the quiz is where the human locks it. (v1.1 may add an optional `Risk:` field to remove re-run drift -- deferred per this round's decision.)

## 6. Size inference (tie-breaker only -- explicitly unreliable)

Pre-implementation size is genuinely unknowable (BO-01's 791 lines were unpredictable from its spec). Therefore size is the **weakest** heuristic -- used only to decide whether to SPLIT an otherwise-cohesive group, never as a primary grouping axis. Coarse proxy: `S/M/L` from acceptance-criteria count + number of layers touched + deep-modules introduced + migration present. The skill must state this proxy is approximate and never block a sensible risk/cohesion grouping on a size guess.

## 7. The partitioning algorithm

### Hard constraints (never violate)
- **C1 -- Dependency closure.** An issue may be in PR_k only if every one of its blockers is in PR_1..PR_k (already merged, or in the same PR). PRs form a topological layering. A plan that violates C1 produces an unmergeable PR.
- **C2 -- Merge-gate isolation.** An issue carrying an explicit PR merge gate (e.g. mandatory adversarial security review, external sign-off) gets its **own PR** -- or is co-bundled ONLY with issues that share that exact gate/dependency. Rationale: the gate blocks the entire PR, so bundling clean low-risk work behind a gated issue strands it. C2 fires rarely (1 of 8 in the BO set), so it isolates the genuinely dangerous work without shattering the plan.

### Soft heuristics (priority order; trade off against each other, never against C1/C2)
- **H1 -- Risk isolation.** Don't mix risk tiers in one PR; group same-tier so reviewer attention matches the stakes.
- **H2 -- Cohesion.** Group issues sharing a surface, deep module, or theme (e.g. all read-only views; refund + audit-log, since refund consumes the audit module).
- **H3 -- Size budget.** Soft cap per PR (~<=4 issues, OR ~<=12 acceptance-criteria-equivalents, OR not more than ~1-2 `L`); split when exceeded. (Weakest -- see Section 6.)
- **H4 -- Dependency proximity.** If A blocks B, same risk, tightly coupled -> prefer same PR (cuts stacked-PR overhead). If B is materially riskier -> split at the boundary.
- **H5 -- Minimize stacked-PR depth.** Few well-themed PRs beat many tiny dependent ones (the per-issue-PR antipattern), but never at the cost of C1/C2/H1.

## 8. Human-in-the-loop quiz (mirrors `/to-issues` step 4)

The skill is **not** a deterministic oracle. After computing a candidate plan it presents the ordered PRs as a numbered list and asks:
- Does the batching match your release cadence / reviewer bandwidth?
- Are the risk tiers right? (this is where inferred risk gets corrected)
- Are dependencies captured correctly?
- Should any PR be split or merged?

Iterate until approved, THEN write `RELEASE-PLAN.md`. Human corrections live in the plan artifact, not back-written to the issues (v1).

## 9. Output artifact: `RELEASE-PLAN.md`

Path: `docs/afk-workflow/backlog/<feature>/RELEASE-PLAN.md`. Template:

```markdown
# Release plan -- <feature>

Generated by /to-prs on <date>. This is a PLAN ONLY -- it does not open PRs.
Re-run /to-prs after each batch merges to refresh the remainder.

## PR 1 -- <title>  (risk: low)
Issues: BO-01, BO-02, BO-03, BO-04
Depends on PR: none
Rationale: <which rules drove this grouping>

Build this batch (board-gating):
  cd <repo root>
  # hold everything else
  for n in 05 06 07 08; do sed -i 's/^Status: ready-for-agent/Status: needs-triage/' docs/afk-workflow/backlog/<feature>/issues/$n-*.md; done
  # ensure this batch is ready (BO-01 already done is auto-skipped)
  for n in 02 03 04; do sed -i 's/^Status: needs-triage/Status: ready-for-agent/' docs/afk-workflow/backlog/<feature>/issues/$n-*.md; done
  bash docs/afk-workflow/scripts/afk.sh 5

PR description skeleton:
  ## Summary
  ## Issues in this PR
  ## Testing
  ## Risk / rollback

## PR 2 -- <title>  (risk: medium-high)
...
```

## 10. Worked example -- the live BO-01..08 backlog (validation)

Dependencies (extracted whole-issue): 01 -> none; 02/03/04 -> 01; 05 -> none (migration-gated HITL); 06 -> 03+05; 07 -> 02+05 (+ merge gate: security review); 08 -> 02+05 (destructive).
Inferred risk: 01-04 low; 05 medium; 06 high; 07 critical; 08 high.

Algorithm output:
- **PR1 = {01, 02, 03, 04}** -- gated shell + read-only views. Low risk, AFK, share the shell (H1+H2; 02-04 depend on 01 so same-PR per H4).
- **PR2 = {05, 06}** -- audit-log schema + refund. 05 must precede 06; 06 consumes 05's audit module (C1 + H2). Medium-high.
- **PR3 = {07}** -- impersonation. **Isolated by C2** (explicit adversarial-security-review merge gate). Critical.
- **PR4 = {08}** -- account deletion. High risk, destructive, separated from 07's gate (H1 + C2 spillover).

Note: this **refined the initial gut recommendation** (which lumped 07+08 into one PR). C2 gives a principled reason to isolate 07: bundling 08 with it would strand 08 behind 07's security review. The algorithm beats intuition with a concrete rationale -- that is the value over the prose heuristic.

## 11. Build deliverables (when approved)

1. `skills/to-prs/SKILL.md` -- frontmatter (name `to-prs`; description with triggers "plan PRs / how should I split this into PRs / batch the backlog / release grouping" + the "plans, does not create PRs" disclaimer), the algorithm (Sections 5-7), the quiz (8), the output template (9).
2. Output convention `docs/afk-workflow/backlog/<feature>/RELEASE-PLAN.md`; add to README "What it writes" tree.
3. README: new row in "Commands, in order" between `/triage` and the night shift (`/to-prs`, Recommended, Run-in = Fresh); new mermaid node; cross-link from "After the loop"; new row in the Skills table.
4. `setup-afk-skills`: add `/to-prs` to its skill inventory if it enumerates them.
5. Bump skill count 13 -> 14 in `plugin.json` + `marketplace.json` + README; version 0.4.1 -> **0.5.0** (new skill = minor).
6. No changes to `to-issues`/`triage`/runners (risk = infer-only; no new field in v1).

## 12. Deferred (v1.1+)

- **Split mode**: given an already-built branch with N commits, recommend how to carve it into stacked PRs from the *real* diffs (grounded LOC/file-overlap). Higher fidelity than plan-mode size guesses; for when you built a batch larger than intended.
- **Optional `Risk:` field** on the issue template (reads-if-present, infers-if-absent) to remove re-run inference drift.
- **Longitudinal**: record which plan shipped when, for trend/aud trail.

## 13. Open questions for Jeff -- RESOLVED 2026-06-13

All three locked by Jeff; skill BUILT this session.

1. Output filename -> **`PR-PLAN.md`** (matches the `/to-prs` command name).
2. Board-gating commands -> **both inline to the session AND written into the file.**
3. BO worked example (Section 10) -> **confirmed as-is**: PR1={01,02,03,04}, PR2={05,06}, PR3={07}, PR4={08}. C2 keeps 07 isolated so 08 isn't stranded behind 07's security review. This is the skill's baked-in worked example + acceptance test.

> Implementation note vs this spec: the built skill is **tracker-aware** (the spec's `sed`-based gating is the local-markdown case; the skill also emits `gh`/`glab` label-swap gating for GitHub/GitLab trackers, and uses the configured label strings from `triage-labels.md`). This keeps `/to-prs` consistent with the rest of the config-driven, tracker-agnostic plugin.
