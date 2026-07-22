# Phase 0 Research: Graph Build Command

**Feature**: 002-graph-build-command
**Date**: 2026-07-22

Every finding below was produced by running the tool, not by recall. Constitution
Principle XVI requires the invocation surface to be verified against a stated version;
Principle XV requires that a check be observed failing, so the negative cases were run
too. Verified against **graphify 0.9.9** (`graphify --version`), installed at
`/Users/jony/.local/bin/graphify`.

---

## R1: There is no `graphify build` command

**Decision**: The full-corpus build is not available as a CLI subcommand and MUST NOT be
assumed. `graphify update <path>` is the only deterministic, scriptable entry point that
produces a graph.

**Evidence**: `graphify --help` lists `install`, `uninstall`, `path`, `explain`,
`diagnose`, `clone`, `merge-driver`, `merge-graphs`, `add`, `watch`, `update`,
`cluster-only`, `label`, `query`, `affected`, `save-result`, `reflect`, `check-update`,
and `tree`. No `build`. The full pipeline described in the tool's own documentation —
including model-assisted interpretation of docs, papers, and images — is driven by the
**agent skill**, which orchestrates Python calls, not by a single CLI command.

**Consequence**: This is the single most important finding for the design. A plan that
assumed `graphify build` would have failed at the first task. The feature needs two
distinct paths, which R2 and R3 establish.

**Alternatives considered**: Calling the tool's Python API directly from our scripts —
rejected because it would couple the extension to internal module layout across versions,
and because reimplementing what the skill orchestrates is exactly what Principle XVI
forbids.

---

## R2: `graphify update <path>` builds from scratch, with no prior graph

**Decision**: Use `graphify update <path>` for both the first build and the incremental
refresh of code. One command covers both spec user stories P1 and P2 for code content.

**Evidence**: In a scratch directory containing only two Python files and no
`graphify-out/`, the command produced a graph on the first run:

```text
$ graphify update .
Re-extracting code files in . (no LLM needed)...
[graphify watch] Rebuilt: 5 nodes, 7 edges, 2 communities
[graphify watch] graph.json, graph.html and GRAPH_REPORT.md updated in graphify-out
Code graph updated. For doc/paper/image changes run /graphify --update in your AI assistant.
```

**Rationale**: "No LLM needed" makes this path deterministic, free, fast, and safe to run
from a script on either platform — the properties the confirmation step in FR-005 exists
to protect the maintainer from lacking.

**Alternatives considered**: Requiring the agent skill even for the first build —
rejected because it makes the cheapest and most common case depend on model availability
and cost for no benefit.

---

## R3: Non-code content requires the agent skill, and the tool says so itself

**Decision**: The command handles code deterministically through the CLI and **delegates
non-code content to the maintainer's own graphify skill** rather than orchestrating the
model-assisted pipeline itself.

**Evidence**: Every `graphify update` run ends with the tool's own instruction: *"For
doc/paper/image changes run `/graphify --update` in your AI assistant."*

**Rationale**: The tool is telling us where its boundary is. Honouring that boundary is
Principle XVI applied literally: the extension invokes what the tool exposes and hands off
what the tool delegates, instead of reconstructing the orchestration in our own command
prose where it would drift from upstream on the next release.

**Consequence for the spec**: FR-009 (delegate, never reimplement) is satisfied by
construction. The build report must state plainly that code was processed and that
non-code content needs the skill pass — otherwise a maintainer with a docs-heavy project
reads a partial graph as complete, which SC-005 forbids.

---

## R4: Provenance is carried on each link as `confidence`

**Decision**: Read evidence labels from `links[].confidence`, and the numeric strength
from `links[].confidence_score`. Report both without translation.

**Evidence**: A link from the probe graph, verbatim:

```json
{
  "relation": "contains",
  "confidence": "EXTRACTED",
  "source_file": "src/a.py",
  "source_location": "L1",
  "weight": 1.0,
  "source": "src_a",
  "target": "src_a_alpha",
  "confidence_score": 1.0
}
```

