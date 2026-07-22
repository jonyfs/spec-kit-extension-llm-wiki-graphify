---
description: >-
  Verify the graphify installation, report what a build would examine, and —
  once confirmed — build or refresh the project knowledge graph.
scripts:
  sh: scripts/bash/graph-build.sh
  ps: scripts/powershell/graph-build.ps1
---

# Build the project knowledge graph

Builds or refreshes a [graphify](https://github.com/safishamsi/graphify) knowledge graph of
this project, so specifications and plans can be written against a graph you can inspect
rather than against whatever the agent inferred and forgot.

All graph construction is delegated to the graphify installation on this machine. This
command installs nothing, and implements no extraction, clustering, or rendering of its
own.

## Arguments

Parse `$ARGUMENTS`. All are optional.

| Argument | Effect |
|---|---|
| *(none)* | Refresh if a graph exists; otherwise a first build |
| `--full` | Re-examine everything, replacing the existing graph |
| `--path <p>` | Override the configured scope root for this run |
| `--status` | Report the current graph's state and exit; builds nothing |

An unrecognised argument stops the command with a message naming it. Never ignore one — a
silently dropped `--full` produces a refresh the user believes was a rebuild.

## Sequence

Run these in order. Each step's failure stops the command; no later step runs.

### 1. Dependency check

Run the script in `check` mode.

- **Exit 4 (`dependency-missing`)**: report that graphify is not installed or not on
  `PATH`, reproduce the install instructions from the script's output, and stop. Do **not**
  install it, and do **not** offer to. Nothing was written.
- **Exit 5 (`dependency-too-old`)**: report the version found alongside the range required,
  both taken from the script's output, and stop.

graphify is pre-1.0, so a version above the ceiling is refused for the same reason a
version below the floor is: this extension reads fields observed in one specific version,
and a newer release may have changed them silently.

### 2. Scope report

Run the script in `scope` mode and show the user, before anything is built:

- the resolved root and the number of files it holds
- that **no exclusions are applied** — graphify offers no exclusion mechanism, so vendored
  directories and any secrets stored in files inside the scope root *are* read
- that structure is extracted from code and documents alike, while the semantic layer needs
  a separate pass

If the scope holds nothing graphify can read, the build will report
`nothing-to-examine` (exit 3). That is not a success and must never be reported as one.

### 3. Confirmation

**Ask, and wait.** Absence of an answer is a decline.

State plainly what will happen: a build reads every file under the scope root and writes to
`graphify-out/`. On declining, report that nothing ran and stop.

Do **not** skip this step when this command was reached through the `after_specify` hook.
That is precisely the path where an unrequested build would be most surprising, and the
hook is offered — not automatic — for that reason.

### 4. Build

Run the script in `build` mode with `--confirmed`, plus `--full` if the user asked for a
rebuild.

The script changes into the scope root before invoking graphify, because graphify writes a
`manifest.json` into the *working* directory while writing the graph to the *target* path.
Running it from elsewhere leaves a stray `graphify-out/` behind.

### 5. Report

Render the script's structured output for a human:

- **Outcome first.** The nine outcomes — `built`, `current`, `nothing-to-examine`,
  `declined`, `dependency-missing`, `dependency-too-old`, `already-running`,
  `interrupted-state`, `failed` — each get their own wording. Never collapse two into one
  message.
- **Counts**: entities and relationships.
- **Evidence breakdown**: reproduce `EXTRACTED`, `INFERRED`, and `AMBIGUOUS` **verbatim**,
  as a breakdown. Never sum them into a single relationship count, and never paraphrase
  them. A graph that is entirely `EXTRACTED` and one that is 40% `INFERRED` are different
  objects, and a single total cannot tell them apart.
- **Delta** on a refresh: what was added, changed, and removed.
- **Output location** and **elapsed time**.
- **Backup path** when graphify created one — it is the user's only recovery path if the
  rebuild was a mistake.

**Coverage statement — required on every completed build.** State, precisely:

> Structure was extracted from code and from documents alike — a Markdown heading is an
> entity here, exactly as a function is. What this run did **not** produce is the semantic
> layer: concepts spanning documents, and relationships inferred between prose and the code
> that implements it. No exclusions were applied.

Precision matters more than reassurance. Saying "your documents were not read" is false —
their structure was — and a user who checks will find their headings, conclude the
statement was wrong, and then trust the graph for the semantic claims it cannot make.

### 6. Handoff offer

When the scope contained documents, offer the model-assisted pass as an explicit next step:

> To add the semantic layer — concepts spanning documents, and inferred relationships —
> run `/graphify --update` in your AI assistant. That pass uses a model, so it costs time
> and money; this one did not.

Offer only. Never run it, and never make this build's success conditional on it.

## Prohibitions

| Never | Why |
|---|---|
| Install, upgrade, or modify graphify | It is the user's dependency, not ours |
| Build without confirmation obtained in this same invocation | A build reads every file and costs the user time |
| Read, write, or modify `spec.md`, `plan.md`, or `tasks.md` | Those belong to the core commands and to the user |
| Write anywhere except this extension's own directory and `graphify-out/` | Everything else belongs to the user |
| Edit anything under `graphify-out/` after graphify writes it | A hand-corrected graph no longer matches what a rebuild would produce |
| Delete anything under `graphify-out/` except `graph.json` in `--full` | Removing `cache/`, `manifest.json`, or the dated backups turns a rebuild into data loss |
| Claim that exclusions were applied | graphify ignores them; the claim would be false |
| Stage, commit, or push | Not this command's business |
| Block or gate any core Spec Kit command | The graph serves the workflow; it never gates it |
| Present a failed or skipped step as completed | A silent failure is worse than a loud one |

## When no graph exists

Say so, and offer to build one. Do not build unasked, and do not block whatever the user
was doing.
