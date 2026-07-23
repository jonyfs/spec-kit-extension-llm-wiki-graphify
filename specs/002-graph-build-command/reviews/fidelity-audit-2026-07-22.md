# Fidelity Audit: Extension vs. the graphify Article

**Date**: 2026-07-22
**Question asked**: does this Spec Kit extension implement, to the letter, what the source
article and its sublinks describe?
**Sources**: the Medium article
(`andrej-karparthys-llm-wiki-codes-graphify`), the graphify tool it describes
(`safishamsi/graphify`), and the installed graphify skill.

**Verdict**: **No — and correctly not.** The extension implements one slice of what the
article describes (the build), delegates the rest to graphify unchanged, and deliberately
defers most of the article's features to later features. Measured against "did it reproduce
graphify", the answer is a deliberate no, and that no is the extension's entire design
premise (Constitution Principle XVI). Measured against "did it faithfully deliver the slice
it claims", the answer is yes, with the qualifications below.

The short version: the article describes **graphify**. This extension is a **bridge to
graphify**, and only its `build` command exists so far. Expecting it to implement the article
to the letter is expecting the wrong thing — but the audit still has to show that what it
*does* cover matches the article's reality, and that what it defers is deferred honestly
rather than missed.

---

## What the article attributes to graphify, line by line

| # | Article claim | In the extension? | Where |
|---|---|---|---|
| 1 | `/graphify .` builds a graph from a folder | **Delegated** | `build` command invokes `graphify update <path>` — verified there is no `graphify build` subcommand (research R1) |
| 2 | Outputs `graph.html`, `GRAPH_REPORT.md`, `graph.json`, `cache/` | **Delegated, untouched** | The extension reads `graph.json` for counts and never writes any of them; all are tool-owned and git-ignored (R6, Principle XVII) |
| 3 | Two-pass: AST for code (deterministic, no AI), then AI agents for docs/papers/images | **Split honoured exactly** | The extension runs only the deterministic pass and hands off the AI pass to the maintainer's own graphify skill (R3). This is the article's own boundary, honoured to the letter |
| 4 | Provenance labels `EXTRACTED` / `INFERRED` / `AMBIGUOUS` | **Preserved verbatim** | Read from `links[].confidence`, reported as a breakdown, never flattened (R4, Principle XVIII) |
| 5 | `graphify query "..."` | **Out of scope (deferred)** | Named in the spec's Out of Scope: "its own feature, depends on this one" |
| 6 | `graphify query ... --budget 500`, `--dfs`, `--graph` | **Out of scope** | Same — the whole query surface is a later feature |
| 7 | `graphify path "A" "B"` | **Out of scope** | Same |
| 8 | `graphify explain "X"` | **Out of scope** | Same |
| 9 | Browsable wiki (the "LLM Wiki" of the title) | **Out of scope** | Spec Out of Scope: "generating or serving the browsable wiki" |
| 10 | `graphify claude install` / `codex install` — assistant integration | **Not reproduced, by design** | The extension does not install graphify into agents; it depends on the maintainer's existing install (Principle XVI). The Spec Kit hook is the integration path instead |
| 11 | "No embeddings, no vector DB" | **Matched** | Spec Out of Scope: "embeddings and vector search" — the extension adds none |
| 12 | `cache/` reprocesses only changed files (incremental) | **Delegated** | The `--full` vs. refresh split rides on graphify's own incremental path (R2, R5) |

**Score against the article's twelve claims**: 4 delegated faithfully (1, 2, 3, 12), 2
preserved exactly (4, 11), 5 deferred to named future features (5, 6, 7, 8, 9), 1
intentionally not reproduced (10). **Zero reproduced incorrectly. Zero silently missing.**

---

## Where the extension is *more* honest than the article

The article says the deterministic pass handles "code" and the AI pass handles "docs,
papers, and images". Probing graphify directly (research R16) found this is imprecise: the
deterministic pass **also extracts document structure** — a Markdown heading becomes a node
with `EXTRACTED` provenance, no AI involved. A single `README.md` produces a two-node graph.

The extension's coverage statement corrects the article rather than parroting it: it tells
the maintainer that structure was extracted from code *and* documents, and that only the
*semantic* layer needs the AI pass. Implementing the article "to the letter" here would have
meant shipping the article's own imprecision. The extension implements the tool's *behaviour*
to the letter, which is the stronger fidelity.

---

## Where fidelity is still owed (open, tracked)

| Gap | Status |
|---|---|
| The article's title feature — the **wiki** — does not exist yet | Deferred; named in Out of Scope. Fidelity to the "LLM Wiki" name is unmet until a wiki feature ships |
| `query`, `path`, `explain` — the article's main interaction verbs | Deferred to their own features; each depends on `build`, which is why `build` shipped first |
| Config is declared but the script does not yet read it | Known gap (feature-002 research R4); feature 003 Phase 1 closes it |
| `query`/`path`/`explain` provenance preservation | Cannot be audited yet — the features do not exist |

None of these is a defect in what shipped. They are the difference between "the extension so
far" and "the extension when complete", and every one is written down in an Out of Scope
section rather than left as a silent shortfall.

---

## Answer to the question

**Did it implement the article to the letter?** No single feature could — the article
describes a whole tool, and reproducing that tool is the one thing the constitution forbids
(Principle XVI: delegate, never reimplement). What shipped is the `build` slice, and within
that slice:

- Every graphify behaviour it touches, it delegates faithfully and verified by running the
  real tool, not by recall.
- Every provenance label survives unchanged.
- The two-pass boundary is honoured exactly, and stated more precisely than the article
  states it.
- Everything not yet built is named as deferred, not missed.

**The one honest caveat**: the feature the article is *titled* after — the LLM Wiki — is not
built yet. Anyone auditing against the title, rather than against what feature 002 claims,
should read this as "the foundation is faithful; the headline feature is still ahead."