Union of link keys across the probe graph: `confidence`, `confidence_score`, `context`,
`relation`, `source`, `source_file`, `source_location`, `target`, `weight`. A pure
AST run yields `confidence` values of `EXTRACTED` only; `INFERRED` and `AMBIGUOUS` appear
once model-assisted extraction has run.

**Rationale**: FR-012 and SC-004 require the labels to survive to the report. Now we know
exactly which field to read, so a breakdown by label is a `group by` over `links`, not an
inference.

**Note on graph shape**: The document uses node-link JSON with the edge array named
`links`, not `edges` — a naive implementation reading `graph["edges"]` gets an empty list
and reports a graph with zero relationships as a success. This is a real trap and belongs
in the contract.

---

## R5: A no-change refresh is already distinct, and is reported distinctly

**Decision**: Do not implement change detection. Run the refresh and classify the tool's
own outcome.

**Evidence**: Second consecutive run with nothing modified:

```text
[graphify watch] No code-graph topology changes detected; outputs left untouched.
```

Third run, after adding one file:

```text
[graphify] backed up curated graph (4 files) -> 2026-07-22/
[graphify watch] Rebuilt: 7 nodes, 8 edges, 2 communities
```

**Rationale**: FR-008 (report a no-change refresh as current, change nothing) is satisfied
by the tool, which also takes a dated backup of a curated graph before replacing it. Our
job is to classify and report these outcomes distinctly, per SC-005 — not to duplicate the
detection.

---

## R6: Outputs are fixed and all derived

**Decision**: Treat the entire `graphify-out/` directory as tool-owned and git-ignored;
never write into it, never parse anything from it except `graph.json` for reporting.

**Evidence**: After a build the directory contains exactly `graph.json`, `graph.html`,
`GRAPH_REPORT.md`, `manifest.json`, and `cache/`, plus a dated backup directory once a
rebuild replaces a curated graph.

**Rationale**: Principle XVII. `.gitignore` already excludes `graphify-out/` as of
constitution v2.0.0, so FR-017 and SC-006 are enforced by a file already in the
repository rather than by a rule the implementation must remember.

---

## R7: Where the dependency check must happen, and what it must catch

**Decision**: Check three things in order, and stop at the first failure: the executable
resolves on `PATH`; `graphify --version` succeeds and parses; the parsed version is at or
above the supported floor.

**Rationale**: FR-001 through FR-004 require the check to precede any build work and to
produce nothing on failure. Splitting it into three ordered checks is what makes FR-002's
"report the version found alongside the version required" possible — a single boolean
`is graphify installed` cannot produce that message.

**Supported floor**: `>=0.9.9`, the version every finding here was verified against.
Raising the floor later is a MAJOR bump for the extension under Principle VIII.

**Falsifiability (Principle XV)**: Each of the three failures must be observed. The probe
for "absent" runs with `PATH` scrubbed of the tool; the probe for "too old" needs a
version string the parser rejects. A check that has only ever seen a healthy machine has
not been tested — it has been assumed.

---

## R8: Confirmation belongs to the command, not the script

**Decision**: The command Markdown (executed by the agent) reports scope and obtains
confirmation. The scripts perform no prompting and refuse to run without an explicit
"already confirmed" argument.

**Rationale**: FR-005 requires confirmation before a build; FR-006 requires that no
lifecycle event can trigger one. A script that prompts on stdin behaves differently under
CI, under a non-interactive shell, and under each harness — three behaviors where the spec
demands one. Putting the decision in the agent layer and making the script's contract
explicitly "the caller has already confirmed" means an unconfirmed build cannot happen by
omission: it requires passing a flag that says the opposite of the truth.

**Alternatives considered**: Prompting in the script with a `--yes` bypass — rejected
because the failure mode is silent in exactly the environment (automation) where an
unrequested expensive build is most damaging.

---

