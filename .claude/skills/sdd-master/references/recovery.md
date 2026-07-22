# Recovery

**Source of truth**: Local extension install behavior plus upstream Spec Kit documentation
**Verified against**: specify-cli 0.11.3
**Verified on**: 2026-07-21

Read this when a workflow step refuses to run, artifacts disagree with each other, or
something fired on its own and the user cannot tell what it did. For what each step
produces, read `workflow.md`. For how to write an artifact well, read `craft.md`. For
what is installed and how it compares to other tools, read `ecosystem.md`.

## 1. The diagnostic frame

Users describe being "stuck" as one problem. It is almost always one of three, and they
have nothing in common except the feeling:

| Class | What is actually true | What fixes it |
|---|---|---|
| **(a) Missing prerequisite** | A required artifact does not exist yet. The step is correct to refuse. | Produce the artifact with the step that owns it. |
| **(b) Drift** | Every artifact exists; they disagree. Nothing refuses; the output is just wrong. | Decide which artifact is authoritative, regenerate downstream. |
| **(c) Active block** | Artifacts are fine. Something interposed itself and denied the command. | Find the blocker and clear its state. |

Separate them before prescribing anything, because the fixes are mutually useless. A
regeneration will not satisfy a guard. Clearing a guard will not create a missing
`plan.md`. And a user hitting (a) and (c) at once — a genuinely common pairing — will
describe a single "it just won't run."

Ask three questions in this order:

1. **Did the command produce an error naming a file?** → class (a). The message tells
   you which one.
2. **Did the command produce a denial naming an action or an extension?** → class (c).
3. **Did the command succeed but produce something inconsistent with what the user
   believes is true?** → class (b).

"Start over" is almost never the right answer and is always the least informative one.
It discards completed work, destroys the evidence needed to diagnose the actual cause,
and leaves the user unable to avoid the same state next time. If you genuinely believe
a restart is warranted, you must be able to name what specifically is unrecoverable.

## 2. Prerequisite failures

The chain is enforced by real shell scripts, not by convention, so a refusal is a
**hard, deterministic fact about where you are in the workflow** — not a malfunction.
Treat it as free diagnostic output. It is the cheapest signal you will get.

From `.specify/scripts/bash/check-prerequisites.sh`:

| Condition | Message | Produced by |
|---|---|---|
| Feature directory absent | `ERROR: Feature directory not found: <dir>` → "Run /speckit-specify first to create the feature structure." | `/speckit.specify` |
| `plan.md` absent | `ERROR: plan.md not found in <dir>` → "Run /speckit-plan first to create the implementation plan." | `/speckit.plan` |
| `tasks.md` absent, with `--require-tasks` | `ERROR: tasks.md not found in <dir>` → "Run /speckit-tasks first to create the task list." | `/speckit.tasks` |

`--require-tasks` is passed by the implementation phase, which is why `plan.md` alone is
enough for `/speckit.tasks` but not for `/speckit.implement`.

From `.specify/scripts/bash/setup-tasks.sh`, which additionally requires **both**
`plan.md` and `spec.md` before it will generate tasks, and which fails separately if the
tasks template cannot be resolved through the override stack:

> `ERROR: Could not resolve required tasks-template from the template override stack`

That last one is not a workflow-state problem at all — it is a broken installation.
The message names the remedy: add an override at
`.specify/templates/overrides/tasks-template.md`, or restore shared infra.

Two failures that look like missing artifacts but are not:

- **Feature resolution failure.** `common.sh` resolves the active feature from
  `SPECIFY_FEATURE_DIRECTORY`, then `.specify/feature.json`. If neither is set you get
  `ERROR: Feature directory not found. Set SPECIFY_FEATURE_DIRECTORY or run the specify
  command to create .specify/feature.json.` The artifacts may exist perfectly well on
  disk; the scripts simply do not know which feature you mean. Fix the pointer, not the
  artifacts.
