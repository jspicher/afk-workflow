---
name: implement
description: Implement an approved ticket or specification with testing and independent review.
disable-model-invocation: true
---

## Project configuration and skill loading

Resolve <workflow-root> from the repository's AFK_WORKFLOW_ROOT pointer and read
config/workflow.json plus relevant config notes under that root. If absent, tell
the user to run setup-afk-skills. Never create a fallback docs tree.
When a step uses another skill, Claude calls Skill with afk-workflow:<name>;
Codex reads this project's .agents/skills/<name>/SKILL.md and follows it.
Use the project installation, not an unrelated global skill. Explicit-only skills
require user invocation; controller prompts explicitly select the AFK workflow.
Headless runs reuse durable approvals and report missing input instead of asking.


# Implement

Read the configured workflow and approved spec or ticket. Use TDD at the approved
seams, check types and focused tests regularly, then run the full gate. Consult
codebase-design when the interface itself needs clarification.

When invoked by the headless controller, follow its execution contract and return
its structured result. The controller owns review, repair sequencing, commit and
tracker updates. Never recursively launch it or commit ahead of review.

Interactively, establish test seams with the user first, reusing recorded approvals
without asking again. Implement the work, then use the configured reviewer through
scripts/review.sh. Review working changes against the starting commit, including
new files. Fix concrete findings and rerun affected checks; stop after two repair
attempts and hand unresolved work back. Commit only after checks and review pass.

A broad spec without tickets stays interactive; do not publish tickets or start
the unattended loop unless the user asks.
