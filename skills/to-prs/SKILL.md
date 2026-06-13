---
name: to-prs
description: Group a triaged backlog of ready issues into an ordered sequence of PR-sized batches and write a PR-PLAN.md. Use when the user wants to plan PRs, decide how to split work into pull requests, batch the backlog for release, group issues into PRs, or avoid one giant unreviewable PR. It PLANS only -- it never opens PRs or touches git.
---

# To PRs

Partition a triaged backlog into an **ordered sequence of PR-sized batches**, then write a `PR-PLAN.md` that doubles as the night-shift batch schedule -- one artifact drives both how you'll ship and how you'll build.

> **This skill PLANS, it does not act.** It never runs `gh pr create`, branches, rebases, commits, or touches git in any way. The name mirrors `/to-prd` and `/to-issues`, but the output is a *plan*, not the PRs themselves. Lead with that so nobody expects PRs to appear.

The issue tracker and triage label vocabulary should have been provided to you -- run `/setup-afk-skills` if not.

## Why this exists

The night shift (`afk.sh`) emits **one atomic commit per issue onto one branch**. It has no notion of how those commits should become pull requests. Left unguided, both defaults are bad:

- **One giant PR** (all N issues) -- unreviewable; reviewers rubber-stamp.
- **One PR per issue** -- the issues have a dependency DAG, so per-issue PRs become painful *stacked* PRs and the overhead balloons.

`/to-prs` reads *your actual backlog*, builds the dependency DAG, and emits *your actual batch commands* -- not generic advice.

## When to run

Between `/triage` and the night shift:

```
... -> /to-issues -> /triage -> /to-prs -> night shift (one PR per batch) -> review/merge -> re-run /to-prs for the next batch
```

**Re-runnable.** As batches merge, re-running re-partitions the remainder, so the plan stays accurate across a multi-batch project. Run in a **fresh session** -- it reads only durable state (the issue files / tracker).

## Process

### 1. Load the backlog

Read every **un-shipped** issue, per the configured issue tracker:

- **Local markdown** -- read `docs/afk-workflow/backlog/<feature>/issues/*.md`.
- **GitHub / GitLab** -- list open issues (`gh issue list` / `glab issue list`) and read each body + comments.

Drop anything already `done` / `wontfix` / merged -- only plan un-shipped work. For each remaining issue, extract:

| Field | Source | Use |
|---|---|---|
| id / title | filename or issue number | labelling |
| state | `Status:` line or triage label | drop shipped work |
| type (AFK / HITL) | `Type:` line or label | risk + gate signal |
| **dependency edges** | `## Blocked by` **and prose** (step 2) | hard topo constraint (C1) |
| **merge gate?** | HITL prose ("review must PASS before merge", "sign-off") | hard isolation (C2) |
| inferred **risk tier** | signals (step 3) | grouping (H1) |
| inferred **size** | AC count + scope signals (step 4) | split tie-breaker only (H3) |
| theme / surface / deep-module | `## What to build` | cohesion (H2) |

### 2. Extract dependencies from the WHOLE issue

Dependencies are **not** confined to the `## Blocked by` section. An issue's real blockers can show up in its `Type:` line, its triage notes, or prose ("depends on the audit-log issue"). Read the **entire issue body** for edges. This semantic extraction is exactly why `/to-prs` is a skill, not a regex -- a parser keyed on one heading would miss edges and produce an **unmergeable** plan.

### 3. Infer risk (infer-only)

There is no explicit `Risk:` field. Infer a tier per issue, then let the human correct it in the quiz (step 6). Tiers: `low` / `medium` / `high` / `critical`. Signals, strongest first:

1. **Explicit merge gate** in the issue (mandatory security review, risk sign-off) -> `critical`.
2. **Type: HITL** -> at least `medium` (human-gated for a reason).
3. **Keyword classes** in title / What-to-build:
   - `critical` / `high`: auth, session, impersonation, refund, payment, money, Stripe, delete / deletion / purge, migration, RLS, permissions, PII.
   - `medium`: schema, write / mutation endpoints, money-adjacent, cross-service.
   - `low`: read-only views, list / detail display, nav / shell, copy, styling, pure UI.
4. **Self-labels** ("highest-risk capability", "destructive") -> honour them.
5. No signal -> `low`.

State plainly that inference is heuristic and the quiz is where the human locks it.

### 4. Estimate size (tie-breaker ONLY)

Pre-implementation size is genuinely unknowable. Size is the **weakest** heuristic -- used only to decide whether to SPLIT an otherwise-cohesive group, never as a primary axis. Coarse proxy `S / M / L` from acceptance-criteria count + layers touched + deep-modules introduced + migration present. Never block a sensible risk / cohesion grouping on a size guess.

### 5. Partition

<hard-constraints>
Never violate these.

- **C1 -- Dependency closure.** An issue may be in PR_k only if every blocker is in PR_1..PR_k (already merged, or in the same PR). PRs form a topological layering. Violating C1 produces an unmergeable PR.
- **C2 -- Merge-gate isolation.** An issue carrying an explicit PR merge gate (mandatory adversarial security review, external sign-off) gets its **own PR**, or is co-bundled ONLY with issues that share that exact gate. The gate blocks the whole PR, so bundling clean low-risk work behind a gated issue strands it.
</hard-constraints>

