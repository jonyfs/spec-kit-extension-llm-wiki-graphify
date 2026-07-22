# Quickstart: Graph Build Command

**Feature**: 002-graph-build-command
**Date**: 2026-07-22

How to prove this feature works. The negative scenarios are not optional extras — under
Constitution Principle XV a gate that has only ever been observed passing has not been
tested, so each failure path below must be *watched failing* before the corresponding
check is trusted.

## Prerequisites

- `graphify >= 0.9.9` on `PATH` (`graphify --version`)
- A Spec Kit project for the install cycle
- `python3` for the repository's validation gates

## Package validation

```bash
python scripts/validate-extension.py extension
bash scripts/check-placeholders.sh
```

Expected: manifest valid, and no `CUSTOMIZE:` markers in `extension/` — markers belong
only to `template/` (Principle III).

## Install cycle (Principle VII)

```bash
specify extension add --dev ./extension
specify extension list          # llm-wiki-graphify appears
specify extension info llm-wiki-graphify
specify extension remove llm-wiki-graphify
```

Every declared command and hook must be executed at least once between `add` and
`remove`. An install that was never exercised proves only that the YAML parses.

---

## Scenario 1 — First build (spec User Story 1)

```bash
mkdir -p /tmp/gb-code/src
printf 'def alpha():\n    return beta()\n\ndef beta():\n    return 42\n' > /tmp/gb-code/src/a.py
printf 'from src.a import alpha\n\ndef main():\n    return alpha()\n' > /tmp/gb-code/src/b.py
cd /tmp/gb-code
bash <ext>/scripts/bash/graph-build.sh scope
bash <ext>/scripts/bash/graph-build.sh build --confirmed
```

Expected: `outcome=built`, `entities=5`, `relationships=7`, `evidence_EXTRACTED=7`, exit
0, and `graphify-out/` containing `graph.json`, `graph.html`, `GRAPH_REPORT.md`,
`manifest.json`, `cache/`.

Those counts are the ones a real run produced during Phase 0 research on exactly these two
files. A different count means either the fixture or the counting changed, and both are
worth stopping for.

**Also verify**: `git status` in a repository shows no `graphify-out/` content (FR-017,
SC-006), and the report names the output location and carries the coverage statement —
code interpreted, prose not interpreted, no exclusions applied (FR-013a, SC-008).

## Scenario 2 — Confirmation is required (FR-005, FR-006, SC-007)

```bash
bash <ext>/scripts/bash/graph-build.sh build          # note: no --confirmed
```

Expected: **exit 2**, nothing built, nothing written. If this exits 0, the confirmation
requirement does not exist regardless of what the command prose says.

Then, through the command itself, decline the prompt: expected `declined`, no writes.

## Scenario 3 — No-change refresh (FR-008)

Immediately after Scenario 1, with nothing modified:

```bash
bash <ext>/scripts/bash/graph-build.sh build --confirmed
```

Expected: `outcome=current`, exit 0, and the tool's own line
`No code-graph topology changes detected; outputs left untouched.` passed through to
stderr. Verified behaviour of graphify 0.9.9 (research R5).

## Scenario 4a — Full rebuild (FR-007, research R10)

```bash
bash <ext>/scripts/bash/graph-build.sh build --confirmed --full
```

Expected: `graphify-out/graph.json` is removed and regenerated, `outcome=built`, and the
counts match a from-scratch build. Verify explicitly that `cache/`, `manifest.json`, and
any dated backup directory **survive** — a `full` mode that removes the whole output
directory turns a rebuild into data loss.

Note there is no `--full` flag on the tool itself (`error: unknown update option: --full`)
and `--force` is not equivalent. If a future graphify adds a real full-rebuild option, this
scenario is where the change surfaces.

## Scenario 4b — Non-default scope root (FR-015, research R11)

```bash
mkdir -p /tmp/gb-root/sub/src && cd /tmp/gb-root
printf 'def s():\n    return 1\n' > sub/src/s.py
bash <ext>/scripts/bash/graph-build.sh build --confirmed --path sub
```

Expected: `sub/graphify-out/` exists, and **`/tmp/gb-root/graphify-out/` does not**.

The tool writes a `manifest.json` into the working directory while writing the graph to
the target path, so without the script changing directory first, this scenario finds a
stray output directory. Every other scenario uses the default root and would never catch
it.

## Scenario 4 — Incremental refresh (spec User Story 2, SC-003)

```bash
printf 'def gamma():\n    return 7\n' > /tmp/gb-code/src/c.py
bash <ext>/scripts/bash/graph-build.sh build --confirmed
```

Expected: `outcome=built`, `entities=7`, `relationships=8`, and a delta reporting what was
added.

**SC-003 check**: time this against a `--full` run on a project large enough for the
difference to be real. A refresh that silently performs a full rebuild is otherwise
indistinguishable from a correct one — which is the whole reason the criterion is stated
as a ratio.

## Scenario 5 — Dependency missing (spec User Story 3, FR-002, FR-004, SC-001)

```bash
mkdir -p /tmp/gb-nopath
env PATH=/tmp/gb-nopath bash <ext>/scripts/bash/graph-build.sh check
```