## R9: Package layout follows the repository's existing discovery

**Decision**: The package lives at `extension/` in the repository root.

**Evidence**: `scripts/install-test.sh` discovers packages with
`find "$REPO_ROOT" -name extension.yml -not -path '*/.git/*'`, and the CI workflow passes
discovered packages to `scripts/validate-extension.py`. Any directory containing an
`extension.yml` is picked up, so the layout choice is free and should be the clearest one.

**Rationale**: `template/` is the inherited `trace` reference extension and stays where it
is. A sibling `extension/` keeps the shipped package and the reference example visibly
distinct, which matters because Principle III now means opposite things in the two
directories.

---

## R10: There is no `--full` flag; a rebuild is forced by removing `graph.json`

**Decision**: `full` mode removes `graphify-out/graph.json` and then invokes
`graphify update <path>`. This is a documented, narrow exception to "never write into
`graphify-out/`".

**Evidence**:

```text
$ graphify update . --full
error: unknown update option: --full

$ graphify update . --force
[graphify watch] No code-graph topology changes detected; outputs left untouched.

$ rm -f graphify-out/graph.json && graphify update .
[graphify watch] Rebuilt: 3 nodes, 3 edges, 1 communities
```

**Rationale**: `--force` is documented as "overwrite `graph.json` even if the rebuild has
fewer nodes" — a safety override for refactors that delete code, not a full re-extraction.
It was observed leaving outputs untouched on an unchanged corpus, so it cannot serve as
the full-rebuild mode. Removing `graph.json` does force one.

**Constraint on the exception (Principle XVII)**: The extension may delete exactly
`graphify-out/graph.json`, only in `full` mode, only after confirmation, and only when the
dependency check has passed. It may not remove, move, or edit any other file under
`graphify-out/`, and it may not edit `graph.json` — only delete it so the tool writes a new
one. Deleting a derived artifact to force regeneration is consistent with the principle;
editing one is what the principle forbids.

**Alternatives considered**: Removing the whole `graphify-out/` directory — rejected
because it discards the tool's `cache/`, its `manifest.json`, and the dated backups it
keeps of curated graphs, turning a rebuild into data loss.

**Corrects**: The pre-critique plan asserted a `--full` flag that does not exist. Critique
finding E1.

---

## R11: The tool writes to the working directory as well as the target path

**Decision**: The script MUST change directory to the resolved scope root before invoking
the tool, and MUST assert afterwards that no `graphify-out/` was created anywhere else.

**Evidence**: From a directory that is not the target:

```text
$ cd elsewhere && graphify update ../proj
[graphify watch] graph.json, graph.html and GRAPH_REPORT.md updated in ../proj/graphify-out

$ ls elsewhere/graphify-out
manifest.json                    # ← created in the working directory

$ ls proj/graphify-out
cache  GRAPH_REPORT.md  graph.html  graph.json
```

The graph goes to the target; a `manifest.json` is left in the working directory.

**Rationale**: `scope.root` is configurable, so a maintainer with a non-default root would
get a stray `graphify-out/` in their project root — a write FR-015 promises does not
happen and the report would never mention. Changing directory first collapses the two
locations into one.

**Corrects**: Critique finding E4. Note that every scenario written before this finding
used the default root, so none of them would have caught it.

---

## R12: An incomplete graph is detectable by `manifest.json` without `graph.json`

**Decision**: Treat `graphify-out/manifest.json` present with `graphify-out/graph.json`
absent as the interrupted state. Refuse to refresh from it and require a full build.

**Evidence**: After removing `graph.json` from a completed build, the directory retains
`manifest.json`, `GRAPH_REPORT.md`, `graph.html`, and `cache/`. `manifest.json` is a
per-file map — its keys were `src/x.py` and `vendor/v.py` — so it records what the tool
believed it had processed. That record surviving without the graph it describes is exactly
the inconsistency an interrupted run leaves behind.