<soft-heuristics>
Priority order; trade off against each other, never against C1 / C2.

- **H1 -- Risk isolation.** Don't mix risk tiers in one PR; group same-tier so reviewer attention matches the stakes.
- **H2 -- Cohesion.** Group issues sharing a surface, deep module, or theme.
- **H3 -- Size budget.** Soft cap per PR (~<=4 issues, OR ~<=12 acceptance-criteria-equivalents, OR not more than ~1-2 `L`); split when exceeded. Weakest -- see step 4.
- **H4 -- Dependency proximity.** If A blocks B, same risk, tightly coupled -> prefer same PR (cuts stacked-PR overhead). If B is materially riskier -> split at the boundary.
- **H5 -- Minimise stacked-PR depth.** Few well-themed PRs beat many tiny dependent ones, but never at the cost of C1 / C2 / H1.
</soft-heuristics>

### 6. Quiz the user

The skill is **not** a deterministic oracle. Present the candidate plan as a numbered list of ordered PRs (id + title + risk + depends-on per PR) and ask:

- Does the batching match your release cadence / reviewer bandwidth?
- Are the risk tiers right? (this is where inferred risk gets corrected)
- Are dependencies captured correctly?
- Should any PR be split or merged?

Iterate until approved. Human corrections live in the plan artifact, not back-written to the issues.

### 7. Write `PR-PLAN.md` (and print the gating commands)

Once approved, write `docs/afk-workflow/backlog/<feature>/PR-PLAN.md` (template below) **and** print each batch's board-gating commands inline to the session, so the user can act immediately and also has them on disk for later batches.

Use the issue tracker's **configured label strings** (from `docs/afk-workflow/config/triage-labels.md`), not the literal canonical names, and emit gating commands matching the configured tracker:

- **Local markdown** -- flip the `Status:` line in the held / batch issue files (`sed`).
- **GitHub / GitLab** -- relabel: `--remove-label ready-for-agent --add-label needs-triage` on held issues; the inverse on the batch.

The lever is the same regardless of tracker: **hold everything outside the batch** (move it out of `ready-for-agent`), **leave only this batch ready**, then run the loop. The loop stops on `<promise>NO MORE TASKS</promise>`; the iteration cap is only a backstop, never the batch selector.

## The `PR-PLAN.md` template

```markdown
# PR plan -- <feature>

Generated by /to-prs on <date>. This is a PLAN ONLY -- it does not open PRs.
Re-run /to-prs after each batch merges to refresh the remainder.

## PR 1 -- <title>  (risk: low)
Issues: NN-a, NN-b, NN-c
Depends on PR: none
Rationale: <which rules drove this grouping>

Build this batch (board-gating -- local-markdown tracker shown):
  cd <repo root>
  # hold everything outside this batch
  for n in 05 06 07 08; do sed -i 's/^Status: ready-for-agent/Status: needs-triage/' docs/afk-workflow/backlog/<feature>/issues/$n-*.md; done
  # ensure this batch is ready (already-done issues are auto-skipped by the loop)
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

(For a GitHub/GitLab tracker, the "hold / ready" lines become `gh issue edit ...` / `glab issue edit ...` label swaps instead of `sed`.)

## Worked example -- an 8-issue backlog

Dependencies (extracted whole-issue): 01 -> none; 02 / 03 / 04 -> 01; 05 -> none (migration-gated HITL); 06 -> 03 + 05; 07 -> 02 + 05 (+ merge gate: security review); 08 -> 02 + 05 (destructive).
Inferred risk: 01-04 low; 05 medium; 06 high; 07 critical; 08 high.

Output:

- **PR1 = {01, 02, 03, 04}** -- gated shell + read-only views. Low risk, AFK, share the shell (H1 + H2; 02-04 depend on 01 so same-PR per H4).
- **PR2 = {05, 06}** -- audit-log schema + the feature that consumes it. 05 must precede 06 (C1); 06 consumes 05's module (H2). Medium-high.
- **PR3 = {07}** -- the privileged capability. **Isolated by C2** (mandatory adversarial-security-review merge gate). Critical.
- **PR4 = {08}** -- the destructive capability. High risk; separated from 07's gate so it isn't stranded behind that review (H1 + C2 spillover).

Note how C2 **refines intuition**: a gut call might lump 07 + 08 into one "dangerous stuff" PR, but bundling 08 behind 07's security review would strand it. The algorithm gives a principled reason to split -- that is the value over a prose heuristic.

## What this skill does NOT do

- **No git, no GitHub/GitLab writes for PRs.** It never creates branches, commits, or pull requests. It edits issue *labels / Status* only as the printed gating commands the user chooses to run -- it does not run them for the user.
- **Size is a guess.** Pre-implementation LOC is unknowable; size only ever breaks a tie (step 4).
- **Risk is inferred, not authoritative.** The quiz (step 6) is where the human locks the tiers.
- **It does not modify `to-issues` / `triage` output.** It reads the backlog; it does not re-triage or rewrite issues.
