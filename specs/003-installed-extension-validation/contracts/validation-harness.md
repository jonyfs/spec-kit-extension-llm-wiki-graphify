# Contract: Validation Harness

**Artifacts**: `scripts/validate-installed-extension.sh` and its `.ps1` counterpart
**Binds**: FR-001 – FR-015; Constitution Principles VII, XV

One contract, two implementations. Behavioural equivalence is the requirement.

## Invocation

```text
validate-installed-extension.sh [--package <path>]
```

No required arguments (FR-015). `--package` defaults to `extension/`; the broken-package
fixtures pass their own path so the same harness proves each assertion can fail.

## Result model

Every scenario resolves to exactly one of three states. Collapsing skipped into passed is
forbidden — it is how coverage silently disappears (FR-010, FR-011).

| State | Meaning | Counts toward pass? |
|---|---|---|
| `PASS` | The scenario ran and its assertion held | yes |
| `FAIL` | The scenario ran and its assertion did not hold | no — fails the run |
| `SKIP` | A prerequisite was absent; the scenario did not run | no, and does not fail the run, but forces the overall result to `INCOMPLETE` |

The overall verdict is `PASS` only if every scenario is `PASS`. Any `FAIL` → `FAIL`. No
`FAIL` but some `SKIP` → `INCOMPLETE` (SC-005). A bare "passed/failed" is never emitted.

## Prerequisites, checked before anything runs

- **`specify` CLI absent** → the whole harness exits `INCOMPLETE` with a message naming the
  missing prerequisite. This is not a failure of the package (edge case, spec).
- **graphify absent** → the dependency-failure scenarios still run; the build-success and
  config scenarios are `SKIP`, and the run is `INCOMPLETE` (FR-010, SC-005).

## Required scenarios

Grouped by the user story they serve. Each names the observable it checks — never "did not
throw".

### US1 — install cycle

1. **Install and register.** `specify extension add --dev <package>` into a throwaway
   project; assert the extension appears in `.specify/extensions/.registry` and in
   `specify extension list`, and that the declared command name is present (research R2, R5).
2. **Remove and restore.** `specify extension remove`; assert it is gone from the registry
   and listing, and that no extension file remains outside `.specify/extensions/.backup/`
   (research R6).
3. **Cleanup always.** The throwaway `mktemp -d` is removed on every exit path, including a
   trapped interrupt (FR-004).

### US2 — command and hook execute

4. **Command script runs as installed.** Invoke the installed
   `.specify/extensions/llm-wiki-graphify/scripts/bash/graph-build.sh` (or `.ps1`) against
   the code fixture with `build --confirmed`; assert `outcome=built`, the entity and
   relationship counts, and the evidence breakdown verbatim. This is the honest form of
   "invoke the command": the prose command delegates here, and this is what a shell can run
   (research R3).
5. **Command prose is registered and points at real scripts.** Assert
   `commands/build.md` was installed and its frontmatter `scripts.sh` / `scripts.ps` resolve
   to files present in the package. The prose layer is validated by presence and reference,
   not execution — executing it needs an agent (research R3).
6. **Hook is aggregated as declared.** Read `hooks.after_specify` from
   `.specify/extensions.yml`; assert our entry is `optional: true`, `priority: 20`, with the
   manifest's prompt and description (research R2).
7. **Dependency failure as installed.** With graphify absent from `PATH`, invoke the
   installed script; assert `dependency-missing` and no graph — the same result the isolated
   script gives, now proven at the installed path.

### US3 — configuration

> **Blocked on a feature-002 follow-up** — the script does not read `config.yml` yet
> (research R4). Until it does, scenarios 9 and 10 must be reported `FAIL`, not `SKIP`: the
> manifest declares the config, so the unmet promise is a failure. The plan records this as
> the first decision for `/speckit-tasks`.

8. **Missing config is silent.** With no `config.yml`, invoke the installed script; assert it
   runs on defaults and emits no warning about the missing file (FR-008; the config is
   `required: false`).
9. **Config narrows scope.** Write a `config.yml` setting `scope.root` to a subdirectory;
   assert the reported root matches and the graph covers only that subtree (FR-009).
10. **Config raises the floor.** Write a `config.yml` setting `graphify.min_version` above
    the installed version; assert `dependency-too-old`, proving the configured value was read
    (FR-009).

## Broken-package fixtures (FR-012, SC-002)

Each fixture makes exactly one assertion fail, and the harness MUST be observed failing
against it before the fixture is committed.

| Fixture | Breaks | Scenario that must fail |
|---|---|---|
| `missing-command-file/` | manifest names `commands/build.md`; the file is deleted | install (specify rejects it) |
| `wrong-command-name/` | command name does not match `speckit.{id}.{command}` | install (specify rejects it) |
| `missing-script/` | frontmatter references a script absent from the package | install (specify rejects it) |
| `wrong-hook-optional/` | hook declared `optional: false` | **hook aggregated** — installs cleanly, fails the post-install assertion |

**Finding during implementation**: `specify extension add` validates more strictly than
`scripts/validate-extension.py` — it rejects all three manifest-level breaks at install
time, so they never reach a later scenario. That still satisfies "the harness can fail
against a broken package", but it left the *post-install* assertions (hook aggregation,
prose registration) never observed failing. The `wrong-hook-optional/` fixture was added to
close that: it installs cleanly and fails the hook-aggregation assertion specifically, so a
post-install check is proven able to fail (SC-002).

A fixture that does not make a real scenario fail is not proving anything and must not be
added.

## Prohibitions

| The harness MUST NOT | Requirement |
|---|---|
| Write anywhere outside its throwaway project | SC-004 |
| Report a skipped scenario as passed | FR-010 |
| Emit a bare pass/fail without the per-scenario breakdown | FR-011 |
| Install or modify graphify | Principle XVI |
| Touch the developer's own installed extensions | edge case, spec |
| Conclude "extension absent" from an unrecognised CLI format | research R5 — fail loudly instead |

## Parity (Principle V)

Both variants produce the same per-scenario states and the same overall verdict for the same
package and environment. Proven by running both in CI on their respective runners, never by
reading the two side by side.
