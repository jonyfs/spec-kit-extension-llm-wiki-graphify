# llm-wiki-graphify

A [GitHub Spec Kit](https://github.com/github/spec-kit) extension that bridges the
spec-driven lifecycle to [graphify](https://github.com/safishamsi/graphify) — the
knowledge-graph tool popularized as "LLM Wiki".

The point is simple: a spec, a plan, and a task list are all written against some
mental model of the project. Graphify builds that model mechanically — a navigable
graph of code, docs, and notes, with every relationship labelled by how it was
established. This extension puts that graph in front of the Spec Kit commands, so the
model being written against is one you can inspect rather than one the agent inferred
on the fly and forgot.

> **Status:** the extension package lives in [`extension/`](extension/) and its first
> command, `speckit.llm-wiki-graphify.build`, is implemented and tested. See
> [`extension/README.md`](extension/README.md) for install and usage, and
> [`.specify/memory/constitution.md`](.specify/memory/constitution.md) for the rules it is
> built against.

## What it is, and what it is not

This extension is a **bridge**. It invokes the graphify installation you already
have. It does not reimplement graph construction, clustering, or wiki generation, and
it does not vendor graphify's source — that tool has its own release cadence, and a
copy would disagree with the graph you already trust within a month.

Four rules shape everything it does. They are constitutional, not stylistic:

- **Graphify is a dependency, checked explicitly.** If graphify is not installed, a
  command stops and says so. There is no silent fallback and no stub graph presented
  as a real one.
- **Derived artifacts are never committed and never hand-edited.** All of
  `graphify-out/` is git-ignored. A wrong edge is fixed in the source and the graph is
  rebuilt — correcting the output by hand produces a graph that no longer matches what
  a rebuild would produce.
- **Provenance survives every hop.** Graphify labels each relationship `EXTRACTED`
  (read from the source), `INFERRED` (model-produced, with a confidence), or
  `AMBIGUOUS` (needs review). Those labels are carried through unchanged. An
  `INFERRED` edge may raise a `[NEEDS CLARIFICATION]` marker; it may not become a
  requirement.
- **The graph serves the lifecycle, never replaces it.** No core command is bypassed
  or gated. `spec.md`, `plan.md`, and `tasks.md` belong to the core commands and to
  you. Graph builds are expensive and touch every file, so nothing builds unprompted.

## Requirements

- A Spec Kit project (`specify` CLI).
- [graphify](https://github.com/safishamsi/graphify), installed and on `PATH`, or the
  equivalent agent skill. The supported invocations are pinned to a stated graphify
  version and verified against it rather than recalled.

## Scope

| Field | Value |
|---|---|
| `extension.id` | `llm-wiki-graphify` |
| Command namespace | `speckit.llm-wiki-graphify.*` |
| Owned directory | `.specify/extensions/llm-wiki-graphify/` |
| Derived output | `graphify-out/` — owned by graphify, git-ignored |

**In scope:** building and incrementally updating a project graph; querying it
(`query`, `path`, `explain`) and surfacing the result as context for a Spec Kit
command; exposing the generated wiki and `GRAPH_REPORT.md` to the agent; opt-in
lifecycle hooks that offer these at the moments they help.

**Out of scope** without a constitutional amendment: graph construction not delegated
to graphify, any persistent graph store inside `.specify/`, embeddings or a vector
database, any write to `spec.md` / `plan.md` / `tasks.md`, and any automatic graph
build.

## Repository layout

This repository was forked from
[`spec-kit-extension-template`](https://github.com/jonyfs/spec-kit-extension-template)
and keeps its engineering discipline: the constitution, the CI gates, and the
validation scripts all still apply to the extension being built here.

| Path | What it is |
|---|---|
| [`.specify/memory/constitution.md`](.specify/memory/constitution.md) | The non-negotiable rules. Source of truth. |
| [`docs/PACKAGING.md`](docs/PACKAGING.md) | How an extension reaches a user, per distribution form. |
| [`docs/HOOKS.md`](docs/HOOKS.md) | The two hook layers, and how not to confuse them. |
| [`extension/`](extension/) | The shipped `llm-wiki-graphify` package. |
| [`template/`](template/) | The inherited `trace` reference extension — a working example, and what keeps the install-test honest. |
| [`.claude/skills/sdd-master/`](.claude/skills/sdd-master/) | The skill that decides how much process a change warrants. Not shipped with the extension. |

## Validation tooling

| Script | Enforces |
|---|---|
| `scripts/validate-extension.py` | Manifest shape, command namespacing, hook events and priorities, script parity |
| `scripts/check-placeholders.sh` | No `CUSTOMIZE:` markers survive into a shipped package |
| `scripts/install-test.sh` | The install → list → info → remove cycle |
| `scripts/test-graph-build.sh` / `.ps1` | That every build-command failure path actually fails, for the right reason |

```bash
python scripts/validate-extension.py path/to/extension
bash scripts/install-test.sh
```

All three run in CI on every pull request.

## Contributing

`main` is the trunk and is never committed to directly. Work happens on short-lived
branches and lands through a pull request with every CI gate green. The pull request
template carries the constitution checklist — a box ticked without the corresponding
check having been run is worse than an unchecked box.

See the constitution's "Development Workflow & Quality Gates" section for the full
sequence.

## License

MIT — see [LICENSE](LICENSE).

Spec Kit is a project of GitHub, Inc. Graphify is a project of its own authors. This
extension is not affiliated with or endorsed by either.
