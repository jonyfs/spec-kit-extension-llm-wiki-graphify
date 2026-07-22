# Implementation Plan: Graph Build Command

**Branch**: `feat/002-graph-build-command` | **Date**: 2026-07-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-graph-build-command/spec.md`

## Summary

Ship `speckit.llm-wiki-graphify.build`, the first command of the extension: it verifies
the maintainer's graphify installation, reports what a build would examine, obtains
confirmation, delegates the build to `graphify update <path>`, and reports the outcome
with evidence labels intact.

The technical approach follows from one research finding: **there is no `graphify build`
subcommand** (research R1). The deterministic, scriptable entry point is
`graphify update <path>`, which was verified to build from scratch as well as refresh
(R2), and which explicitly hands non-code content back to the maintainer's own graphify
skill (R3). The design therefore splits along the boundary the tool itself draws — the
scripts do the deterministic code build, and the command prose delegates the model-assisted
pass rather than reconstructing it.

## Technical Context

**Language/Version**: Bash (POSIX-compatible, macOS BSD and GNU userland) and PowerShell
5.1+ / PowerShell Core 7+, at parity per Principle V. Command logic is Markdown with YAML
frontmatter, executed by the agent harness.

**Primary Dependencies**: `graphify` CLI `>=0.9.9,<0.10.0`, installed by the maintainer
and never provisioned by this extension (Principle XVI, FR-003). The ceiling is required,
not cautious: the dependency is pre-1.0 and promises no compatibility between minor
versions, while every field these contracts read was observed in exactly one version
(research R14). Python is a transitive dependency
of graphify and is never invoked directly by this extension.

**Storage**: None owned. Configuration is read from
`.specify/extensions/llm-wiki-graphify/config.yml` and must tolerate absence. All graph
output belongs to `graphify-out/`, which the tool owns and `.gitignore` excludes.

**Testing**: Shell-level assertions over real invocations in disposable fixture projects,
plus the repository's existing `scripts/validate-extension.py`,
`scripts/check-placeholders.sh`, and `scripts/install-test.sh` gates. Every failure path
must be observed failing, not assumed (Principle XV).

**Target Platform**: Any machine running a Spec Kit project — macOS, Linux, and Windows.

**Project Type**: Spec Kit extension package (a manifest, command Markdown, and paired
scripts).

**Performance Goals**: A refresh on a project where under 5% of files changed completes in
under 25% of the full build's time (SC-003) — satisfied by delegating to the tool's own
incremental path rather than by optimisation work here.

**Constraints**: No network access of our own; no writes outside the two owned
directories; no prompting from scripts (R8); no parsing of graph internals beyond the
documented node-link fields (R4).

**Scale/Scope**: One command, one config file, two script variants, one opt-in hook. The
counting pass loads the whole graph, measured at 0.65 s for 50,000 nodes and 200,000 links
(45.7 MB) — far beyond typical output, so no streaming parser is warranted (research R15).

**Distribution**: This is a **publicly maintained plugin**, not an internal tool. Three
consequences bind the implementation rather than merely colouring it. First, the version
ceiling on a pre-1.0 dependency stops being cautious and becomes necessary — an upstream
release would otherwise break installations the author cannot see or fix (research R14).
Second, Principle XII's distribution matrix must be proven in the published artifact, not
the working tree, before any catalog entry. Third, every message is read by someone who
cannot ask a follow-up question, which is the reason the outcome vocabulary is nine
distinguishable values rather than success-or-failure.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluated against constitution v2.0.0. Pre-research and post-design verdicts are both
recorded; nothing changed between them, and the reasons are stated rather than asserted.

| Principle | Gate | Pre-research | Post-design |
|---|---|---|---|
| I. Manifest is the contract | `extension.yml` complete; every referenced path exists; `requires.speckit_version` a spaceless specifier | PASS (planned) | PASS — [contracts/extension-manifest.md](contracts/extension-manifest.md) fixes every field |
| II. Namespaced commands | `speckit.llm-wiki-graphify.build`; no core shadowing | PASS | PASS |
| III. Placeholders | No `CUSTOMIZE:` markers in the shipped package | PASS | PASS — markers are confined to `template/`, which this feature does not touch |
| IV. Hooks opt-in | Any hook `optional: true`, with prompt and description, explicit `priority` | PASS | PASS — one hook, `after_specify`, opt-in |
| V. Script parity | bash and powershell variants, referenced from frontmatter | PASS | PASS — [contracts/build-script.md](contracts/build-script.md) is one contract binding both |
| VI. Additive, non-destructive | Writes confined to owned directories; no git operations | PASS | PASS — FR-015 through FR-017 |
| VII. Install-test before publish | `add --dev` → `list` → run → `remove` before any tag | DEFERRED to implementation | DEFERRED — a release gate, not a design gate |
| VIII. Versioning and changelog | `1.0.0` at first release; `CHANGELOG.md` entry in the same change | PASS | PASS |
| IX. English artifacts | Every shipped file in English | PASS | PASS |
| X. Compressed conversation, full artifacts | Artifacts in conventional prose | PASS | PASS |
| XI. Hook literacy | Lifecycle hooks only; no harness hook installed or modified | PASS | PASS — this feature installs no harness hook |
| XII. Distribution forms | Every claimed form verified before release | DEFERRED to release | DEFERRED |
| XIII. Proactive extension use | Installed extensions routed to when they apply | PASS | PASS |
| XIV. Trunk-based delivery | Short-lived branch, PR, green CI | PASS — on `feat/002-graph-build-command` | PASS |
| XV. A check that cannot fail is not a check | Every gate observed failing before being trusted | PASS | PASS — every failure path is constructed deterministically rather than raced or assumed: an empty `PATH` for absence, a stub binary for an old version, a deleted `graph.json` for the interrupted state, a pre-created lock for concurrency, and a committed mixed-label fixture for provenance. See [quickstart.md](quickstart.md) |
| XVI. Graphify is a dependency | Delegate; detect; never vendor; never auto-install | PASS | PASS — R1–R3 fix the delegation boundary at the one the tool declares |
| XVII. Derived artifacts never committed or hand-edited | `graphify-out/` git-ignored; never edited | PASS — already in `.gitignore` | PASS |
| XVIII. Provenance survives every hop | Evidence labels preserved unchanged | PASS | PASS — read from `links[].confidence` (R4), reported as a breakdown, never collapsed |
| XIX. Graph serves the lifecycle | No core command bypassed or gated; no unprompted build | PASS | PASS — R8 places confirmation in the agent layer; the hook is opt-in and declinable |

**Verdict**: No violations. Complexity Tracking is therefore empty and has been removed.

The post-design column was re-evaluated after the critique. One row changed materially:
XVII, where `full` mode's deletion of `graphify-out/graph.json` is a write into the
tool-owned directory. It remains PASS because deleting a derived artifact to force
regeneration is what the principle contemplates, while editing one is what it forbids —
but the exception is now narrow, documented, and enumerated in the script contract's
prohibitions rather than left implicit.

Two gates are deferred rather than passed, and the distinction is deliberate: VII and XII
are *release* gates that cannot be satisfied by a design document, only by an executed
install-run-remove cycle against a built package. Recording them as PASS here would be
exactly the empty green Principle XV describes.

## Project Structure

### Documentation (this feature)

```text
specs/002-graph-build-command/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output — all findings verified against graphify 0.9.9
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output — validation scenarios, including the failing ones
├── contracts/           # Phase 1 output
│   ├── extension-manifest.md
│   ├── build-command.md
│   └── build-script.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (16/16)
└── critiques/
    └── critique-2026-07-22.md  # Dual-lens review; its findings are folded in above