**Locking (FR-020)**: The lock is an atomically-created **directory** under the
extension's own `.specify/extensions/llm-wiki-graphify/`, never under `graphify-out/` —
placing it in the tool-owned directory would make the natural implementation a Principle
XVII violation. A directory is atomic on POSIX and Windows filesystems; a check-then-create
lock file is not.

**Stale locks**: The lock records the process identifier and a timestamp. A lock whose
owning process no longer exists is reclaimed with a reported warning. Without this, the
first crash makes the command permanently unusable — an availability failure introduced by
a safety mechanism.

**Corrects**: Critique finding E5, which observed that FR-019 and FR-020 specified
behaviour with no mechanism.

---

## R13: `graphify update` does not honour exclusions

**Decision**: Remove `scope.exclude` from v1. Scope is controlled by `scope.root` alone.
The report states that no exclusions were applied, rather than claiming any were.

**Evidence**: A project containing `src/x.py` and `vendor/v.py` was built with no
exclusion configured, and both appeared in the graph:

```text
$ python3 -c "import json; g=json.load(open('graphify-out/graph.json')); print([n['source_file'] for n in g['nodes']])"
['src/x.py', 'src/x.py', 'vendor/v.py', 'vendor/v.py']
```

`graphify update --help` exposes only `--force` and `--no-cluster`. There is no exclusion
option to pass through.

**Rationale**: The pre-critique design had the extension accept `scope.exclude`, report the
patterns in the scope summary, and then invoke a tool that ignores them. That is a report
making a false statement about what was read — worse than having no exclusion feature,
because the maintainer would believe their vendored code and secrets directory had been
skipped when they had not.

**Consequence**: The spec's edge case about honouring exclusions is not deliverable in v1
and is restated as a known limitation. If exclusions matter, the honest path is upstream
support in graphify, not a claim in our report.

**Corrects**: Critique finding E7, which asked whether exclusion honouring had been
verified. It had not, and it does not hold.

---

## R15: The counting pass is not a scale concern

**Decision**: Read `graph.json` whole and count in one pass. No streaming parser, no
sampling, no size threshold.

**Evidence**: Synthetic graphs at two scales, counted with the same one-pass approach the
contract specifies:

| Graph | File size | Load + count + breakdown |
|---|---|---|
| 10,000 nodes / 40,000 links | 9.0 MB | 0.14 s |
| 50,000 nodes / 200,000 links | 45.7 MB | 0.65 s |

**Rationale**: 50,000 nodes is far beyond what the tool produces for a typical repository,
and sub-second is invisible next to the build itself. Adding a streaming parser to defend
against a cost that does not exist would be complexity with no subject.

**Bound worth stating**: the pass holds the whole graph in memory, so its ceiling is
memory, not time — roughly 10× the file size for a Python-parsed JSON document. A graph
large enough to matter would have to exceed several hundred megabytes, at which point the
build that produced it was the real problem.

**Fixture note**: the generator used here is how
`tests/fixtures/graph-build-mixed/graphify-out/graph.json` is produced — a graph with
`EXTRACTED`, `INFERRED`, and `AMBIGUOUS` links in known proportions, which the scripted
build cannot generate on its own (quickstart Scenario 12).

**Resolves**: Critique question E9.

---

## R16: Markdown is extracted structurally — the deterministic pass is not code-only

**Decision**: Stop describing the deterministic pass as "code only". It reads **code and
document structure**; what it does not do is the *semantic* pass.

**Evidence**: A directory containing one `README.md` and no code at all:

```text
$ graphify update .
[graphify watch] Rebuilt: 2 nodes, 1 edges, 1 communities
```

The nodes:

```json
[
 {"label": "README.md", "file_type": "document", "source_file": "README.md",
  "_origin": "ast", "id": "readme", "community": 0},
 {"label": "just prose", "file_type": "document", "source_file": "README.md",
  "_origin": "ast", "id": "readme_just_prose", "community": 0}
]
```

