# Phase 1 Data Model: Graph Build Command

**Feature**: 002-graph-build-command
**Date**: 2026-07-22

This extension owns almost no data. The graph belongs to graphify; what follows separates
the few structures the extension does own from the ones it only reads, because confusing
the two is how a derived artifact ends up hand-edited (Principle XVII).

---

## Owned by this extension

### BuildConfig

Read from `.specify/extensions/llm-wiki-graphify/config.yml` in the consuming project.
The file is optional; every field has a default, and a missing file is not an error
(Principle I, `required: false`).

| Field | Type | Default | Validation |
|---|---|---|---|
| `scope.root` | path, relative to project root | `.` | MUST resolve inside the project root; a path escaping it is rejected before any build |
| `scope.exclude` | list of glob patterns | `[]` | Patterns are reported in the scope summary, never applied silently (FR-005) |
| `graphify.min_version` | version string | `0.9.9` | MUST be a plain `X.Y.Z`; lowering it below the verified floor is rejected |
| `report.show_top_communities` | integer | `5` | `0` disables the section; negative is rejected |

**State**: none. The config is read once per invocation and never written by the
extension.

### BuildRequest

Constructed in memory by the command before invoking a script. It exists so that the
confirmation in FR-005 is about something concrete.

| Field | Type | Notes |
|---|---|---|
| `root` | absolute path | Resolved from `scope.root` |
| `mode` | `full` \| `refresh` | `full` re-examines everything; `refresh` delegates to the tool's incremental path |
| `confirmed` | boolean | MUST be true before a script runs. The script's contract requires the caller to assert this explicitly (research R8), so an unconfirmed build cannot occur by omission |
| `file_count` | integer | Reported to the maintainer before confirmation, never after |
| `exclusions` | list of glob patterns | Echoed in the scope summary |

### BuildOutcome

The classification of a run. Its whole purpose is SC-005: seven outcomes, no two
producing the same message. This is an enumeration, not a boolean, precisely because
"succeeded / did not succeed" is what collapses "nothing to examine" into "success".

| Value | Meaning | Exit code |
|---|---|---|
| `built` | A graph was produced or replaced | 0 |
| `current` | Refresh ran; the tool reported no topology change | 0 |
| `nothing-to-examine` | The scope contained nothing the tool can read | 3 |
| `declined` | The maintainer declined confirmation; nothing ran | 0 |
| `dependency-missing` | The tool does not resolve on `PATH` | 4 |
| `dependency-too-old` | The tool resolves but is below the floor | 5 |
| `already-running` | Another build holds the lock | 6 |
| `interrupted-state` | A previous run left an incomplete graph | 7 |
| `failed` | The tool ran and reported failure | 8 |

Distinct non-zero codes exist so an automated check can assert *which* failure occurred.
A single code `1` would let a test for "missing dependency" pass on a machine where the
project was merely empty — a check that cannot fail for the right reason (Principle XV).

### BuildReport

The human-facing summary. Rendered by the command, never written to disk by the
extension.

| Field | Source | Notes |
|---|---|---|
| `outcome` | BuildOutcome | Always stated first |
| `entity_count` | `len(graph["nodes"])` | Omitted for non-`built` outcomes |
| `relationship_count` | `len(graph["links"])` | **`links`, not `edges`** — research R4 |
| `evidence_breakdown` | count of `links[].confidence` by value | Labels reproduced verbatim: `EXTRACTED`, `INFERRED`, `AMBIGUOUS` (FR-012, SC-004) |
| `delta` | added / changed / removed vs. previous | Refresh only (FR-011) |
| `output_location` | fixed | `graphify-out/` |
| `elapsed` | measured | Wall clock of the tool invocation |
| `non_code_notice` | fixed | Present whenever code was processed: states that docs, papers, and images require the maintainer's graphify skill pass (research R3) |
| `excluded` | BuildRequest.exclusions | What was skipped, and why |

---

## Read but not owned

### ProjectGraph (`graphify-out/graph.json`)

Produced by graphify. Node-link JSON. The extension reads it for counting and never
writes it.

Top-level keys observed on graphify 0.9.9: `directed`, `multigraph`, `graph`, `nodes`,
`links`, `hyperedges`.

**Node** — observed fields: `label`, `file_type`, `source_file`, `source_location`,
`_origin`, `id`, `community`, `norm_label`.

**Link** — observed fields: `relation`, `confidence`, `confidence_score`, `context`,
`source`, `target`, `source_file`, `source_location`, `weight`.

### EvidenceLabel

Not a structure the extension defines — a value it must not alter. Read from
`links[].confidence`.

| Value | Meaning | Permitted use downstream |
|---|---|---|
| `EXTRACTED` | Read directly from a source file | May be stated as fact |
| `INFERRED` | Produced by a model, with `confidence_score` | May raise a question or a `[NEEDS CLARIFICATION]` marker; MUST NOT become a requirement |
| `AMBIGUOUS` | Flagged for human review | MUST direct a human to the source; MUST NOT be resolved by the extension |

A pure AST run yields only `EXTRACTED` (research R4). The other two appear once the
model-assisted pass has run, which is why the report must show the breakdown rather than a
total: a graph that is 100% `EXTRACTED` and one that is 40% `INFERRED` are different
objects, and a single relationship count cannot tell them apart.

### Tool-owned outputs

`graphify-out/` contains `graph.json`, `graph.html`, `GRAPH_REPORT.md`, `manifest.json`,
`cache/`, and dated backup directories the tool creates before replacing a curated graph.
All of it is derived, git-ignored, never hand-edited, and never written by this extension
(Principle XVII, FR-015, FR-018).

---

## Relationships

```text
BuildConfig ──validates──▶ BuildRequest ──authorises──▶ graphify update
                                                              │
                                                              ▼
                                                        ProjectGraph
                                                         (tool-owned)
                                                              │
                                                        read-only
                                                              ▼
BuildOutcome ────────────────────────────────────────▶ BuildReport
                                                              ▲
                                                     EvidenceLabel
                                                    (carried unchanged)
```

The arrow that matters is the read-only one. Nothing in this feature draws an arrow back
into `ProjectGraph` from the extension side, and that absence is the design.
