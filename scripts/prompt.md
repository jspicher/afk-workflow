# Shared AFK execution contract

Read AGENTS.md / CLAUDE.md and respect project instructions, vocabulary, ADRs,
checks and commit conventions. Use the specified project skill installation,
not an unrelated global skill with the same name.

Work on the supplied ticket only. Its latest approved Agent Brief governs earlier
discussion. If requirements or dependencies conflict, return needs-info. Never
ignore an undeclared dependency discovered in the body. AFK eligibility does not
authorize pushes, PRs, merging, deployment, or unrelated external messages.

## Implementation

Use the TDD skill at the approved test seams: one failing behavioral test, minimal
implementation, then the next slice. Expected values need an independent source.
An explicitly approved no-new-tests decision is valid for documentation-only work.
Read the configured context and domain documents when relevant.

Run focused tests and typechecks during implementation. The controller runs the
configured full gate before review. Refactoring belongs to review and repair.

Return ready when ready for review, needs-info for missing requirements, or
ready-for-human for unresolved access/design/environment decisions. Propose a
commit message following the repository's conventions. Do not commit, change
ticket state, or recursively launch the AFK controller.

## Review

Review the supplied baseline against all working changes, including new files.
Assess Standards and Spec independently. Missing required evidence means blocked,
not pass. Concrete violations and unmet requirements block completion; code smells
are advisory unless supported by a violated requirement. Reviewers must not edit,
run checks that write files, repair, commit, or update tickets.

Use independent subagents for the two axes when available; otherwise perform
separate passes and disclose the limitation. Return the required structured result.

## Ownership

The controller owns checks, review sequencing, commits, status and recovery.
Do not ask interactive questions in a headless session; report missing input.
