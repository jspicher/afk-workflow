---
name: zoom-out
description: Tell the agent to zoom out and give broader context or a higher-level perspective. Use when you're unfamiliar with a section of code or need to understand how it fits into the bigger picture.
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


I don't know this area of code well. Go up a layer of abstraction. Give me a map of all the relevant modules and callers, using the project's domain glossary vocabulary.
