# trace — Feature Traceability Check

A small, read-only Spec Kit extension that checks whether the current feature's
`spec.md`, `plan.md` and `tasks.md` still agree with each other.

It is the reference extension of the
[spec-kit-extension-template](https://github.com/jonyfs/spec-kit-extension-template)
repository: a complete, working package that exercises every pattern the template
documents — a manifest, a namespaced command with an alias, a lifecycle hook,
paired bash/PowerShell scripts, and an optional config file.

## What it checks

All of these are decidable by reading the files, which is exactly why they belong
in a script rather than in a prompt:

| Check | Reported when |
|---|---|
| Artifact presence | `spec.md` is missing, or `tasks.md` exists without a `plan.md` |
| Story coverage | A `### User Story N` in `spec.md` has no task tagged `[USN]` |
| Story orphans | A task is tagged `[USN]` for a story `spec.md` does not define |
| Requirement orphans | A task cites `FR-042` and `spec.md` defines no `FR-042` |
| Duplicate requirement IDs | The same requirement ID is defined twice in `spec.md` |
| Duplicate task IDs | The same `T###` is used by two tasks |
| Unresolved clarifications | `[NEEDS CLARIFICATION]` survives in `spec.md` |
| Requirement coverage | A requirement no task cites — off by default, see configuration |

It also reports counts that are useful without being defects: stories, requirements,
task completion, and clarification markers.

## What it deliberately does not do

It does not judge whether a requirement is well-written, whether the plan is sound,
or whether the tasks would actually implement the spec. Those are semantic
questions and belong to `/speckit.analyze`. This extension answers only the
structural one — do the identifiers and sections line up — and answers it the same
way every time.

## Install

From a local directory:

```bash
specify extension add --dev /path/to/template
specify extension list
```

From a release ZIP:

```bash
specify extension add trace --from https://github.com/jonyfs/spec-kit-extension-template/releases/download/v1.0.0/trace-1.0.0.zip
```

Removal:

```bash
specify extension remove trace --force
```

### Supported distribution forms

| Form | Supported |
|---|---|
| Local directory (`--dev`) | Yes |
| Custom URL (`--from`) | Yes |
| Catalog (`specify extension add trace`) | No — not submitted to a catalog |
| Bundled in the CLI | No — bundling is reserved for core extensions |

## Usage

```text
/speckit.trace.check
/speckit.trace.check 003-payment-links
```

`speckit.trace.verify` is registered as an alias for the same command.

The scripts can also be run directly, which is how CI would use them:

```bash
.specify/extensions/trace/scripts/bash/trace-check.sh
.specify/extensions/trace/scripts/bash/trace-check.sh --json --feature 003-payment-links
```

```powershell
.specify/extensions/trace/scripts/powershell/trace-check.ps1
.specify/extensions/trace/scripts/powershell/trace-check.ps1 -Json -Feature 003-payment-links
```

Both variants accept the same options and produce the same report and the same
JSON. Exit codes:

| Code | Meaning |
|---|---|
| `0` | No findings, or `warn_only` is enabled |
| `1` | At least one finding |
| `2` | No feature directory could be resolved |

### Feature resolution

With no explicit selector the scripts resolve the feature in this order:

1. `SPECIFY_FEATURE` environment variable → `specs/$SPECIFY_FEATURE`
2. Current git branch name → `specs/<branch>`
3. The most recently modified `specs/*/spec.md`

## Hook

One lifecycle hook is declared:

| Event | Command | Optional | Priority |
|---|---|---|---|
| `after_tasks` | `speckit.trace.check` | `true` | `10` |

It is `optional: true`, so it prompts before running and never fires silently.
`after_tasks` is the moment the check has the most to say: `tasks.md` has just
been generated from `plan.md`, and any story or requirement that failed to make
the crossing is visible immediately rather than during implementation.

The hook is safe to accept at any time because the command only reads files.

## Configuration

Optional. Installed to `.specify/extensions/trace/trace-config.yml`; deleting the
file restores the defaults below. Values can be overridden without committing
them by putting the same keys in `.specify/extensions/trace/local-config.yml`,
which takes precedence and is gitignored by the CLI convention.

| Key | Default | Effect |
|---|---|---|
| `requirement_pattern` | `(FR\|NFR\|SC)-[0-9]+` | Extended regex matching a requirement identifier |
| `require_requirement_coverage` | `false` | Report a requirement no task cites as a finding |
| `fail_on_needs_clarification` | `true` | Report a surviving `[NEEDS CLARIFICATION]` marker as a finding |
| `warn_only` | `false` | Report everything but always exit `0` |

Only flat `key: value` pairs are read; nested mappings and lists are ignored.

`require_requirement_coverage` defaults to `false` because the stock Spec Kit
tasks template does not cite requirement IDs in task text at all — turning it on
in a project that does not follow that convention produces nothing but noise.
Turn it on when your team writes `T014 [US2] Implement FR-007 …`.

## Conventions it assumes

Derived from the stock Spec Kit templates:

- User stories are headings: `### User Story 2 - Title (Priority: P2)`
- Requirements are list items whose first bold run is the ID: `- **FR-001**: System MUST …`
- Tasks are checkbox list items whose first token is the ID: `- [ ] T014 [P] [US2] …`
- A task's story is tagged in brackets: `[US2]`

A project that uses different conventions can adjust `requirement_pattern`; the
story and task shapes are fixed, and a project that diverges from them will see
zero stories or zero tasks reported rather than a wrong answer.

## Compatibility

Requires `specify` `>=0.2.0`. Verified against specify-cli 0.11.3 on macOS with
bash 3.2 and PowerShell 7.

## License

MIT — see [LICENSE](LICENSE).
