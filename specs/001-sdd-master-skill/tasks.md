---
description: "Task list for the SDD Master Skill"
---

# Tasks: SDD Master Skill

**Input**: Design documents from `specs/001-sdd-master-skill/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: The spec requires evaluation (SC-001 through SC-003, SC-006), so evaluation
tasks are first-class implementation tasks here, not optional extras. There is no unit
test suite — the artifact is prose, and the only meaningful test is behavioral
comparison against a no-skill baseline.

**Organization**: Tasks are grouped by user story. Each story phase is independently
completable and independently testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: Which user story the task serves (US1, US2, US3)

## Path Conventions

Skill package lives at `.claude/skills/sdd-master/`. Evaluation output goes to
`.claude/skills/sdd-master-workspace/`, already gitignored. All paths below are relative
to the repository root.

---

## Phase 1: Setup

- [X] T001 Create the skill package directory structure at `.claude/skills/sdd-master/` with `references/` and `evals/` subdirectories
- [X] T002 Verify `.claude/skills/*-workspace/` is excluded in `.gitignore` so evaluation runs never enter version control

---

## Phase 2: Foundational

**⚠️ CRITICAL**: No user story work can begin until this phase is complete. Every story's
guidance is reached through the router, and every reference is trusted only because of
the provenance convention established here.

- [X] T003 Write the YAML frontmatter and skeleton of `.claude/skills/sdd-master/SKILL.md` with `name: sdd-master` and a first-draft description, per `contracts/skill-frontmatter.md`
- [X] T004 Write the four-band classification (`direct`, `light`, `full`, `defer`) into `.claude/skills/sdd-master/SKILL.md`, with each band's definition and the rule that exactly one is chosen
- [X] T005 Write the raising/lowering signal table into `.claude/skills/sdd-master/SKILL.md` from `data-model.md` Request Classification, including the rule that `full` requires at least one raising signal
- [X] T006 Write the reference-pointer section of `.claude/skills/sdd-master/SKILL.md` mapping each question class to exactly one reference file, so only the relevant one is loaded
- [X] T007 Establish the provenance header convention (`Source of truth` / `Verified against` / `Verified on`) as a documented rule inside `.claude/skills/sdd-master/SKILL.md`

**Checkpoint**: The router exists and can classify a request, but has no facts to cite yet.

---

## Phase 3: User Story 1 — Right-Sized Routing (Priority: P1) 🎯 MVP

**Goal**: A user describes work without naming the methodology and gets an approach
proportional to what they asked for — nothing for trivial changes, the full workflow for
substantial ambiguous ones.

**Independent Test**: Run the trivial-request case and the substantial-feature case in
separate sessions. The trivial one produces no artifacts; the substantial one names the
workflow steps in dependency order. Neither requires the user to mention Spec Kit.

### Implementation

- [X] T008 [US1] Create `.claude/skills/sdd-master/references/workflow.md` with the provenance header recording spec-kit CLI 0.13.3.dev0 and the verification date
- [X] T009 [US1] Document the eight core workflow steps in `.claude/skills/sdd-master/references/workflow.md`, stating for each what it consumes, what artifact it produces, and its hard prerequisite
- [X] T010 [US1] Document the artifact structure (specification, plan, task list, research, data model, contracts, checklists) and what belongs in each in `.claude/skills/sdd-master/references/workflow.md`
- [X] T011 [US1] Document the feature-resolution rule in `.claude/skills/sdd-master/references/workflow.md` — resolution order is environment variable, then `.specify/feature.json`, then hard error, and the git branch is never consulted
- [X] T012 [US1] Write the Direct-band guidance into `.claude/skills/sdd-master/SKILL.md`, stating that the correct output is the work itself with no artifacts and at most one sentence of explanation
- [X] T013 [US1] Write the Full-band guidance into `.claude/skills/sdd-master/SKILL.md`, requiring steps be named in dependency order with the artifact each produces
- [X] T014 [US1] Write the Defer-band guidance into `.claude/skills/sdd-master/SKILL.md`, requiring compliance with an explicit user instruction plus a statement of its cost

### Validation

- [X] T015 [P] [US1] Add the `resist-ceremony-on-trivial-change` case to `.claude/skills/sdd-master/evals/evals.json` with assertions that no specification, plan, or task artifact is produced
- [X] T016 [P] [US1] Add the `route-large-feature-to-full-flow` case to `.claude/skills/sdd-master/evals/evals.json` with assertions that steps are named in correct dependency order
- [X] T017 [US1] Run both US1 cases with and without the skill into `.claude/skills/sdd-master-workspace/iteration-1/`, following `quickstart.md` step 2
- [X] T018 [US1] Grade the US1 runs against contract clauses C1, C2, C3, C4 and C12 from `contracts/routing-contract.md`, recording pass/fail per clause

**Checkpoint**: US1 is complete and independently shippable. If the trivial case gained
ceremony, stop and fix the band thresholds before proceeding — that failure invalidates
the feature regardless of how the other stories score.

---

## Phase 4: User Story 2 — Recovering a Broken Workflow State (Priority: P2)

**Goal**: A user stuck mid-workflow gets a diagnosis naming the actual cause and an
ordered recovery that preserves their work.

**Independent Test**: Describe a state where a hand-edit left downstream artifacts stale
and a step refused to run. Both problems are named separately, a regeneration order is
given, and starting over is not advised.

### Implementation

- [X] T019 [US2] Create `.claude/skills/sdd-master/references/recovery.md` with the provenance header recording specify-cli 0.11.3 and the verification date
- [X] T020 [US2] Document prerequisite-failure diagnosis in `.claude/skills/sdd-master/references/recovery.md` — which step refuses without which artifact, and that a refusal is diagnostic information rather than a malfunction
- [X] T021 [US2] Document drift diagnosis and repair order in `.claude/skills/sdd-master/references/recovery.md`, including the direction-of-repair rule from research D5 (logic changes update the specification first; refactoring fixes code first and syncs back)
- [X] T022 [US2] Document the two hook layers in `.claude/skills/sdd-master/references/recovery.md` per `docs/HOOKS.md`, keeping lifecycle hooks and harness hooks explicitly distinct as Principle XI requires
- [X] T023 [US2] Document hook-interference diagnosis in `.claude/skills/sdd-master/references/recovery.md` — how an auto-executing hook can block a core step, how to identify the responsible extension, and how to clear the state without deleting it
- [X] T024 [US2] Write the precondition-checking rule into `.claude/skills/sdd-master/SKILL.md`, requiring an unmet precondition be named rather than a doomed recommendation issued
- [X] T025 [US2] Write the destructive-action rule into `.claude/skills/sdd-master/SKILL.md`, requiring the consequence be stated before the recommendation and a preserving alternative offered where one exists

### Validation

- [X] T026 [P] [US2] Add the `diagnose-broken-mid-flow-state` case to `.claude/skills/sdd-master/evals/evals.json` with assertions that both causes are named separately and recovery preserves completed work
- [X] T027 [US2] Run the US2 case with and without the skill into `.claude/skills/sdd-master-workspace/iteration-1/`
- [X] T028 [US2] Grade the US2 run against contract clauses C5, C6 and C7 from `contracts/routing-contract.md`

**Checkpoint**: US1 and US2 both work independently.

---

## Phase 5: User Story 3 — Grounded Craft Guidance (Priority: P3)

**Goal**: A user asking a judgment question gets an answer grounded in what practitioners
found, including where the evidence is weak.

**Independent Test**: Ask where a decision belongs across the governance, specification,
and plan layers. The answer gives a discriminating test that generalizes rather than
restating the question.

### Implementation

- [X] T029 [P] [US3] Create `.claude/skills/sdd-master/references/craft.md` with the provenance header recording the external-source snapshot date
- [X] T030 [US3] Document the three-layer question in `.claude/skills/sdd-master/references/craft.md` with the discriminating test — if it would be true of the next feature too, it belongs in governance
- [X] T031 [US3] Document how to write testable acceptance criteria in `.claude/skills/sdd-master/references/craft.md`, including the rule that unmeasurable adjectives must be replaced with observable outcomes
- [X] T032 [US3] Document feature sizing in `.claude/skills/sdd-master/references/craft.md`, including the micro-spec finding and why over-specifying trivial work degrades rather than improves output
- [X] T033 [US3] Document the evidence-grading scheme in `.claude/skills/sdd-master/references/craft.md` per `data-model.md` Evidence Grade, including the controlled findings from research D6 that point against the more-context-is-better intuition
- [X] T034 [P] [US3] Create `.claude/skills/sdd-master/references/ecosystem.md` with the provenance header stating that installed capabilities are read at use time
- [X] T035 [US3] Document dynamic capability discovery in `.claude/skills/sdd-master/references/ecosystem.md` — read `.specify/extensions.yml` and the registry at use time, never assert a capability exists because it exists elsewhere
- [X] T036 [US3] Document the routing table for common situations in `.claude/skills/sdd-master/references/ecosystem.md`, labeling this project's installed extensions explicitly as worked examples rather than a fixed catalog
- [X] T037 [US3] Document the competing tools and how each genuinely differs in approach in `.claude/skills/sdd-master/references/ecosystem.md`, without dismissing the alternatives

### Validation

- [X] T038 [US3] Verify each reference file against `contracts/skill-frontmatter.md` — provenance header present, no fact owned by two files, table of contents on any file over 300 lines

**Checkpoint**: All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T039 [P] Build `.claude/skills/sdd-master/evals/trigger-evals.json` with 20 realistic queries, roughly half should-trigger and half should-not, weighted toward near-misses that share vocabulary with the domain
- [X] T040 Tune the `description` field in `.claude/skills/sdd-master/SKILL.md` against the trigger evaluation set until activation is high on should-trigger and low on should-not, per SC-006
- [X] T041 Verify `.claude/skills/sdd-master/SKILL.md` is under 500 lines and contains no per-command facts that belong in a reference, per `contracts/skill-frontmatter.md`
- [X] T042 [P] Run `bash scripts/check-placeholders.sh` and confirm no template placeholders survived into the skill package
- [X] T043 [P] Verify every file in the skill package is written in English per constitution Principle IX
- [X] T044 Read one full evaluation transcript against all twelve clauses of `contracts/routing-contract.md`, noting qualitatively whether the responses read as reasoning or as checklist recital
- [X] T045 [P] Add the skill to `CHANGELOG.md` under Unreleased per constitution Principle VIII
- [X] T046 Open a pull request from `001-sdd-master-skill` to `main` with the constitution checklist honestly completed, and confirm all four CI jobs are green per constitution Principle XIV

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — starts immediately
- **Foundational (Phase 2)**: Depends on Setup. **Blocks every user story**
- **User Stories (Phases 3–5)**: All depend on Foundational. Independent of each other once it is done
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Depends only on Foundational. No dependency on other stories
- **US2 (P2)**: Depends only on Foundational. Independently testable without US1
- **US3 (P3)**: Depends only on Foundational. Independently testable without US1 or US2

The stories share the router but own separate reference files, which is what keeps them
independent. Each adds its own rules to `SKILL.md`, so their router edits are sequential
even though their reference work is parallel.

### Within Each User Story

Reference file creation → reference content → router rules → evaluation case →
evaluation run → grading. The router rules come after the reference exists so they can
point at something real.

### Parallel Opportunities

- T015 and T016 write separate evaluation cases and can be authored together
- T029 and T034 create two different reference files and can start together
- T039, T042, T043 and T045 in Polish touch different files and can run together
- Across stories: once Phase 2 is done, US2's `recovery.md` and US3's `craft.md` and
  `ecosystem.md` can be written concurrently by different agents, since no two stories
  edit the same reference

---

## Parallel Example: User Story 3

```text
# T029 and T034 create separate files — launch together:
Task: "Create references/craft.md with its provenance header"
Task: "Create references/ecosystem.md with its provenance header"

# Then their content tasks proceed independently:
Task: "Document the three-layer question in craft.md"        (T030)
Task: "Document dynamic capability discovery in ecosystem.md" (T035)
```

---

## Implementation Strategy

### MVP First

**Phases 1–3 only** — Setup, Foundational, and User Story 1. That yields a skill that
correctly resists ceremony on small work and routes substantial work into the full
workflow. Per the spec's US1 rationale, this is where the entire value sits: the
discrimination. Stop here and the feature is still worth having.

### Incremental Delivery

1. Complete Setup and Foundational → the router exists
2. Add US1 → **MVP, independently shippable**
3. Add US2 → recovery guidance, still shippable at any point
4. Add US3 → craft depth
5. Polish → trigger tuning and the pull request

### The stopping condition that matters

T017 and T018 gate everything downstream. If the trivial-request case gains ceremony
with the skill installed, the correct response is to fix the band thresholds, not to
proceed to US2. `quickstart.md` states this as the pass criterion: winning US1's
substantial case and US2's recovery case while adding ceremony to trivial work is a
failure, not an acceptable trade.

---

## Notes

- Evaluation runs use independent agents that did not author the skill. Grading your own
  prose is not evidence.
- Baseline (no-skill) runs are mandatory, not optional. Given that added context has been
  measured as net-negative in controlled settings, output that merely looks good does not
  show the skill helped.
- Every task writes inside `.claude/skills/sdd-master/` or this feature's `specs/`
  directory, satisfying constitution Principle VI.
