# llm-wiki-graphify

A [GitHub Spec Kit](https://github.com/github/spec-kit) extension that builds a
[graphify](https://github.com/safishamsi/graphify) knowledge graph of your project and
makes it available to the spec-driven workflow.

Specs and plans are written against some model of the project. This builds that model
mechanically — entities and relationships extracted from your code and documents, each
relationship labelled with how it was established — so you can inspect it instead of
trusting whatever the agent inferred and forgot.

## Requirements

- A Spec Kit project
- **graphify `>=0.9.9,<0.10.0`** on `PATH`, installed by you

```bash
uv tool install 'graphifyy>=0.9.9,<0.10.0'
# or: python3 -m pip install 'graphifyy>=0.9.9,<0.10.0'
```

The version ceiling is not caution. graphify is pre-1.0 and makes no compatibility promise
between minor versions, while this extension reads fields observed in one specific release
— the edge array named `links`, the `confidence` vocabulary, the wording of its no-change
message. A `0.10.0` could change any of them, and the failure would be silent: a graph
reported as built with zero relationships in it. So the extension refuses a version it has
not been verified against, in either direction.

**This extension never installs, upgrades, or modifies graphify.** If it is missing, the
command stops and tells you how to install it.

## Install

```bash
specify extension add --dev /path/to/extension
specify extension list
```

## Usage

```bash
/speckit.llm-wiki-graphify.build            # refresh, or first build if none exists
/speckit.llm-wiki-graphify.build --full     # re-examine everything
/speckit.llm-wiki-graphify.build --status   # report the graph's state; build nothing
/speckit.llm-wiki-graphify.build --path sub # override the configured scope root
```

The command always reports what it is about to examine and **waits for you to confirm**
before building. A build reads every file under the scope root, and that is your time and
your machine.

An opt-in hook offers a build after `/speckit.specify`. Declining it has no effect on your
specification, and nothing builds without an explicit yes.

## What a build actually covers

Read this part carefully — it is the thing most likely to be misunderstood.

**Extracted**: structure, from code *and* documents. A Markdown heading becomes an entity
exactly as a function does, and the relationships between them carry `EXTRACTED`
provenance. Your specs are in the graph.

**Not extracted**: the semantic layer. Concepts spanning several documents, and the
relationships a model would infer between a requirement and the code implementing it, are
not produced by this pass. Those carry `INFERRED` or `AMBIGUOUS` provenance and come from
graphify's model-assisted pass:

```text
/graphify --update
```

Every completed build says this in its report. The deterministic pass is local, free, and
fast; the model-assisted one is none of those, which is why they are separate and why this
extension ships the cheap one and offers the other.

## Provenance is preserved, never flattened

graphify labels each relationship with its evidentiary basis, and this extension reports
those labels **verbatim**, as a breakdown:

| Label | Meaning | What you may do with it |
|---|---|---|
| `EXTRACTED` | Read directly from a source file | Treat as fact |
| `INFERRED` | Produced by a model, with a confidence score | Raise a question; **never** promote to a requirement |
| `AMBIGUOUS` | Flagged for human review | Go read the source |

A relationship count alone cannot distinguish a graph that is entirely `EXTRACTED` from one
that is 40% `INFERRED`, and those are different objects. So the count is never reported
without the breakdown.

## Privacy

The build this extension runs is **local**: no network, no model, no data leaves your
machine. The model-assisted pass it offers is not — it sends content to whichever backend
your graphify is configured to use. That difference matters on a private codebase, so the
extension states which one you are getting, every time.

## Limitations, stated plainly

- **No exclusions.** graphify exposes no exclusion mechanism, so everything inside the
  scope root is read — vendored dependencies, and any secrets living in files. Narrow
  `scope.root` if that matters. The extension will never claim an exclusion was applied,
  because it cannot apply one.
- **Local projects only.** graphify can ingest remote repositories and merge several
  sources; this extension covers the local case.
- **The graph is derived, always.** `graphify-out/` is regenerable, git-ignored, and never
  hand-edited. A wrong edge is fixed at the source and the graph rebuilt — correcting the
  output directly produces a graph that no longer matches what a rebuild would produce.

## Outcomes

Nine, each with its own message and exit code, so a failure tells you which failure:

| Outcome | Exit | Meaning |
|---|---|---|
| `built` | 0 | A graph was produced or replaced |
| `current` | 0 | Nothing changed since the last build |
| `nothing-to-examine` | 3 | No readable files — **not** a success |
| `dependency-missing` | 4 | graphify is not on `PATH` |
| `dependency-too-old` | 5 | Outside the supported range, or an unparseable version |
| `already-running` | 6 | Another build holds the lock |
| `interrupted-state` | 7 | A previous build left an incomplete graph; use `--full` |
| `failed` | 8 | graphify ran and reported failure |
| `declined` | — | You said no; nothing ran |

## Configuration

Optional, at `.specify/extensions/llm-wiki-graphify/config.yml`. Every value has a default,
so no file is needed. See `config-template.yml`.

## License

MIT — see [LICENSE](LICENSE).
