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

**Primary Dependencies**: `graphify` CLI `>=0.9.9`, installed by the maintainer and never
provisioned by this extension (Principle XVI, FR-003). Python is a transitive dependency
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
graphs themselves range from a handful of nodes to tens of thousands; the extension never
holds a graph in memory beyond a single counting pass over `graph.json`.

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
| XV. A check that cannot fail is not a check | Every gate observed failing before being trusted | PASS | PASS — the three dependency failures and the empty-project case each get a fixture that makes them fail; see [quickstart.md](quickstart.md) |
| XVI. Graphify is a dependency | Delegate; detect; never vendor; never auto-install | PASS | PASS — R1–R3 fix the delegation boundary at the one the tool declares |
| XVII. Derived artifacts never committed or hand-edited | `graphify-out/` git-ignored; never edited | PASS — already in `.gitignore` | PASS |
| XVIII. Provenance survives every hop | Evidence labels preserved unchanged | PASS | PASS — read from `links[].confidence` (R4), reported as a breakdown, never collapsed |
| XIX. Graph serves the lifecycle | No core command bypassed or gated; no unprompted build | PASS | PASS — R8 places confirmation in the agent layer; the hook is opt-in and declinable |

**Verdict**: No violations. Complexity Tracking is therefore empty and has been removed.

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
└── checklists/
    └── requirements.md  # Spec quality checklist (16/16)
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
└── config-template.yml             # scope root, exclusions, version floor

tests/
└── fixtures/
    ├── graph-build-empty/          # a project with nothing to examine
    └── graph-build-code/           # a small code project with known node/edge counts

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
- **Phase 2** — `tasks.md`, produced by `/speckit-tasks`, not by this command.
