# Workflow Reference

**Source of truth**: Upstream github/spec-kit command templates and scripts
**Verified against**: spec-kit CLI 0.13.3.dev0 / specify-cli 0.11.3 (local install)
**Verified on**: 2026-07-21

This file answers one question: what does each workflow step consume, produce, and
require before it will run. It does not cover how to write a good spec (`craft.md`), how
to diagnose a broken or drifted workspace (`recovery.md`), or which extensions and
competing tools are present (`ecosystem.md`).

---

## The steps

Each core command is a skill under `.claude/skills/speckit-<name>/`, invoked as
`/speckit-<name>`. All of them read `.specify/memory/constitution.md` when it exists and
treat it as non-negotiable.

| Step | Consumes | Produces | Hard prerequisite | Writes? |
|---|---|---|---|---|
| `constitution` | Your stated principles; the existing constitution | `.specify/memory/constitution.md` | None — runs on an empty project | Writes |
| `specify` | A natural-language feature description | `specs/NNN-name/spec.md`, and `.specify/feature.json` pointing at it | None | Writes |
| `clarify` | `spec.md` | Same `spec.md`, with a `## Clarifications` → `### Session YYYY-MM-DD` block | `spec.md` exists | Writes (spec only) |
| `plan` | `spec.md` + constitution + `plan-template.md` | `plan.md`, plus `research.md`, `data-model.md`, `contracts/`, `quickstart.md` as the feature needs them | Feature directory resolvable | Writes |
| `tasks` | `plan.md` (required), `spec.md` (required), whatever optional design docs exist | `tasks.md` | `plan.md` **and** `spec.md` must exist — enforced by script | Writes |
| `analyze` | `spec.md`, `plan.md`, `tasks.md`, constitution | A report in the conversation only | `tasks.md` complete | **Nothing** |
| `checklist` | `spec.md`, plus `plan.md`/`tasks.md` if present | `specs/NNN-name/checklists/<domain>.md` | `plan.md` exists (it calls the plan-requiring prerequisite check) | Writes |
| `implement` | `tasks.md`, `plan.md`, and every design doc present | Actual code, and `[X]` marks in `tasks.md` | `tasks.md` must exist — enforced by script | Writes |
| `converge` | `spec.md`, `plan.md`, `tasks.md`, the current code | A new `## Phase N: Convergence` section appended to `tasks.md` | `tasks.md` must exist; intended after `implement` has run | Appends only |

Two behaviors in that table are easy to get wrong and worth stating outright.

**`clarify` is meant to run before `plan`, not after.** Its own template says so, and
warns that skipping it raises downstream rework risk. That warning is the honest framing:
clarification is cheap while only `spec.md` exists and expensive once `plan.md` and
`tasks.md` have been derived from the ambiguity.

**`checklist` is not a test plan.** Its template calls checklists "unit tests for
English" — they interrogate whether the *requirements* are complete, unambiguous, and
consistent, not whether the implementation works. A checklist item like "verify the
button clicks correctly" is a misuse. `implement` reads these: if any checklist has
incomplete items it stops and asks whether to proceed anyway, so an incomplete checklist
is a soft gate on implementation, not a decoration.

---

## The prerequisite chain, and who enforces it

The ordering is not advisory. Three bash scripts under `.specify/scripts/bash/` enforce
it and exit non-zero when it is violated. (PowerShell equivalents ship alongside.)

| Script | Called by | Hard-errors when |
|---|---|---|
| `setup-plan.sh --json` | `plan` | The feature directory cannot be resolved. Otherwise it creates the directory and copies the plan template if `plan.md` is absent |
| `setup-tasks.sh --json` | `tasks` | `plan.md` is missing (`Run /speckit-plan first`), or `spec.md` is missing (`Run /speckit-specify first`), or the tasks template cannot be resolved |
| `check-prerequisites.sh --json` | `checklist` | The feature directory or `plan.md` is missing |
| `check-prerequisites.sh --json --require-tasks --include-tasks` | `implement`, `converge` | `tasks.md` is missing (`Run /speckit-tasks first`) — in addition to the feature-directory and `plan.md` checks |
| `check-prerequisites.sh --json --paths-only` | `clarify` | Only the feature directory fails to resolve; no artifact validation is performed at all |

Note the asymmetry: `--paths-only` skips validation entirely, which is why `clarify` will
happily run when `plan.md` does not exist yet — that is the intended order, not an
oversight.

**A refusal is diagnostic information, not a malfunction.** When one of these scripts
exits with `ERROR: plan.md not found in ...`, it has told you precisely which artifact is
missing and named the command that produces it. Users routinely read this as the tool
being broken and reach for reinstalling, re-initializing, or starting the feature over —
all of which destroy work to fix nothing. The correct response is always to run the named
prerequisite. The one case where the message is genuinely misleading is a feature-resolution
failure, covered below.

---

## Artifact structure

One fact, one artifact. Drift happens when the same decision is recorded in two places,
so the split matters more than the formatting.

**`spec.md`** — *what and why, never how.* Template-mandatory sections: `User Scenarios &
Testing`, `Requirements`, `Success Criteria`. User stories are numbered and prioritized
(`### User Story 1 - [Title] (Priority: P1)`), each with acceptance scenarios and an
independent test. Requirements are `FR-###`; measurable outcomes are `SC-###`. Optional:
`Key Entities` when data is involved, `Edge Cases`, `Assumptions`. `clarify` adds
`## Clarifications` with dated session subsections and nothing else.

