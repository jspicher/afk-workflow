---
name: grill-with-docs
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project's language and documented decisions.
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


<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
<workflow-root>/
├── context/
│   └── CONTEXT.md
└── adr/
    ├── 0001-event-sourced-orders.md
    └── 0002-postgres-for-write-model.md
```

If a `<workflow-root>/context/CONTEXT-MAP.md` exists, the repo has multiple contexts. The map points to where each one lives:

```
/
├── <workflow-root>/
│   ├── context/
│   │   └── CONTEXT-MAP.md            ← points at the per-context files below
│   └── adr/                         ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md               ← per-context: stays with its code
│   └── billing/
│       ├── CONTEXT.md
```

Create files lazily; only when you have something to write. If no `<workflow-root>/context/CONTEXT.md` exists, create one when the first term is resolved. If no `<workflow-root>/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y; which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account'; do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible; which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up; capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

Don't couple `CONTEXT.md` to implementation details. Only include terms that are meaningful to domain experts.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse**; the cost of changing your mind later is meaningful
2. **Surprising without context**; a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**; there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

</supporting-info>

For multiple contexts, store new context-specific ADRs under <workflow-root>/adr/<context>/ and record those locations in the context map. Existing project domain.md locations take precedence; preserve established source-adjacent context documents.
