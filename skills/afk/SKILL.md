---
name: afk
description: Run one AFK ticket lifecycle with implementation, independent review, and bounded repair.
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


# AFK: one ticket

Resolve the workflow root and run its scripts/once.sh from the target repository.
Pass a supplied local issue glob as one quoted argument. A single local ticket
path is an exact glob. GitHub uses the configured ready queue instead.

The configured roles determine the CLIs regardless of which CLI invokes this skill.
Show the roles, follow the controller's outcome, and report its completion, blocker,
or error and artifact path. Do not treat a failed command as completion or start
additional iterations.
