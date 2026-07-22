---
description: "Report traceability gaps between the current feature's spec.md, plan.md and tasks.md"
scripts:
  sh: .specify/extensions/trace/scripts/bash/trace-check.sh --json
  ps: .specify/extensions/trace/scripts/powershell/trace-check.ps1 -Json
---

# Traceability Check

Check that the current feature's Spec Kit artifacts still agree with each other,
and report every disagreement that can be decided mechanically.

This command is **read-only**. It never edits `spec.md`, `plan.md`, or
`tasks.md`, never creates files, and never touches git state. It tells you what
is inconsistent; deciding what to change is your call.

## User input

```text
$ARGUMENTS
```

`$ARGUMENTS` is optional. When it names a feature — either a directory path or a
feature folder name such as `003-payment-links` — pass it through to the script
as the feature selector. When it is empty, let the script resolve the feature
itself.

## Execution

1. Run the script for the current platform, from the repository root:

   - **Bash**: `.specify/extensions/trace/scripts/bash/trace-check.sh --json [--feature <name>]`
   - **PowerShell**: `.specify/extensions/trace/scripts/powershell/trace-check.ps1 -Json [-Feature <name>]`

   The script resolves the feature in this order: the explicit selector, the
   `SPECIFY_FEATURE` environment variable, `specs/<current-git-branch>`, then the
   most recently modified `specs/*/spec.md`.

2. Parse the JSON object it writes to stdout:

   | Field | Meaning |
   |---|---|
   | `feature`, `feature_dir` | Which feature was actually checked |
   | `artifacts` | Which of `spec.md` / `plan.md` / `tasks.md` exist |
   | `user_stories` | `total` in the spec, `with_tasks` covered by at least one task |
   | `requirements` | `total` defined in the spec, `cited_by_tasks` referenced by a task |
   | `tasks` | `total` task entries and how many are checked off |
   | `needs_clarification` | Count of unresolved `[NEEDS CLARIFICATION]` markers |
   | `findings` | The list of inconsistencies. Empty means clean |
   | `notes` | Context that is not a defect, e.g. a phase not reached yet |

   Exit code `0` means no findings (or `warn_only` is enabled), `1` means at
   least one finding, `2` means no feature directory could be resolved.

3. If the exit code is `2`, report that no feature was found and stop. The usual
   cause is that `/speckit.specify` has not been run yet.

## Report

Confirm which feature directory was checked, then present the results:

- **State** — one line with the story, requirement, and task counts.
- **Findings** — every entry in `findings`, each with the concrete next action
  that would resolve it:

  | Finding | Usual resolution |
  |---|---|
  | A user story has no tasks | Re-run `/speckit.tasks`, or drop the story from the spec |
  | A task tags a user story the spec does not define | Fix the tag, or add the story to the spec |
  | A task cites an unknown requirement ID | Fix the citation, or add the requirement to the spec |
  | A requirement or task ID is defined twice | Renumber the duplicate |
  | Unresolved `[NEEDS CLARIFICATION]` markers | Run `/speckit.clarify` |
  | `tasks.md` exists without `plan.md` | Run `/speckit.plan` before implementing |

- **Notes** — mention them only when they change the reading of the result, for
  example that `tasks.md` does not exist yet so task-side checks were skipped.

Do not edit any artifact as part of this command. If the user asks you to fix a
finding afterwards, that is a separate, explicit action.

## Scope

This check is deliberately mechanical and complements `/speckit.analyze` rather
than replacing it. It answers "do the IDs and structure line up?" — it does not
judge whether a requirement is well-written, whether the plan is sound, or
whether the tasks actually implement the spec. Those need `/speckit.analyze`.

## Configuration

Read from `.specify/extensions/trace/trace-config.yml`, overridden by
`.specify/extensions/trace/local-config.yml`. Both are optional; the built-in
defaults apply when neither exists.

| Key | Default | Effect |
|---|---|---|
| `requirement_pattern` | `(FR\|NFR\|SC)-[0-9]+` | Which identifiers count as requirements |
| `require_requirement_coverage` | `false` | Treat an uncited requirement as a finding |
| `fail_on_needs_clarification` | `true` | Treat a surviving clarification marker as a finding |
| `warn_only` | `false` | Report findings but always exit `0` |
