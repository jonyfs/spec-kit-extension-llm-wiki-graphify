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

## Resolved unknowns

| Unknown from Technical Context | Resolved by |
|---|---|
| How a build is actually invoked | R1, R2 |
| Whether a first build needs the model | R2, R3 |
| Where evidence labels live | R4 |
| How a no-change refresh is detected | R5 |
| What the output surface is | R6 |
| What the dependency check must produce | R7 |
| Where confirmation lives | R8 |
| Where the package lives | R9 |

No `NEEDS CLARIFICATION` items remain.
