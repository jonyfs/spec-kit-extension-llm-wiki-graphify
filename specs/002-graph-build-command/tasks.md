---
description: "Task list for the graph build command"
---

# Tasks: Graph Build Command

**Input**: Design documents from `/specs/002-graph-build-command/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md,
critiques/critique-2026-07-22.md

**Tests**: Test tasks are included and are **not optional here**. Constitution Principle XV
requires every gate to be observed failing before it is trusted, and this feature's value
is concentrated in its failure paths — a missing dependency, an empty project, an
interrupted build. A test suite that only ever ran against a healthy machine would tell us
nothing about the cases the spec exists to handle.

**Organization**: Tasks are grouped by user story so each story can be implemented, tested,
and shipped independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete work)
- **[Story]**: Which user story the task serves (US1, US2, US3)

## Path Conventions

Paths follow plan.md's Structure Decision: the shipped package is `extension/`, fixtures
live in `tests/fixtures/`, and repository-level gates live in `scripts/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the package skeleton so every later task has somewhere to write.

- [X] T001 Create the package directory tree `extension/{commands,scripts/bash,scripts/powershell}/` per plan.md Structure Decision
- [X] T002 [P] Write `extension/extension.yml` exactly as fixed by `contracts/extension-manifest.md`, with id `llm-wiki-graphify`, version `1.0.0`, effect `read-write`, and the single opt-in `after_specify` hook at priority 20
- [X] T003 [P] Write `extension/config-template.yml` with `scope.root`, `graphify.min_version` (`0.9.9`), `graphify.max_version` (`0.10.0`), and `report.show_top_communities` — and **no** `scope.exclude`, which research R13 removed because the tool ignores exclusions entirely
- [X] T004 [P] Copy `LICENSE` (MIT) into `extension/` and write `extension/CHANGELOG.md` in Keep a Changelog format with an `Unreleased` section
- [X] T005 Verify `python scripts/validate-extension.py extension` passes on the skeleton, and that `bash scripts/check-placeholders.sh` reports no `CUSTOMIZE:` markers in `extension/` — markers belong only to `template/` (Principle III)

**Checkpoint**: The manifest parses and the repository's existing gates accept the package.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The dependency check and the script scaffolding every user story invokes.
No user story can start before this phase completes.

⚠️ **Blocking**: Phases 3–5 all depend on this phase.

- [X] T006 Implement argument parsing and the structured key/value stdout emitter in `extension/scripts/bash/graph-build.sh` per `contracts/build-script.md`, including the four modes (`check`, `scope`, `build`, `status`) and exit code 2 for an unknown argument or a `build` without `--confirmed`
- [X] T007 Implement the version parser in `extension/scripts/bash/graph-build.sh`: parse `X.Y.Z` from `graphify --version` (observed format `graphify 0.9.9`) using a POSIX-portable expression — **not** `sed -E` with `\s`, which BSD sed silently ignores and which already broke `scripts/install-test.sh` in this repository
- [X] T008 Implement `check` mode in `extension/scripts/bash/graph-build.sh`: resolve on `PATH` (absent → exit 4), parse the version (unparseable → exit 5, **failing closed**, never treated as new enough), compare against both floor and ceiling (outside → exit 5 reporting version found and range required), and create nothing on any failure path
- [X] T009 [P] Create fixture `tests/fixtures/graph-build-code/` — two Python files producing the known counts from research R2 (5 nodes, 7 links) — and `tests/fixtures/graph-build-empty/` containing nothing the tool can read
- [X] T010 [P] Create fixture `tests/fixtures/graph-build-mixed/graphify-out/graph.json` — a committed graph whose `links[].confidence` values include `EXTRACTED`, `INFERRED`, and `AMBIGUOUS` in known proportions, generated as described in research R15. This is the one graph in the repository that is deliberately committed rather than derived; note that in a `README` beside it so a future reader does not delete it as a stray build output
- [X] T011 [P] Create `scripts/test-graph-build.sh` following the existing `scripts/test-validator.sh` pattern, with an assertion helper that checks **both** the exit code and the `outcome=` line — asserting only "non-zero" would let a test for a missing dependency pass against a merely empty project
- [X] T012 Write the failing-first assertions for the dependency paths in `scripts/test-graph-build.sh`: `PATH` set to an empty directory expects exit 4 and no `graphify-out/` created anywhere; a stub binary printing `graphify 0.0.1` expects exit 5 reporting both `0.0.1` and the required range; a stub printing an unparseable string expects exit 5. Run them and **watch each one fail** before T008 is considered done

**Checkpoint**: The dependency check works and has been observed rejecting all three failure
modes. User story implementation can begin.

---

## Phase 3: User Story 1 — Build a graph for a project that has none (Priority: P1) 🎯 MVP

