# Implementation Plan: Installed Extension Validation

**Branch**: `feat/003-installed-extension-validation` | **Date**: 2026-07-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-installed-extension-validation/spec.md`

## Summary

Add a validation harness that installs the `llm-wiki-graphify` package into a throwaway
Spec Kit project created by the `specify` CLI, exercises the registered command's underlying
script and the aggregated hook, tests the three configuration states, removes the extension,
and reports a three-state result — passed, failed, or skipped-with-reason. This is the layer
above the feature-002 script suites: they test the scripts in isolation, this tests the
package **as installed**, and closes Constitution Principle VII.

The approach is fixed by six findings from running the CLI (research R1–R6). Two are
load-bearing:

- **The command is agent-executed prose, not a shell entry point** (R3). "Invoke the
  command" at the shell level means invoking the script it delegates to, at its installed
  path, and asserting the same observable results. The plan says so rather than overstating.
- **The script does not yet read a project `config.yml`** — verified, not assumed: `grep`
  found no config read in `graph-build.sh`, and the defaults are compiled in (R4). US3's
  config-honouring scenarios therefore depend on a small feature-002 follow-up. This is a
  surfaced prerequisite, not hidden scope, and until it exists those scenarios must be
  reported as **failing** — the manifest declares the config, so an unmet promise is a
  failure, not a skip.

## Technical Context

**Language/Version**: Bash and PowerShell, matching the two runners the existing gates use.
The harness is a shell script, not a new language runtime — the project has no test
framework and adding one for this would be unjustified complexity.

**Primary Dependencies**: the `specify` CLI (already a dependency of `install-test.sh`) and,
for the build-execution scenarios only, graphify `>=0.9.9,<0.10.0`. When graphify is absent,
those scenarios are skipped, not failed (FR-010).

**Storage**: none. Each run works entirely inside a `mktemp -d` throwaway project and
removes it on exit.

**Testing**: the harness *is* the test. It is itself validated the way feature 002's suites
were — by broken-package fixtures that each assertion must be observed failing against
(FR-012, SC-002).

**Target Platform**: Linux and Windows CI runners, plus a maintainer's machine.

**Project Type**: a validation harness for a Spec Kit extension package. No product code
changes; `extension/` is not touched by this feature.

**Performance Goals**: a full run in under 5 minutes of wall clock (SC-003), dominated by
`specify init` and one real graph build.

**Constraints**: never writes outside the throwaway project (SC-004); cleans up on every
exit path including interruption (FR-004); reports three states, never a bare pass/fail
(FR-011).

**Scale/Scope**: one harness script per platform, a small set of broken-package fixtures,
and a CI job. No graphs larger than the feature-002 code fixture are built.

## Constitution Check

Evaluated against constitution v2.0.0. This feature is pure verification, which changes what
several gates mean.

| Principle | Gate | Verdict |
|---|---|---|
| I. Manifest is the contract | — | N/A — no manifest changes |
| II. Namespaced commands | — | N/A — no new commands |
| III. Reference-extension placeholders | — | N/A — touches neither `template/` nor `extension/` |
| IV. Hooks opt-in | — | N/A — declares no hooks |
| V. Script parity | Harness runs on both platforms | PASS — Linux and Windows CI, mirroring the feature-002 arrangement |
| VI. Additive, non-destructive | Writes confined; no git operations | PASS — writes only inside the throwaway project (SC-004) |
| VII. Install-test before publish | This feature *is* the mechanization of VII | PASS — and it is what lets VII finally be marked satisfied (SC-006) |
| VIII. Versioning | `CHANGELOG.md` entry | PASS — a root changelog entry lands with the harness |
| IX. English | — | PASS |
| X. Compressed conversation, full artifacts | — | PASS |
| XI. Hook literacy | Installs no harness hook | PASS — the CI job runs the harness; it modifies no `.claude/` or `.codex/` config |
| XII. Distribution forms | — | Deferred — this validates the local-directory form; archive and catalog remain release-time |
| XIII. Proactive extension use | — | N/A |
| XIV. Trunk-based delivery | Branch, PR, green CI | PASS — on `feat/003-installed-extension-validation` |
| XV. A check that cannot fail is not a check | Every assertion observed failing against a broken package | PASS — the whole point of the feature; FR-012, SC-002 |
| XVI. Graphify is a dependency | — | PASS — the harness never installs graphify; absence → skip |
| XVII. Derived artifacts | — | PASS — the throwaway project's `graphify-out/` is destroyed with it, never committed |
| XVIII. Provenance | — | PASS — the harness asserts labels survive; it does not alter them |
| XIX. Graph serves the lifecycle | — | N/A |

**Verdict**: No violations. Complexity Tracking is empty and removed.

The one gate worth dwelling on is **XV applied to the harness itself**. A validation harness
that has only ever run against a working package proves nothing — it could be a script that
prints "passed" unconditionally. So the broken-package fixtures are not optional extras;
they are how the harness earns trust, exactly as the mutation test earned trust for the
feature-002 suites.

## Project Structure

### Documentation (this feature)

```text
specs/003-installed-extension-validation/
├── plan.md
├── spec.md
├── research.md          # Six findings from running the specify CLI
├── contracts/
│   └── validation-harness.md
├── quickstart.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
scripts/
└── validate-installed-extension.sh    # the harness (Linux/macOS)
                                        # a .ps1 counterpart for the Windows runner

tests/
└── fixtures/
    └── broken-packages/
        ├── missing-command-file/       # manifest names commands/build.md; file removed
        ├── wrong-command-name/         # command name violates the namespace
        └── missing-script/             # frontmatter references a script that is absent

.github/workflows/ci.yml                # gains an installed-validation job on both runners
```

**Structure Decision**: The harness lives in `scripts/` beside the existing
`install-test.sh` and `test-graph-build.sh`, which it complements rather than replaces:
`install-test.sh` proves add→list→remove for every package generically; this proves the
`llm-wiki-graphify` command and hook actually function as installed. The broken-package
fixtures live under `tests/fixtures/broken-packages/` beside the existing
`invalid-extension/` fixture the manifest validator already uses, and follow the same "prove
the check rejects what it should" pattern as `scripts/test-validator.sh`.

## Dependency surfaced by research

US3 (configuration honoured) depends on the feature-002 script reading a project
`config.yml`, which it does not currently do (research R4, confirmed by inspection). Three
ways forward, to decide at `/speckit-tasks` or with the user:

1. **Sequence US3 behind a small feature-002 follow-up** that adds the config read. Cleanest;
   US3 then passes honestly.
2. **Ship US1 and US2 now, hold US3** until the config read exists. The harness is already
   valuable at that point — it closes Principle VII.
3. **Write US3's assertions now and let them fail** against the current script, as
   executable documentation of an unmet manifest promise. Consistent with Principle XV, but
   a red suite in CI needs a stated expiry.

The plan does not pick one silently; it records the choice as the first thing `/speckit-tasks`
must resolve.

## Phase Outputs

- **Phase 0** — [research.md](research.md). Six findings, each from a real CLI run. R3 and
  R4 changed the shape of the harness.
- **Phase 1** — [contracts/validation-harness.md](contracts/validation-harness.md) and
  [quickstart.md](quickstart.md).
- **Phase 2** — `tasks.md`, from `/speckit-tasks`.
