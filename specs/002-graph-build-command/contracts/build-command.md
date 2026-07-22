# Contract: Build Command

**Artifact**: `extension/commands/build.md`
**Command**: `speckit.llm-wiki-graphify.build`
**Binds**: FR-001 – FR-014, FR-022, FR-023; Principles XVI, XVIII, XIX

The command is Markdown with YAML frontmatter, executed by the agent harness. It owns the
two things a script cannot own correctly: the confirmation decision (research R8) and the
handoff for non-code content (research R3).

## Frontmatter

```yaml
---
description: >-
  Verify the graphify installation, report what a build would examine, and —
  once confirmed — build or refresh the project knowledge graph.
scripts:
  sh: scripts/bash/graph-build.sh
  ps: scripts/powershell/graph-build.ps1
---
```

Both variants are declared. Shipping one is a release blocker (Principle V).

## Arguments

Received via `$ARGUMENTS`. All optional.

| Argument | Effect | Default |
|---|---|---|
| *(none)* | Refresh if a graph exists; otherwise a first build | — |
| `--full` | Re-examine everything, replacing the existing graph | Refresh when a graph exists |
| `--path <p>` | Override the configured scope root for this run | `scope.root` from config, else `.` |
| `--status` | Report the current graph's state and exit; builds nothing | — |

`--status` is covered by spec User Story 3 scenario 5 (a capability reached with no graph
states that fact and offers to build). It ships in v1 because that scenario needs a way to
ask without building; if it gains no scenario of its own it should be dropped rather than
carried untested.

An unrecognised argument is reported and the command stops. It is never ignored, because
a silently dropped `--full` produces a refresh the maintainer believes was a rebuild.

## Required sequence

The order is normative. Each step's failure stops the command with the corresponding
`BuildOutcome`, and no later step runs.

1. **Dependency check** (FR-001, FR-002). Invoke the script's `check` mode. On
   `dependency-missing`, report the tool as absent, name the install step, and stop. On
   `dependency-too-old`, report the version found alongside the version required, and
   stop. Do not install anything (FR-003). Do not create any directory (FR-004).

2. **Scope report** (FR-005, FR-013a). State the resolved root and the file count, and
   state that no exclusions are applied — the underlying tool offers no exclusion
   mechanism, so vendored directories and secrets inside the scope root *are* read
   (research R13). If the scope contains nothing the tool can examine, report
   `nothing-to-examine` and stop — this is not a success (FR-013).

3. **Confirmation** (FR-005, FR-006). Ask explicitly, and wait. Absence of an answer is a
   decline. On decline, report `declined`, write nothing, and stop. This step MUST NOT be
   skipped when the command was reached through the `after_specify` hook — that is
   precisely the path where an unrequested build would be most surprising.

4. **Build** (FR-007, FR-009). Invoke the script's `build` mode with the confirmation
   asserted. The script delegates to `graphify update <path>`; the command implements no
   extraction, clustering, or rendering of its own.

5. **Report** (FR-010 – FR-014). Render the `BuildReport` from the script's structured
   output. On a refresh, include the delta (FR-011).

## Report requirements

- **Evidence labels appear verbatim.** `EXTRACTED`, `INFERRED`, and `AMBIGUOUS` are
  reproduced as the graph carries them, as a breakdown, never summed into a single
  relationship count and never paraphrased (FR-012, SC-004, Principle XVIII).
- **The coverage statement is unconditional on a completed build** (FR-013a, SC-008).
  Every report for a `built` outcome states three things: code was interpreted; documents,
  papers, and images were not, and the maintainer's own graphify skill performs that pass
  (research R3); no exclusions were applied (research R13). Omitting any of them lets a
  prose-heavy project read a partial graph as complete — which, for a Spec Kit project
  whose most valuable content is Markdown, is the most likely misreading of all.
- **The backup path is surfaced when the tool creates one.** It is the maintainer's only
  recovery path after a rebuild replaces a graph.
- **Outcomes are distinguishable.** The nine `BuildOutcome` values produce nine different
  messages. No two may be reported with the same wording (SC-005).
- **A failure is never absorbed.** A step that failed is reported as failed; a step that
  was skipped is reported as skipped, never as completed (FR-014).
- **No inferred relationship is stated as fact.** If the report surfaces individual
  relationships, each carries its label and, for `INFERRED`, its confidence score.

## Prohibitions

| The command MUST NOT | Requirement |
|---|---|
| Install, upgrade, or modify graphify | FR-003 |
| Build without confirmation obtained in this same invocation | FR-006, SC-007 |
| Read, write, or modify `spec.md`, `plan.md`, or `tasks.md` | FR-016 |
| Write anywhere except the extension's own directory and `graphify-out/` | FR-015 |
| Edit anything under `graphify-out/` after the tool writes it | FR-018 |
| Stage, commit, or push | FR-017 |
| Block or gate any core Spec Kit command | FR-023, Principle XIX |
| Reimplement any part of graph construction | FR-009, Principle XVI |
| Claim that exclusions were applied | FR-013a, research R13 |
| Delete or edit anything under `graphify-out/` except removing `graph.json` in `--full` | FR-018, research R10 |

## Behaviour when no graph exists

Any other capability of this extension, reached with no graph present, states that fact
and offers this command. It does not build, and it does not block the step the maintainer
was performing (FR-023).