**Goal**: A maintainer with no graph gets one, having been told what would be examined and
having agreed to it, and receives a report that states what was and was not interpreted.

**Independent Test**: In a project where no graph has ever been built, run the command and
confirm a graph is produced, the scope was reported before any work started, and the report
carries entity and relationship counts, the evidence breakdown, and the coverage statement.

- [X] T013 [US1] Implement `scope` mode in `extension/scripts/bash/graph-build.sh`: resolve the root, reject any path escaping the project root, report the file count, and state that **no exclusions are applied** — reporting exclusions the tool ignores would be a false statement about what was read (research R13)
- [X] T014 [US1] Implement `build` mode's invocation core in `extension/scripts/bash/graph-build.sh`: change directory to the resolved scope root **before** invoking the tool (research R11 — the tool writes `manifest.json` into the working directory while writing the graph to the target path), invoke `graphify update <path>`, and pass the tool's own output through to stderr unmodified
- [X] T015 [US1] Implement outcome classification in `extension/scripts/bash/graph-build.sh`: a rebuild line → `built`, `No code-graph topology changes detected` → `current` (research R5), a tool failure → `failed` exit 8, and an empty scope → `nothing-to-examine` exit 3, which is **not** success (FR-013)
- [X] T016 [US1] Implement graph counting in `extension/scripts/bash/graph-build.sh`: entities from `nodes`, relationships from **`links`** — not `edges`, which does not exist and silently yields zero (research R4) — plus the breakdown by `links[].confidence` with each label reproduced verbatim
- [X] T017 [US1] Assert in `scripts/test-graph-build.sh` that a build against `tests/fixtures/graph-build-code/` reports exactly 5 entities and 7 relationships with `evidence_EXTRACTED=7`, and that a build against `tests/fixtures/graph-build-empty/` exits 3 — watch the empty case fail if it is ever made to exit 0
- [X] T018 [US1] Write `extension/commands/build.md` frontmatter and the normative step sequence from `contracts/build-command.md`: dependency check, scope report, confirmation, build, report, handoff offer — with both `scripts.sh` and `scripts.ps` declared
- [X] T019 [US1] Implement the confirmation step in `extension/commands/build.md`: ask explicitly and wait; treat absence of an answer as a decline; report `declined` and write nothing. The step MUST NOT be skipped when the command was reached through the `after_specify` hook — that is the path where an unrequested build would be most surprising
- [X] T020 [US1] Implement report rendering in `extension/commands/build.md`: outcome first, counts, evidence breakdown with labels verbatim and never summed into a single total (FR-012, Principle XVIII), output location, elapsed time, and the backup path when the tool created one
- [X] T021 [US1] Implement the coverage statement in `extension/commands/build.md` (FR-013a, SC-008): every completed build states that code was interpreted, that documents, papers, and images were not and require the maintainer's own graphify skill pass, and that no exclusions were applied
- [X] T022 [US1] Implement the handoff offer in `extension/commands/build.md` (FR-013b): when the scope contained prose documents, offer the model-assisted pass as an explicit, declinable next step naming the command that performs it — never run it, and never make the build's success conditional on it
- [X] T023 [US1] Assert boundaries in `scripts/test-graph-build.sh`: after a build, `git status --porcelain` shows no `graphify-out/` entries, and `spec.md`, `plan.md`, and `tasks.md` are byte-for-byte unchanged (FR-015, FR-016, SC-006) — FR-016 is the one a passing build never surfaces on its own
- [X] T024 [US1] Assert in `scripts/test-graph-build.sh` that `build` without `--confirmed` exits 2 having written nothing (FR-006, SC-007). If this ever exits 0, the confirmation requirement does not exist regardless of what the command prose says

**Checkpoint**: User Story 1 is independently deliverable. A maintainer can build a graph
and knows exactly what is in it.

---

## Phase 4: User Story 2 — Refresh a graph after the project changed (Priority: P2)

**Goal**: Refreshing is cheap, honest about what moved, and refuses to proceed from a
damaged or contended state.

**Independent Test**: Build a graph, add a file, refresh, and confirm the new entity appears
in both the graph and the delta while unchanged parts are not rebuilt.