Absence is **constructed**, not assumed: `PATH` is an empty directory, so the tool cannot
be found regardless of where it is installed. The earlier form of this scenario scrubbed
`PATH` to `/usr/bin:/bin` and asked the reader to check that graphify was not there — an
instruction a tired person skips, on a machine where the scenario then passes having
tested nothing. That is the exact Principle XV failure this scenario exists to catch.

Expected: **exit 4**, a message naming the missing dependency and its install step, **and
no `graphify-out/` directory created**. Check for the directory explicitly; its absence is
half the requirement.

## Scenario 6 — Dependency too old (FR-002)

Place a stub earlier on `PATH` that prints an old version:

```bash
mkdir -p /tmp/gb-stub
printf '#!/bin/sh\necho "graphify 0.0.1"\n' > /tmp/gb-stub/graphify
chmod +x /tmp/gb-stub/graphify
env PATH=/tmp/gb-stub:$PATH bash <ext>/scripts/bash/graph-build.sh check
```

Expected: **exit 5**, reporting `0.0.1` found and `0.9.9` required. Both numbers must
appear; "version too old" alone does not satisfy FR-002.

## Scenario 7 — Nothing to examine (FR-013, SC-005)

```bash
mkdir -p /tmp/gb-empty && cd /tmp/gb-empty && touch .gitkeep
bash <ext>/scripts/bash/graph-build.sh build --confirmed
```

The fixture must contain **no readable file at all** — not even a `README.md`. Research
R16 found that a lone `README.md` produces a two-node graph, because document structure is
extracted. An "empty" fixture holding a readme tests the opposite of what it claims to.

Expected: **exit 3**, `outcome=nothing-to-examine`, and a message distinct from a
successful build. Exit 0 here would be the "gate with no subject" failure named in
Principle XV.

## Scenario 8 — Concurrent build (FR-020, research R12)

Create the lock directly rather than racing two real builds:

```bash
mkdir -p .specify/extensions/llm-wiki-graphify/build.lock
bash <ext>/scripts/bash/graph-build.sh build --confirmed
```

Expected: exit **6**, the run in progress named, nothing written.

Then verify stale-lock reclamation: with a lock recording a process identifier that no
longer exists, the next build reclaims it, reports the reclamation, and proceeds. Without
this, one crash disables the command permanently — a safety mechanism that becomes an
availability failure.

## Scenario 9 — Interrupted build (FR-019, research R12)

The interrupted state is reproducible without actually interrupting anything — it is
`manifest.json` present with `graph.json` absent:

```bash
cd /tmp/gb-code && rm -f graphify-out/graph.json
bash <ext>/scripts/bash/graph-build.sh build --confirmed          # refresh
```

Expected: exit **7**, the incomplete state named, and a refusal to refresh from it. Then:

```bash
bash <ext>/scripts/bash/graph-build.sh build --confirmed --full   # recovery
```

Expected: `outcome=built`, recovering cleanly.

Constructing the state deterministically matters: a scenario that depends on landing a
`SIGINT` in the right millisecond is a scenario that gets skipped.

## Scenario 10 — Boundaries hold (FR-015, FR-016)

After any successful build:

```bash
git status --porcelain                 # no graphify-out/ entries
git diff --stat specs/                 # spec, plan, tasks byte-for-byte unchanged
```

Expected: both empty. FR-016 is the one a passing build will never surface on its own,
so it is checked explicitly.

## Scenario 11 — Parity (FR-021, Principle V)

Run Scenarios 1, 3, 5, 6, and 7 through `graph-build.ps1` on Windows.

Expected: identical `outcome` values, identical exit codes, identical stdout key set.
Parity is proven by running both, never by reading the two files side by side.

## Scenario 12 — Provenance survives (FR-012, SC-004)

The scripted build emits only `EXTRACTED` links, so this scenario **cannot be run against
a graph this feature produces**. It requires a committed fixture:
`tests/fixtures/graph-build-mixed/graphify-out/graph.json`, a small hand-built graph whose
`links[].confidence` values include all three labels, with `confidence_score` present on
the `INFERRED` ones.

```bash
bash <ext>/scripts/bash/graph-build.sh status --path tests/fixtures/graph-build-mixed
```

Expected: the breakdown reports all three labels verbatim, with non-zero counts for each.

The fixture is a graph, not a build output — it is committed deliberately as test data and
is the one graph in this repository that is not derived. Note that a run against a
100%-`EXTRACTED` graph would pass a naive version of this check while proving nothing,
which is why the fixture is required rather than optional.

---

## Coverage

| Scenario | Requirements |
|---|---|
| 1 | FR-005, FR-007, FR-010, FR-017 |
| 2 | FR-005, FR-006, SC-007 |
| 3 | FR-008 |
| 4 | FR-007, FR-011, SC-003 |
| 4a | FR-007, FR-018 |
| 4b | FR-015 |
| 5 | FR-001, FR-002, FR-004, SC-001 |
| 6 | FR-002 |
| 7 | FR-013 |
| 8 | FR-020 |
| 9 | FR-019 |
| 10 | FR-015, FR-016, SC-006 |
| 11 | FR-021 |
| 12 | FR-012, SC-004 |
| 1, 4a | FR-013a, SC-008 (coverage statement present on every completed build) |

FR-003 (never auto-install) and FR-009 (never reimplement) are verified by inspection:
no install invocation and no extraction, clustering, or rendering logic may appear in the
package. FR-014, FR-018, FR-022, and FR-023 are exercised through the command rather than
the script, during the install cycle above.