**`plan.md`** — *how.* Sections: `Summary`, `Technical Context` (language, dependencies,
storage, testing, platform, performance goals, constraints, scale — unknowns marked
`NEEDS CLARIFICATION`), `Constitution Check` (a gate evaluated before Phase 0 and
re-evaluated after Phase 1), `Project Structure`, and `Complexity Tracking` — the last of
which exists to justify violations and should be omitted when the gate passes clean.

**`research.md`** — Phase 0 output. Its job is to resolve every `NEEDS CLARIFICATION`
raised in Technical Context, as decisions with rationale. If it exists and unknowns
remain, planning is not finished.

**`data-model.md`** — Phase 1. Entities, fields, relationships, and state. Generated only
when the feature has data worth modeling.

**`contracts/`** — Phase 1. One file per observable interface. Downstream, `tasks` maps
each contract to tasks, so a contract that names no interface produces no work.

**`quickstart.md`** — Phase 1. How to validate the feature works, in a form a person can
follow.

**`checklists/`** — one file per focus area (`security.md`, `ux.md`, …). Requirements-quality
questions, not verification steps.

**`tasks.md`** — Ordered, dependency-aware, grouped into phases. The format is strict:

```text
- [ ] T001 [P] [US1] Description with exact file path
```

- `T###` — sequential, zero-padded, unique across the whole file.
- `[P]` — optional; means this task touches different files than its neighbors and can
  run in parallel. Two `[P]` tasks writing the same file is a bug, because `implement`
  will run them concurrently.
- `[US#]` — the user story this task serves. **Required in story phases, forbidden in
  Setup, Foundational, and Polish phases.** That is not cosmetic: story labels are what
  make a story independently implementable and independently deliverable as an MVP
  increment. A shared-infrastructure task labeled with one story falsely implies the
  other stories do not need it.
- The description must contain the exact file path. `implement` uses those paths to
  decide what can run in parallel and what must serialize.

Standard phase order: Setup → Foundational (blocking; no story work may start until it
completes) → one phase per user story in priority order → Polish.

---

## Feature resolution: the git branch is never consulted

This is the highest-value fact in this file, because it is the one that silently produces
wrong results rather than errors.

`get_feature_paths()` in `.specify/scripts/bash/common.sh` resolves the active feature in
exactly this order:

1. **`SPECIFY_FEATURE_DIRECTORY`** environment variable, if non-empty. Relative values
   are normalized against the repo root, and the value is then *persisted* into
   `.specify/feature.json` so later sessions without the env var still resolve.
2. **`.specify/feature.json`**, key `feature_directory` (parsed with `jq`, falling back to
   `python3`, then to `grep`/`sed`).
3. **Hard error.** `ERROR: Feature directory not found. Set SPECIFY_FEATURE_DIRECTORY or
   run the specify command to create .specify/feature.json.`

There is no fourth step. The current git branch is **not** part of resolution. The
companion function `get_current_branch()` returns `$SPECIFY_FEATURE` if set and otherwise
returns the empty string — it never shells out to git. `CURRENT_BRANCH` appears in script
output as a label only; nothing keys off it.

**Why this surprises people.** Spec Kit's conventions are saturated with branch imagery:
features are created as `001-feature-name`, the same string names both the branch and the
directory, `plan.md` carries a `**Branch**:` field, and the documentation talks in terms
of feature branches. Every signal suggests the branch is the selector. It is not. State
lives in `.specify/feature.json`.

**The symptom.** A user runs `git checkout 002-other-feature` and then `/speckit-tasks`.
The command succeeds — no error, no warning — and writes `tasks.md` into
`specs/001-first-feature/`, because `feature.json` still points there. Work lands in the
wrong feature directory while the branch name in every prompt says otherwise. The user
later reports "tasks disappeared" or "my plan doesn't match my spec," which is a drift
symptom with a resolution cause.

**The fix is to change the pointer, not the branch.** Either export
`SPECIFY_FEATURE_DIRECTORY=specs/002-other-feature` (which also rewrites `feature.json`),
or edit `.specify/feature.json` directly. `specify` sets it automatically when it creates
a feature, which is why the problem only appears when switching *back* to earlier work.

---

## Two more non-obvious facts

**Completed tasks are marked `[X]` in `tasks.md`, and that mark is load-bearing.**
`implement` is instructed to mark each finished task off as `[X]` in the file. This is not
bookkeeping for humans — it is what makes a scoped or resumed run possible. A long
implementation run can exhaust context before finishing; the documented remedy is to start
a fresh run, which reads `tasks.md`, sees which tasks are already `[X]`, and continues from
there. It follows that hand-editing checkboxes changes what a resumed run will do, and
that a run which fails to write its `[X]` marks will redo completed work. If a resumed run
is repeating itself, check whether the marks were actually written before assuming the
tool is at fault.

**`analyze` writes nothing at all; `converge` writes only by appending.** `analyze` is
declared strictly read-only — it produces a severity-graded findings report in the
conversation and may propose a remediation plan, but it never edits a file, and any
remediation must be invoked separately by the user. `converge` is nearly as constrained:
its only write is appending a new `## Phase N: Convergence` section to the bottom of
`tasks.md`. It must not modify `spec.md` or `plan.md`, must not rewrite, renumber, reorder,
or delete any existing task (including tasks from a previous convergence phase), and must
not touch application code. When the codebase already satisfies everything, it leaves
`tasks.md` byte-for-byte unchanged rather than appending an empty header.

That asymmetry is why both are safe to recommend to a user who is unsure of their state.
Neither can lose work. `analyze` tells you whether the three artifacts agree with each
other; `converge` tells you whether the artifacts agree with the code, and turns each gap
into a task rather than fixing it silently.