- **Missing `jq`.** Several scripts exit non-zero with `Missing dependency: jq` before
  doing any work. Nothing is wrong with the workflow.

## 3. Drift diagnosis and repair

Drift is the class where a confident answer is most likely to be wrong, so be careful
about what you claim.

**First, establish which artifact is authoritative.** Authority is not fixed by the
tool; it is determined by where the most recent *intentional human decision* was
recorded. Useful evidence, in descending reliability:

- The bridge's own `artifacts_sha256` snapshot. `update-handoff.sh` records SHA-256 of
  `spec.md`, `plan.md`, and `tasks.md` on `executing` and `complete` writes, and on a
  `complete` write it compares them and emits
  `[bridge] WARNING: artifact drift since executing snapshot: <files> (sha256 mismatch)`
  plus an `artifact_drift_detected` event in `.specify/bridge-events.jsonl`. This tells
  you *exactly* which files changed during execution — machine-verified, not inferred.
- `git log`/`git diff` per artifact. A hand-edit shows as a commit or working-tree change
  with no corresponding regeneration of its downstream files.
- Snapshots under `.specify/bridge-snapshots/<id>/`, copied by the bridge on each
  handoff write.

**Then apply the one direction-of-repair rule worth memorizing** (Thoughtworks' SPDD):

> **For a change in logic or intent, update the specification first, then regenerate
> downstream. For a refactoring, fix the code first, then sync the specification back.**

The reasoning is that the artifact which should lead is the one where the decision
actually lives. A behavior change is a decision about *what the system does* — that
belongs in the spec, and code written before the spec catches up encodes an unreviewed
decision. A refactoring changes nothing about what the system does, so forcing it
through the spec first generates ceremony that produces no new information, and the spec
edit would be a fiction written to justify a mechanical change.

**Then be honest about what the tool does not decide.** Upstream Spec Kit deliberately
does **not** prescribe a maintenance model. It names three — flow-back (code changes
propagate back into the spec), flow-forward (spec changes drive regeneration), and
living spec (the spec is continuously maintained as the primary artifact) — and calls
the choice a **team convention, not a CLI setting**. There is no flag that selects one.

So: diagnose the drift concretely, then present a repair consistent with the model the
project already appears to be using — inferred from its history, its constitution, and
how its artifacts have actually been maintained. Do not invent policy the tool
explicitly declines to set, and say plainly that this is a team decision if the project
has never made one.

**Repair order, once direction is chosen.** Regenerate strictly downstream-only, one
step at a time, reviewing each before continuing — a regeneration cascade run blind
turns one drifted artifact into three. Then run the cross-artifact consistency check
(`/speckit.analyze`) to confirm convergence rather than assuming it.

## 4. The two hook layers — keep them separate

Per `docs/HOOKS.md`, two independent things are called "hooks." They share a name and
nothing else, and conflating them is the single most common source of "my hook did not
fire."

| | Layer 1 — Spec Kit lifecycle hooks | Layer 2 — Harness hooks |
|---|---|---|
| Declared in | an extension's `extension.yml` | `.claude/settings.json`, `.codex/hooks.json` |
| Aggregated in | `.specify/extensions.yml` | n/a |
| Fires on | Spec Kit command lifecycle events (`before_plan`, `after_tasks`, …) | harness runtime events (`PreToolUse`, `Stop`, …) |
| Executes | a Spec Kit slash command, as prompt text for the agent | a real shell command, as an OS process |
| Owned by | the extension | the user's machine |
| **Can block?** | **No.** A `before_` hook is not a veto. | **Yes.** `PreToolUse` exit code 2 blocks the tool call. |

Diagnostic consequences worth stating out loud:

- A Layer 1 hook that "did not fire" usually did not fire because the user never ran the
  core command it is attached to, or because `enabled: false`, or because it has a
  non-empty `condition` (which consuming commands must skip rather than interpret).
- `optional` defaults to **true**. Omitting it does not make a hook mandatory.
- A Layer 2 hook that "did not fire" is usually a `matcher` regex that does not match the
  tool name, or a non-zero exit being reported as an error rather than a block.
- Only Layer 2 can genuinely prevent a tool call from executing. If a user reports that
  something was *blocked at the OS level*, look in the harness config — not in
  `extensions.yml`.

## 5. Hook interference — the hardest failure to self-diagnose

A hook with `optional: false` **auto-executes without prompting**. The user sees a
refusal with no visible cause, because nothing in their transcript says "a hook ran."
This project ships six such hooks in `.specify/extensions.yml`: `worktrees.create` on
`after_specify`, the superpowers bridge `guard` on `before_clarify`, `before_plan`,
`before_tasks`, and `before_implement`, and the bridge `handoff` on `after_tasks`.

### The bridge guard ladder

`speckit-superpowers-bridge/scripts/bash/guard-command.sh` evaluates five rules in order
against `.specify/superpowers-handoff.json`:

1. `speckit.implement` **denied** when handoff `status` is `executing` — *"speckit.implement blocked while superpowers handoff is executing"*
2. `superpowers:writing-plans` or `superpowers:brainstorming` **denied** when a handoff
   `feature_directory` is set *and* both `spec.md` and `plan.md` exist there — *"native superpowers planning is forbidden while spec kit owns design artifacts"*
3. `speckit.constitution` **denied** when `status` is `executing` — *"constitution edits blocked during active handoff; mark blocked first"*
4. any other `speckit.*` action — allowed
5. anything else — allowed

Every decision is appended to `.specify/bridge-events.jsonl` with `"action":"guard"` and
the `checked_action`. **That log is your diagnosis.** Tail it before speculating: it
tells you the decision, the reason string, the actor, and the timestamp. A denial exits
1 and prints both `Guard denied <action>.` and the reason — but the user may have seen
only the downstream refusal, not the guard's own output.

Note the honest nuance: the guard is a Layer 1 hook, so its "deny" is enforced by the
agent honoring the command's instruction, not by the OS. It is not a sandbox.

### Clearing it correctly

The remedy is to **move the handoff out of `executing`**:

```bash
.specify/extensions/speckit-superpowers-bridge/scripts/bash/update-handoff.sh \
  --status blocked --reason "pausing superpowers execution to edit the constitution"
# or, when execution genuinely finished:
.specify/extensions/speckit-superpowers-bridge/scripts/bash/update-handoff.sh \
  --status complete
```

`--status` accepts exactly `ready`, `executing`, `blocked`, `complete`; anything else is
a usage error.

Two things not to do, both of which users reach for first:

- **Do not delete `.specify/superpowers-handoff.json`.** The guard reads a missing file
  as empty status and will stop denying — so it *appears* to work — but you have thrown
  away `artifacts_sha256`, `last_snapshot_id`, and `artifact_owner`, which are exactly
  the fields the drift detection in section 3 depends on. You trade a five-second fix
  for a permanently undiagnosable class (b).
- **Do not re-run `/speckit.tasks` to "reset" it.** `handoff` is an `optional: false`
  `after_tasks` hook; re-running tasks just rewrites the handoff file and may regenerate
  `tasks.md` over completed work.

To stop a mandatory hook entirely rather than clearing its state, disable the extension
that declares it: `specify extension disable <id>` (e.g.
`specify extension disable speckit-superpowers-bridge`). This is the right move when the
extension is genuinely unwanted, and the wrong move when it is doing its job and the
user simply wants past it once.

## 6. A real portability bug, as a worked example

Verified in this project on macOS: `speckit-superpowers-bridge` **v1.1.0**'s
`update-handoff.sh` calls `realpath -m` in its `project_path`, `feature_full`, and
`snapshot_path` resolution. `-m` is a GNU coreutils extension; BSD `realpath` on macOS
does not implement it and fails immediately:

```
realpath: illegal option -- m
usage: realpath [-q] [path ...]
```

Because the script runs under `set -euo pipefail`, this aborts before the `jq` write —
so **`.specify/superpowers-handoff.json` is never created**. `guard-command.sh` is
unaffected: it never calls `realpath`, so it keeps running and keeps allowing everything
(empty status matches no deny rule).

Present this as a method, not a bug report. The diagnostic shape generalizes:

1. The *symptom* was at the wrong layer — "the handoff file isn't there" looks like
   state, and is actually a crash.
2. The **first move was to run the script directly** rather than through the hook.
   A Layer 1 hook's stderr is easy to lose; the script's is not.
3. The failure was **partial**. One script in an extension broke and a sibling did not,
   producing a coherent-looking but wrong system state. Always check whether the
   extension's *other* scripts share the failing call.
4. The cause was **platform-specific**, so it reproduces for some users and not others —
   worth checking `verified-versions.json` and the extension's declared platform support
   before assuming misuse.

## 7. Recovery order

| Symptom | Likely cause | Ordered fix | Preserves | Costs |
|---|---|---|---|---|
| `ERROR: <artifact> not found` naming a step to run | (a) missing prerequisite | Run exactly the named step; do not run later steps first | Everything | Nothing |
| `ERROR: Feature directory not found. Set SPECIFY_FEATURE_DIRECTORY…` | (a) feature pointer unset, artifacts intact | Set `SPECIFY_FEATURE_DIRECTORY` or repair `.specify/feature.json` | Everything | Nothing |
| `Could not resolve required tasks-template` | broken install, not workflow state | Add the override, or reinstall shared infra | Everything | Nothing |
| Command denied, no visible cause | (c) `optional: false` hook | Read `.specify/bridge-events.jsonl` → identify rule → `update-handoff.sh --status blocked` | Everything, including drift baselines | Nothing |
| Same, and the extension is unwanted | (c) | `specify extension disable <id>` | Artifacts | Loses that extension's guardrails for everyone on the project |
| Handoff file never appears | extension script crash (§6) | Run the script directly, read stderr, patch or disable | Everything | Nothing |
| Spec hand-edited, plan/tasks stale | (b) drift, logic change | Confirm spec authoritative → regenerate `plan.md` → review → regenerate `tasks.md` → review → `/speckit.analyze` | Spec | **Discards hand-edits to `plan.md` and `tasks.md`, and unchecked/checked task state.** Diff or copy them aside first |
| Code refactored, spec stale | (b) drift, refactoring | Fix code first → sync spec back by hand → `/speckit.analyze` | Code and task state | Manual, unautomated; slower |
| `[bridge] WARNING: artifact drift since executing snapshot` | (b) artifacts edited mid-execution | Diff the named files against `.specify/bridge-snapshots/<last_snapshot_id>/` → decide intentional vs accidental → repair per §3 | Everything | Nothing to diagnose; repair cost depends on the decision |
| Everything regenerates but stays inconsistent | (b) no agreed maintenance model | Name the three models, get the team to pick one, then repair | Everything | A decision the tool will not make for you |

Any recovery that regenerates an artifact **destroys hand-edits and completion state in
that artifact and everything below it**. Say so before recommending it, every time, and
offer the preserving alternative — copy the artifact aside, regenerate, and reconcile —
whenever one exists.

## Naming commands the user can actually type

Before you put a command in a repair procedure, check this project's invocation form.
The registry stores dotted names (`speckit.tasks`, `speckit.analyze`); several harnesses
expose them hyphenated and slash-prefixed (`/speckit-tasks`, `/speckit-analyze`). The
mapping is mechanical — replace dots with hyphens — but which form the user can type is
a property of their harness, not of Spec Kit.

Read `.specify/extensions/.registry` for the registered names and check the harness's
own command directory (for example `.claude/skills/` or `.claude/commands/`) for the
exposed form. This applies inside a diagnosis just as much as inside a recommendation: a
recovery order full of commands that do not resolve is worse than no recovery order,
because the user assumes their state is more broken than it is.
