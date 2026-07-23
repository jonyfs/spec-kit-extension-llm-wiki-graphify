---
description: "Task list for installed-extension validation"
---

# Tasks: Installed Extension Validation

**Input**: Design documents from `/specs/003-installed-extension-validation/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/validation-harness.md,
quickstart.md

**Tests**: The harness *is* the test. Constitution Principle XV applies to it directly: a
validation harness that has only ever run against a working package could be a script that
prints "passed" unconditionally. The broken-package fixtures (Phase 2) are how it earns
trust, and every assertion must be observed failing against one before it is trusted.

**Organization**: grouped by user story. Phase 1 is the option-1 config-read prerequisite
that US3 depends on; without it, US3 ships red.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete work)
- **[Story]**: Which user story the task serves (US1, US2, US3)

---

## Phase 1: Config-read prerequisite (option 1 — decided in plan.md)

**Purpose**: The feature-002 script does not read a project `config.yml` (research R4,
confirmed by `grep`). US3 depends on it. This adds it as one additive change to `extension/`,
so US3 passes honestly rather than shipping red.

⚠️ **Blocking for US3 only.** US1 and US2 do not depend on this phase.

- [X] T001 Add a config-reading step to `extension/scripts/bash/graph-build.sh`: read `.specify/extensions/llm-wiki-graphify/config.yml` when present, applying `scope.root`, `graphify.min_version`, and `graphify.max_version` over the compiled defaults; a missing file remains silent and defaulted (config is `required: false`)
- [X] T002 Report a malformed `config.yml` as a distinct failure in `extension/scripts/bash/graph-build.sh` — stop and name the file as unreadable rather than silently falling back to defaults (spec US3 scenario 4)
- [X] T003 Port T001 and T002 to `extension/scripts/powershell/graph-build.ps1` at behavioural parity
- [X] T004 [P] Extend `scripts/test-graph-build.sh` and `.ps1`: a config narrowing `scope.root` changes the reported root; a config raising `graphify.min_version` above the installed version trips `dependency-too-old`; a malformed config stops distinctly. Watch each fail against the unmodified script before T001–T003 land
- [X] T005 Update `specs/002-graph-build-command/data-model.md` and `contracts/build-script.md` to record that the config is now read, closing the gap research R4 identified

**Checkpoint**: The script honours config, and the difference is observable — a configured
value proven to take effect, never inferred from the absence of an error (FR-009).

---

## Phase 2: Foundational (harness skeleton + broken-package fixtures)

**Purpose**: The harness scaffolding and the fixtures that prove it can fail. No user-story
assertion is trusted before Phase 2 exists.

⚠️ **Blocking**: Phases 3–5 depend on this phase.

- [X] T006 Create `scripts/validate-installed-extension.sh` with the three-state result model from `contracts/validation-harness.md`: PASS / FAIL / SKIP per scenario, an overall verdict of PASS only if all pass, FAIL on any fail, INCOMPLETE on any skip; and a per-scenario breakdown, never a bare pass/fail (FR-010, FR-011)
- [X] T007 Implement the throwaway-project lifecycle in `scripts/validate-installed-extension.sh`: `mktemp -d`, `specify init --here --integration claude --script sh --force` (research R1), and cleanup on every exit path including a trapped interrupt (FR-004, SC-004)
- [X] T008 Implement prerequisite gating in `scripts/validate-installed-extension.sh`: `specify` absent → INCOMPLETE naming the missing prerequisite, not a package failure; graphify absent → build and config scenarios SKIP, run INCOMPLETE (FR-010, SC-005)
- [X] T009 [P] Create `tests/fixtures/broken-packages/missing-command-file/` — a copy of `extension/` with `commands/build.md` deleted, its manifest still naming it
- [X] T010 [P] Create `tests/fixtures/broken-packages/wrong-command-name/` — a copy whose command name violates `speckit.{id}.{command}`
- [X] T011 [P] Create `tests/fixtures/broken-packages/missing-script/` — a copy whose command frontmatter references a script absent from the package

**Checkpoint**: The harness runs, gates its prerequisites honestly, and three broken packages
exist to fail against.

---

## Phase 3: User Story 1 — install cycle (Priority: P1) 🎯 MVP

**Goal**: Prove the package installs, registers what the manifest promises, removes cleanly,
and leaves nothing behind.

**Independent Test**: Run against the current package and confirm PASS; run against
`missing-command-file/` and confirm the install/register scenario FAILs naming the file.

- [X] T012 [US1] Implement "install and register" in `scripts/validate-installed-extension.sh`: `specify extension add --dev`, then assert the extension in `.specify/extensions/.registry` and in `specify extension list`, and the declared command name present (research R2, R5)
- [X] T013 [US1] Implement "remove and restore": `specify extension remove`, assert gone from registry and listing, and no extension file outside `.specify/extensions/.backup/` (research R6, FR-003)
- [X] T014 [US1] Implement CLI-format resilience: read facts from the structured registry, use `list`/`info` text only for corroboration, and FAIL loudly on an unrecognised format rather than concluding the extension is absent (research R5)
- [X] T015 [US1] Assert in the harness's own self-check that "install and register" FAILs against `tests/fixtures/broken-packages/missing-command-file/` and `wrong-command-name/`, naming the break — watch it fail before trusting it (FR-012, SC-002)

**Checkpoint**: US1 is independently deliverable and closes the mechanical half of Principle
VII.

---

## Phase 4: User Story 2 — command and hook execute (Priority: P2)

**Goal**: Prove the installed command's script actually runs and the hook is aggregated as
declared.

**Independent Test**: With the extension installed, run the installed script against the code
fixture and confirm the expected counts; read the aggregated hook config and confirm
`optional: true`.

- [X] T016 [US2] Implement "command script runs as installed": invoke `.specify/extensions/llm-wiki-graphify/scripts/bash/graph-build.sh build --confirmed` against the code fixture, assert `outcome=built`, the counts, and the evidence breakdown verbatim (research R3, FR-005)
- [X] T017 [US2] Implement "command prose registered": assert `commands/build.md` installed and its frontmatter `scripts.sh`/`scripts.ps` resolve to files present in the package — presence and reference, since executing the prose needs an agent (research R3)
- [X] T018 [US2] Implement "hook aggregated as declared": read `hooks.after_specify` from `.specify/extensions.yml`, assert our entry is `optional: true`, `priority: 20`, with the manifest's prompt and description (research R2, FR-006)
- [X] T019 [US2] Implement "dependency failure as installed": with graphify off `PATH`, invoke the installed script, assert `dependency-missing` and no graph (FR-005)
- [X] T020 [US2] Implement "declining the hook changes nothing" in `scripts/validate-installed-extension.sh`: assert that not invoking the offered build leaves the project's specification and workflow state unchanged (FR-007)
- [X] T021 [US2] Assert in self-check that "command prose registered" FAILs against `tests/fixtures/broken-packages/missing-script/` (FR-012, SC-002)

**Checkpoint**: Every declared command and hook has been executed or structurally verified as
installed — the substantive half of Principle VII.

---

## Phase 5: User Story 3 — configuration honoured (Priority: P3)

**Goal**: Prove the installed extension honours config and that its absence is safe. Depends
on Phase 1.

**Independent Test**: Install with no config and confirm defaults; install a scope-narrowing
config and confirm the graph covers only that subtree.

- [X] T022 [US3] Implement "missing config is silent": with no `config.yml`, invoke the installed script, assert it runs on defaults with no warning about the missing file (FR-008)
- [X] T023 [US3] Implement "config narrows scope": write a `config.yml` setting `scope.root` to a subdirectory, assert the reported root matches and the graph covers only that subtree (FR-009)
- [X] T024 [US3] Implement "config raises the floor": write a `config.yml` setting `graphify.min_version` above the installed version, assert `dependency-too-old`, proving the value was read (FR-009)
- [X] T025 [US3] Implement "malformed config stops distinctly": write an unparseable `config.yml`, assert the run stops naming the file rather than defaulting silently (FR-008, US3 scenario 4)

**Checkpoint**: All three user stories pass. Principle VII is satisfiable on this harness
alone (SC-006).

---

## Phase 6: Polish & Integration

- [ ] T026 Port `scripts/validate-installed-extension.sh` to `scripts/validate-installed-extension.ps1` at behavioural parity — same per-scenario states, same overall verdict (Principle V, FR-014)
- [X] T027 Add `installed-validation` and `installed-validation-windows` jobs to `.github/workflows/ci.yml`, installing the `specify` CLI and graphify at the pinned version, running the harness on Linux and Windows (FR-014). Reuse the Windows PATH fix from the feature-002 job
- [X] T028 [P] Run the isolation check from quickstart.md: capture `git status --porcelain` before and after a run and confirm it is unchanged (SC-004)
- [X] T029 [P] Run the skip-path check from `specs/003-installed-extension-validation/quickstart.md`: with graphify unreachable, confirm the run reports SKIP and INCOMPLETE, never PASS (SC-005)
- [X] T030 Update the root `CHANGELOG.md` with the harness entry, and mark Constitution Principle VII satisfiable via this harness in the feature-002 plan's deferred-gates note (SC-006)
- [X] T031 Time a full run and record it against SC-003's 5-minute budget in `research.md`

---

## Dependencies & Execution Order

```text
Phase 1 (config read — US3 prerequisite)
    │