- [X] T025 [US2] Implement `--full` mode in `extension/scripts/bash/graph-build.sh`: remove **exactly** `graphify-out/graph.json` and then invoke the same `update` command. There is no `--full` flag on the tool (`error: unknown update option: --full`) and `--force` is not equivalent — it left outputs untouched on an unchanged corpus (research R10). Remove nothing else: `cache/`, `manifest.json`, and the dated backups must survive, or a rebuild becomes data loss
- [X] T026 [US2] Implement delta reporting in `extension/scripts/bash/graph-build.sh`: capture the previous counts before the run and report added, changed, and removed against them (FR-011)
- [X] T027 [US2] Implement interrupted-state detection in `extension/scripts/bash/graph-build.sh`: `graphify-out/manifest.json` present with `graphify-out/graph.json` absent (research R12) → exit 7, naming the state and requiring a `--full` run. Never refresh from an incomplete graph
- [X] T028 [US2] Implement locking in `extension/scripts/bash/graph-build.sh`: atomically create `build.lock/` under `.specify/extensions/llm-wiki-graphify/` — **never** under `graphify-out/`, which the tool owns and where a lock would make the natural implementation a Principle XVII violation. Record the owning process identifier and a start timestamp; release on every exit path including interruption
- [X] T029 [US2] Implement stale-lock reclamation in `extension/scripts/bash/graph-build.sh`: a lock whose owning process no longer exists is reclaimed with a reported warning. Without this, one crash disables the command permanently — a safety mechanism that becomes an availability failure
- [X] T030 [US2] Assert the no-change refresh in `scripts/test-graph-build.sh`: a second consecutive run reports `outcome=current` with the tool's own line passed through, and modifies nothing (FR-008)
- [X] T031 [US2] Assert the full rebuild in `scripts/test-graph-build.sh`: after `--full`, the counts match a from-scratch build **and** `cache/`, `manifest.json`, and any dated backup directory still exist
- [X] T032 [US2] Assert the interrupted and contended states in `scripts/test-graph-build.sh`, constructing each deterministically: delete `graph.json` and expect exit 7; pre-create `build.lock/` and expect exit 6; write a lock naming a dead process and expect reclamation. A test that depends on landing a signal in the right millisecond is a test that gets skipped
- [X] T033 [US2] Assert the non-default scope root in `scripts/test-graph-build.sh`: build with `--path sub` and confirm `sub/graphify-out/` exists while the parent directory has none (research R11). Every other assertion uses the default root and would never catch this

**Checkpoint**: The graph is maintainable, and the two states that could corrupt it are
refused rather than absorbed.

---

## Phase 5: User Story 3 — Understand immediately why a build cannot run (Priority: P3)

**Goal**: Every failure names what is missing and the step that resolves it, in a message a
stranger can act on without reading the source.

**Independent Test**: With the tool absent, run the command and confirm it stops, names the
dependency and its install step, and produces no output directory.

- [X] T034 [US3] Implement the dependency failure messages in `extension/commands/build.md`: `dependency-missing` names the tool and the exact install step; `dependency-too-old` reports the version found alongside the range required. Never install anything on the maintainer's behalf (FR-003)
- [X] T035 [US3] Implement `status` mode in `extension/scripts/bash/graph-build.sh`: report whether a graph exists, when it was built, its counts, and its evidence breakdown. Build nothing, and exit 0 whether or not a graph exists — absence is a state, not an error
- [X] T036 [US3] Implement the no-graph behaviour in `extension/commands/build.md` (FR-023): state that no graph exists and offer to build one, without blocking or gating the step the maintainer was performing
- [X] T037 [US3] Assert message distinctness in `scripts/test-graph-build.sh` (SC-005): collect the message for all nine outcomes and assert no two are identical. Nine distinguishable outcomes is why a stranger can act on a failure; success-or-failure is why they would open an issue instead
- [X] T038 [US3] Assert in `scripts/test-graph-build.sh` that no failure path creates `graphify-out/` (FR-004) — the absence of the directory is half of what the requirement demands, and the half a passing check silently skips

**Checkpoint**: All three user stories are complete and independently verifiable.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T039 [P] Port every mode to `extension/scripts/powershell/graph-build.ps1` at behavioural parity per `contracts/build-script.md`: identical `outcome` values, identical exit codes, identical stdout key set. Use an atomically-created directory for the lock, which is atomic on Windows filesystems too
- [X] T040 Add a Windows job to `.github/workflows/ci.yml` running `scripts/test-graph-build.sh`'s PowerShell equivalent against the same fixtures. **Parity claimed without a Windows run is parity assumed** — Principle XV forbids trusting a check nobody has watched, and no Windows machine is available locally, so CI is the only honest path to verifying it
- [X] T041 [P] Write `extension/README.md` leading with the command, and documenting: the supported graphify range `>=0.9.9,<0.10.0` and why the ceiling exists, that the deterministic build is local-only while the model-assisted pass sends content to whichever backend the maintainer's graphify uses, that v1 builds a code graph, and that exclusions are unavailable
- [X] T042 [P] Add the `graph-build` job to `.github/workflows/ci.yml` running `scripts/test-graph-build.sh`, with graphify installed at a pinned version so the suite tests the version the contracts were verified against
- [ ] T043 Run the Principle VII install cycle from quickstart.md against a real Spec Kit project: `add --dev` → `list` → `info` → execute the command and the hook at least once each → `remove`. An install that was never exercised proves only that the YAML parses
- [ ] T044 Update the root `CHANGELOG.md` and `extension/CHANGELOG.md` with the `1.0.0` entry, and update the root `README.md` to describe the shipped command rather than describing the extension as under construction
- [ ] T045 Verify SC-003 by timing a refresh against a full rebuild on a project large enough for the ratio to be meaningful, and record both timings in `specs/002-graph-build-command/research.md` as R16. A refresh that silently performs a full rebuild is otherwise indistinguishable from a correct one, so the number is the evidence — not the impression that it felt fast
- [ ] T046 Verify SC-009 by having someone unfamiliar with the feature read a build report and state whether their documentation is in the graph, recording who was asked and what they answered in `specs/002-graph-build-command/research.md` as R17. The criterion exists because the wrong answer is always "yes, it is in there", and only a real reader can falsify it. If this cannot be run, mark SC-009 unverified in `specs/002-graph-build-command/checklists/requirements.md` rather than assuming it holds