```

### Source Code (repository root)

```text
extension/                          # the shipped llm-wiki-graphify package
├── extension.yml                   # manifest — id, commands, hooks, config
├── README.md                       # install, usage, the supported graphify version
├── LICENSE                         # MIT
├── CHANGELOG.md                    # Keep a Changelog
├── commands/
│   └── build.md                    # speckit.llm-wiki-graphify.build
├── scripts/
│   ├── bash/
│   │   └── graph-build.sh
│   └── powershell/
│       └── graph-build.ps1
└── config-template.yml             # scope root and supported graphify version range

tests/
└── fixtures/
    ├── graph-build-empty/          # a project with nothing to examine
    ├── graph-build-code/           # a small code project with known node/edge counts
    └── graph-build-mixed/          # a committed graph.json carrying all three evidence
                                    # labels; the scripted build emits only EXTRACTED, so
                                    # provenance coverage cannot be proven without it

scripts/
└── test-graph-build.sh             # asserts each failure path actually fails
```

**Structure Decision**: The shipped package lives at `extension/`, a sibling of the
inherited `template/` reference extension. Both are discovered by the existing CI gates,
which locate packages with `find -name extension.yml` (research R9), so the choice costs
nothing mechanically and keeps the two visibly distinct — necessary because Principle III
now means opposite things in the two directories: `template/` must carry placeholder
markers, `extension/` must carry none.

`tests/fixtures/` already exists for the inherited validator tests and is extended rather
than duplicated. `scripts/test-graph-build.sh` follows the existing
`scripts/test-validator.sh` pattern of asserting that a check rejects what it should
reject, for the reason it should reject it.

## Phase Outputs

- **Phase 0** — [research.md](research.md). Nine findings, each produced by running
  graphify 0.9.9 rather than by recall. R1 (no `build` subcommand) reshaped the design;
  R4 records that the edge array is named `links`, not `edges`, which is the trap most
  likely to produce a graph reported as empty-but-successful.
- **Phase 1** — [data-model.md](data-model.md), the three contracts under
  [contracts/](contracts/), and [quickstart.md](quickstart.md).
- **Post-critique** — [critiques/critique-2026-07-22.md](critiques/critique-2026-07-22.md)
  found four must-address items, three sharing one root cause: the research had verified
  the happy path and generalised from it. Five further probes became R10–R14 and corrected
  claims that could not have survived implementation — a `--full` flag that does not
  exist, a tool that writes to two directories, and a `scope.exclude` setting the tool
  ignores entirely. Every correction is recorded as evidence in `research.md` rather than
  as a silent edit.
- **Phase 2** — `tasks.md`, produced by `/speckit-tasks`, not by this command.