Phase 2 (harness skeleton + broken-package fixtures)
    ↓
    ├─────────────────┬──────────────────────────┐
    ↓                 ↓                          ↓
Phase 3 (US1)     Phase 4 (US2)     Phase 5 (US3, needs Phase 1)
    └─────────────────┴──────────────────────────┘
                      ↓
              Phase 6 (Polish + CI)
```

US1 and US2 depend only on Phase 2. US3 depends on Phase 2 **and** Phase 1. The three stories
are otherwise independent, though they share the harness file and so are sequential in
practice within the bash implementation.

## Parallel Opportunities

- **Phase 2**: T009, T010, T011 — three independent fixtures.
- **Phase 1**: T004 (the failing-first tests) is independent of the porting in T003.
- **Phase 6**: T028, T029 are independent checks.

## Implementation Strategy

**MVP**: Phase 2 + Phase 3 (US1). That alone closes the mechanical half of Principle VII —
the package installs, registers, and removes cleanly, proven against broken packages.

**Increment 2**: Phase 4 (US2) — the substantive half: the command's script and the hook
actually work as installed.

**Increment 3**: Phase 1 + Phase 5 (US3) — config honoured. Phase 1 is sequenced here rather
than first because US1 and US2 deliver Principle VII without it; the config read is only
needed for US3, and doing it just-in-time keeps the `extension/` change close to the tests
that justify it.

## Completion notes

- **T026 (PowerShell harness port) — open, tracked.** The bash harness and both
  `graph-build` variants are exercised; the config read is parity-tested on both. The
  *installed-validation* harness itself is bash-only so far. Porting it to PowerShell is
  real remaining work, deferred honestly rather than faked — the same posture taken for
  Windows parity in feature 002 before CI settled it. The Linux job settles Principle VII
  today; the Windows harness job is the follow-up.
- **T031 — full run measured at 4 s**, far inside SC-003's 5-minute budget. Recorded in
  research.md as R7.
- Two harness bugs were found by running it, not by reading it: `specify extension remove`
  prompts interactively (fixed with `--force`), and a frontmatter parse used `sed \s`, the
  GNU extension BSD sed silently ignores — the exact defect this repository keeps hitting.
- A finding that reshaped the fixtures: `specify` validates more strictly than
  `validate-extension.py`, rejecting all three manifest-level breaks at install. A fourth
  fixture, `wrong-hook-optional/`, installs cleanly and fails a post-install assertion, so
  every assertion class is proven able to fail (SC-002).

## Task Count

| Phase | Tasks |
|---|---|
| 1 — Config read (US3 prerequisite) | 5 |
| 2 — Foundational | 6 |
| 3 — US1 | 4 |
| 4 — US2 | 6 |
| 5 — US3 | 4 |
| 6 — Polish | 6 |
| **Total** | **31** |