The link between them carries `"confidence": "EXTRACTED"`. The heading became a node, and
`_origin` is `ast` — the document was parsed structurally, not interpreted.

**What this corrects**: the spec, the plan, and the critique's P2 finding all described the
deterministic pass as reading code and ignoring prose, and concluded that a Spec Kit
project's Markdown would be absent from the graph. That is wrong. Document structure —
headings and their containment — does enter the graph, with `EXTRACTED` provenance.

**What remains true**: the *semantic* layer does not. Cross-document concepts, the
relationships a model would infer between a requirement and the code that implements it,
and everything carrying `INFERRED` or `AMBIGUOUS` provenance still require the
model-assisted pass. The tool's own closing line says so on every run: *"For doc/paper/image
changes run `/graphify --update` in your AI assistant."*

**Consequence**: the coverage statement must be precise rather than reassuring. "Documents
were not interpreted" is false; "document structure was extracted, but no semantic
relationships were inferred between documents or between documents and code" is true. The
distinction matters because a maintainer who reads the false version would go looking for
their headings and find them, and then trust the graph for the semantic claims it cannot
make.

**How this was found**: while building the `nothing-to-examine` fixture. The fixture
contained a single `README.md`, and the build that was supposed to find nothing produced a
graph. The test was wrong, and it was wrong because the spec was wrong.

---

## R17: An empty scope is reported by the tool, not inferred from a file count

**Decision**: Classify `nothing-to-examine` from graphify's own output and the absence of
`graph.json` — never from counting files.

**Evidence**: A directory containing only `.gitkeep`:

```text
$ graphify update .
Nothing to update or rebuild failed — check output above.
Re-extracting code files in . (no LLM needed)...
[graphify watch] No code files found - nothing to rebuild.
```

No `graph.json` was produced.

**Rationale**: A file count cannot distinguish "no files" from "files the tool does not
read", and R16 shows the set of files the tool reads is wider than expected. Counting would
have reported `nothing-to-examine` for a directory of Markdown that graphify happily
extracts. The tool already answers the question precisely; asking it is more reliable than
guessing from the filesystem.

---

## Resolved unknowns

| Unknown from Technical Context | Resolved by |
|---|---|
| How a build is actually invoked | R1, R2 |
| Whether a first build needs the model | R2, R3 |
| Where evidence labels live | R4 |
| How a no-change refresh is detected | R5 |
| What the output surface is | R6 |
| What the dependency check must produce | R7, R14 |
| Where confirmation lives | R8 |
| Where the package lives | R9 |
| How a full rebuild is forced | R10 |
| Where the tool actually writes | R11 |
| How interrupted and concurrent states are detected | R12 |
| Whether exclusions are honoured | R13 |
| What version range is safe to depend on | R14 |
| Whether graph size threatens the counting pass | R15 |
| What the deterministic pass actually reads | R16 |
| How an empty scope is detected | R17 |

No `NEEDS CLARIFICATION` items remain.

---

## R14: The dependency is pre-1.0 and must be pinned with a ceiling

**Decision**: Require `graphify >=0.9.9,<0.10.0`. Raising the ceiling is a deliberate
re-verification pass that re-runs every probe in this document, not a version-string edit.

**Evidence**: `graphify --version` prints `graphify 0.9.9` — a 0.x release. Under semantic
versioning, 0.x makes no backward-compatibility promise between minor versions.

**Rationale**: Every contract in this feature rests on behaviour observed in exactly one
version: the edge array named `links`, the `confidence` vocabulary, the absence of
`--full`, the wording of the no-change message, the dual write location. A `0.10.0` that
changed any of them would break installed copies of this extension in other people's
projects, with no signal until a build silently reported zero relationships.

**Version parsing must fail closed**: If `graphify --version` produces output that does not
parse as `X.Y.Z`, the command stops with `dependency-too-old` and reports the raw string.
An unparseable version is never treated as new enough — the format itself is unversioned
and could change.

**Corrects**: Critique findings E13 and E14.
