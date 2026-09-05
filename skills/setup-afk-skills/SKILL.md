---
name: setup-afk-skills
description: Configure AFK asset location, ticket storage, implementation and review roles, checks, and domain conventions.
disable-model-invocation: true
---

# Set up AFK Workflow

Explore AGENTS.md / CLAUDE.md, the AFK_WORKFLOW_ROOT pointer, existing workflow
layouts, tracker/domain notes, ignore rules, remotes, installed skills, and project
checks. Preserve existing instructions and custom files. Detect legacy YAML ticket
conventions such as FoS's status/depends_on.

## Interview one question at a time

Explicitly ask these choices; recommend existing settings on reruns:

1. Asset parent directory, default ./docs for new projects. Choosing ./.docs puts
   assets in ./.docs/afk-workflow. Normalize repository-contained absolute inputs
   to repository-relative paths before calling the helper.
2. Ticket storage, default local Markdown, with GitHub, GitLab, Jira and a described
   alternative available. Only local and GitHub have headless adapters. Record
   other systems' exact access and transition instructions for interactive use.
   Never infer GitHub storage merely from the remote.
3. Roles, default Claude implementer and Codex reviewer. Either CLI can fill either
   or both roles. Optional model values inherit CLI defaults when omitted.

Confirm the discovered full check commands as argument arrays, retaining required
environment settings with explicit env arguments. If no gate exists, establish a
meaningful check with the user before enabling headless execution.

When triage is installed, ask once whether to retain existing/default labels.
Single-context is the default; ask about multiple contexts only for a real monorepo.

## Preview and apply

Resolve scripts from this skill's assets/runtime directory for project Codex copies,
otherwise the Claude plugin root's scripts directory, otherwise a supplied source
checkout. Do not guess plugin cache paths.

Prepare the agreed checks JSON outside tracked source. Run setup.sh with explicit
--assets, --tracker, --implementer, --reviewer, --checks-file and, where applicable,
--repository owner/repo or --format fos-yaml. Show the default preview and intended
instruction-file changes, then apply with --apply once agreed. On reruns explicit
flags update those fields; omitted choices, custom notes and other settings are
preserved. Switching a role's CLI clears its previous provider's model override.

The helper installs runtime files, creates missing config notes and maintains
instruction pointers. Enrich issue-tracker.md, triage-labels.md and domain.md from
the reviewed project conventions and the templates alongside this skill.
workflow.json is authoritative for runtime roles, storage, labels and checks;
do not leave competing settings in Markdown notes.

If Codex is selected and project skills are absent, run the source distribution's
install-codex.sh against this repository, preview then --apply once agreed. It
copies skills into .agents/skills and records hashes. Reconcile conflicts without
overwriting modified copies or unrelated skills.

## Existing installations

Read both docs/afk-workflow and .docs/afk-workflow when discovering legacy layouts.
Preserve the existing location unless a move was selected. Use migrate.sh --from
OLD_PARENT --to NEW_PARENT, show the reference inventory, then --apply once agreed.
The helper moves only AFK-owned assets and retains recovery copies in Git metadata.

Replace obsolete AFK instruction sections with the managed pointer, retaining
unrelated rules. Preview active PRD.md/prd.md -> spec.md renames and their links;
reject collisions, retain backups, and update active to-prd/to-issues references.
Preserve historical records, custom domain files and existing ticket formats.

Old runners without ownership manifests may be customized. Show their diffs,
retain backups and reconcile with the new runtime before applying managed updates.
Do not blindly overwrite them or convert FoS YAML tickets to Markdown.

## Verify

Read back config/pointers and verify roles, storage, and skill sources. Reruns must
not duplicate sections or reset choices. Report whether Git ignores the assets;
do not force-add files or change ignore rules automatically. Show the configured
afk.sh/once.sh commands and point to the README configuration and recovery guide.
