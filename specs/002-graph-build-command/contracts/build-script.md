# Contract: Build Script

**Artifacts**: `extension/scripts/bash/graph-build.sh` and
`extension/scripts/powershell/graph-build.ps1`
**Binds**: FR-001 – FR-004, FR-007 – FR-011, FR-015, FR-019 – FR-021; Principles V, XVI

One contract, two implementations. Behavioural equivalence is the requirement; identical
source is not. Where the platforms genuinely differ, the difference must be invisible to
the caller.

## Invocation

```text
graph-build.(sh|ps1) check   [--path <p>] [--min-version <v>] [--max-version <v>]
graph-build.(sh|ps1) scope   [--path <p>]
graph-build.(sh|ps1) build   --confirmed [--path <p>] [--full]
graph-build.(sh|ps1) status  [--path <p>]
```

`build` **MUST** refuse to run without `--confirmed`. The flag is not a convenience
bypass — it is the caller asserting that a human authorised this run (research R8). A
script that prompts on stdin behaves one way interactively, another under CI, and another
under each harness; a script that refuses without an explicit assertion behaves the same
everywhere.

## Output

Structured, single-line-per-field key/value on stdout, so both the agent and a test can
parse it without a JSON dependency in the shell:

```text
outcome=built
entities=7
relationships=8
evidence_EXTRACTED=8
evidence_INFERRED=0
evidence_AMBIGUOUS=0
elapsed_seconds=2
output=graphify-out
coverage=code-only
exclusions=none
backup=graphify-out/2026-07-22
```

Diagnostics go to stderr. The tool's own output is passed through to stderr unmodified —
never suppressed, never re-worded (FR-014).

## Exit codes

| Code | Outcome | Meaning |
|---|---|---|
| 0 | `built`, `current` | The run reached a legitimate conclusion |
| 3 | `nothing-to-examine` | Scope held nothing the tool can read — **not** success (FR-013) |
| 4 | `dependency-missing` | `graphify` does not resolve on `PATH` |
| 5 | `dependency-too-old` | Below the floor, at or above the ceiling, or a version string that does not parse |
| 6 | `already-running` | Another build holds the lock (FR-020) |
| 7 | `interrupted-state` | A previous run left an incomplete graph (FR-019) |
| 8 | `failed` | The tool ran and reported failure |
| 2 | usage error | Unknown argument, or `build` without `--confirmed` |

Distinct codes exist so a test can assert *which* failure happened. Collapsing them into
`1` would let a test for "missing dependency" pass against a merely empty project — a
check that cannot fail for the right reason (Principle XV).

## Required behaviour

### `check` (FR-001 – FR-004)

1. Resolve `graphify` on `PATH`. Absent → exit 4, having created nothing.
2. Run `graphify --version` and parse `X.Y.Z` from its output (observed format:
   `graphify 0.9.9`). Unparseable → exit 5, reporting the raw string. **Fail closed**: an
   unparseable version is never treated as new enough, because the version format is
   itself unversioned and may change (research R14).
3. Compare against the floor (default `0.9.9`) **and the ceiling** (default `0.10.0`,
   exclusive). Outside the range → exit 5, reporting the version found and the range
   required. The ceiling exists because the dependency is pre-1.0 and promises no
   compatibility between minor versions; every field this contract reads was observed in
   exactly one version.
4. Create no directory and write no file on any failure path (FR-004).

### `scope` (FR-005)

Report the resolved root and the file count. Resolve the root and reject any path escaping
the project root before reporting. Writes nothing.

The scope summary MUST state that **no exclusions are applied**. The underlying tool
exposes no exclusion option — a project's vendored directories and secrets are read
(verified in research R13, where `vendor/v.py` entered the graph). Reporting exclusions
that were never applied would be a false statement about what was read.

### `build` (FR-007 – FR-011, FR-019, FR-020)

1. Re-run the `check` sequence. The check is cheap and a stale earlier result is not
   evidence about now.
2. Acquire an exclusive lock: atomically create `build.lock/` under
   `.specify/extensions/llm-wiki-graphify/` — **never** under `graphify-out/`, which the
   tool owns. Held by a live process → exit 6 without writing (FR-020). Held by a process
   that no longer exists → reclaim it and report the reclamation, so one crash does not
   disable the command permanently.
3. Detect an incomplete previous graph: `graphify-out/manifest.json` present with
   `graphify-out/graph.json` absent (research R12). Present → exit 7 and require a
   `--full` run; never refresh from an incomplete state (FR-019).
4. **Change directory to the resolved scope root** before invoking the tool. The tool
   writes `graphify-out/manifest.json` into the *working* directory while writing the
   graph to the *target* path (research R11), so a non-default root would otherwise leave
   a stray `graphify-out/` behind, violating FR-015. After the run, assert that no
   `graphify-out/` was created outside the scope root.
5. In `full` mode only, and only after steps 1–3 have passed, remove exactly
   `graphify-out/graph.json` so the tool regenerates it. There is no `--full` flag on the
   tool, and `--force` is not equivalent — it left outputs untouched on an unchanged
   corpus (research R10). Remove nothing else, and never edit a file the tool wrote.
6. Invoke `graphify update <path>`. This is the whole of the build; the script implements
   no extraction, clustering, or rendering (FR-009, Principle XVI).
7. Classify the tool's outcome: rebuilt → `built`; "No code-graph topology changes
   detected" → `current` (research R5); tool failure → `failed`.
8. Count from `graphify-out/graph.json`: entities from `nodes`, relationships from
   **`links`** — not `edges`, which does not exist and silently yields zero (research R4).
9. Break relationships down by `links[].confidence`, reproducing each label verbatim
   (FR-012).
10. On a refresh, report added, changed, and removed against the previous counts (FR-011).
11. Report the dated backup directory when the tool creates one — it is the maintainer's
    only recovery path.
12. Release the lock on every exit path, including interruption.

### `status`

Report whether a graph exists, when it was last built, its counts, and its evidence
breakdown. Builds nothing, and exits 0 whether or not a graph exists — absence is a state,
not an error.

## Prohibitions

| The script MUST NOT | Requirement |
|---|---|
| Install or upgrade graphify | FR-003 |
| Prompt for confirmation | research R8 |
| Build without `--confirmed` | FR-006 |
| Write outside `graphify-out/` and the extension's own directory | FR-015 |
| Modify anything under `graphify-out/` after the tool writes it | FR-018 |
| Delete anything under `graphify-out/` other than `graph.json` in `full` mode | FR-018, R10 |
| Report exclusions as applied | FR-013a, R13 |
| Place the lock under `graphify-out/` | Principle XVII, R12 |
| Run any git command | FR-017 |
| Suppress or re-word the tool's own error output | FR-014 |

## Parity requirements (Principle V)

Both variants MUST produce identical `outcome` values, identical exit codes, and the same
key set on stdout for the same fixture. Parity is proven by running the same fixture
through both, not by reading the two files side by side.

Known platform differences that MUST be handled rather than inherited:

- **`sed -E` and `\s`**: BSD `sed` on macOS silently ignores GNU extensions. Version
  parsing uses a POSIX-portable expression. This exact defect already broke
  `scripts/install-test.sh` in this repository.
- **`grep -q` under `set -o pipefail`**: `grep -q` exits at first match, sending SIGPIPE
  upstream and turning a match into a pipeline failure. Also already observed here.
- **Locking**: a directory created with `mkdir` is atomic on both POSIX and Windows
  filesystems; a lock *file* checked-then-created is not.