---

## Dependencies & Execution Order

```text
Phase 1 (Setup)
    ↓
Phase 2 (Foundational — dependency check + fixtures + assertion harness)
    ↓
    ├─────────────────┬─────────────────┐
    ↓                 ↓                 ↓
Phase 3 (US1/P1)  Phase 4 (US2/P2)  Phase 5 (US3/P3)
    │                 │                 │
    └─────────────────┴─────────────────┘
                      ↓
              Phase 6 (Polish)
```

**Story independence**: US1 is fully independent once Phase 2 lands. US2 shares the script
file with US1 and so is sequenced after it in practice, though its behaviour is
independently testable. US3 depends on Phase 2's dependency check and on US1 only for the
command file it extends.

**Release gates that no task can close early**: T043 satisfies Principle VII; Principle XII
(every distribution form verified in the *published* artifact) is a release activity that
happens after this feature merges. Both are recorded as DEFERRED in plan.md rather than
marked passed, because a design document cannot satisfy either.

## Parallel Opportunities

**Phase 1**: T002, T003, T004 touch different files and can run together.

**Phase 2**: T009, T010, T011 are independent — two fixture sets and the assertion harness.

**Phase 6**: T039, T041, T042 are independent — the PowerShell port, the README, and the CI
job.

Within Phases 3–5 most tasks edit the same two files (`graph-build.sh` and `build.md`), so
they are sequential by necessity rather than by dependency.

## Implementation Strategy

**MVP**: Phase 1 + Phase 2 + Phase 3 (US1). That delivers a working, honest build command:
it verifies its dependency, asks before spending the maintainer's time, produces a graph,
and reports what is and is not in it. Everything after that is refinement of a thing that
already works.

**Increment 2**: Phase 4 (US2) makes the graph maintainable rather than disposable.

**Increment 3**: Phase 5 (US3) sharpens the failure messages — the last mile for a plugin
strangers install.

**Before release**: Phase 6. Note that T040 and T046 cannot be completed by the author
alone at a keyboard — one needs Windows CI, the other needs another person. Scheduling them
as "polish" is deliberate, not dismissive: they are the two claims most likely to be
quietly assumed rather than checked.

## Completion notes

Recorded honestly rather than by ticking everything that looked adjacent.

- **T040** — the Windows CI job and `scripts/test-graph-build.ps1` are written and the
  suite passes (24/24) on PowerShell Core under macOS. That is **not** parity on Windows:
  path separators, `Get-Process`, and filesystem semantics all differ. The claim is settled
  when the CI job runs, not before.
- **T043** — `scripts/install-test.sh` passes for both packages: add → list → info →
  remove. Principle VII also requires every declared command and hook to be executed at
  least once inside an installed project, and that has not been done. The task stays open
  until it is.
- **T045 / T046** — open by nature. SC-003 needs a project large enough for the ratio to
  mean something; SC-009 needs a person who has never seen this feature. Neither can be
  closed by the author at a keyboard, which is exactly why they were scheduled rather than
  assumed.

Two tasks changed shape during implementation, because the research they rested on turned
out to be incomplete — see `research.md` R16 and R17. T015's outcome classification now
reads graphify's own output instead of counting files, and T021's coverage statement says
that document *structure* is extracted rather than claiming documents were skipped.

## Task Count

| Phase | Tasks |
|---|---|
| 1 — Setup | 5 |
| 2 — Foundational | 7 |
| 3 — US1 (P1) | 12 |
| 4 — US2 (P2) | 9 |
| 5 — US3 (P3) | 5 |
| 6 — Polish | 8 |
| **Total** | **46** |
