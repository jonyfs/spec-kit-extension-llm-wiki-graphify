# Phase 0 Research: Installed Extension Validation

**Feature**: 003-installed-extension-validation
**Date**: 2026-07-22

Every finding below was produced by running the `specify` CLI, not by recall. Verified
against **specify-cli** as installed in this environment, with the feature-002 `extension/`
package.

---

## R1: A throwaway project is created by the CLI, non-interactively

**Decision**: Build the throwaway project with
`specify init --here --integration claude --script sh --force` inside a fresh `mktemp -d`.

**Evidence**:

```text
$ cd "$(mktemp -d)" && specify init --here --integration claude --script sh --force
$ ls -a
.  ..  .claude  .specify  CLAUDE.md
```

`--force` skips the confirmation prompt, `--here` targets the current directory, and
`--script sh` fixes the variant. The result is a project shaped the way a real one is —
which is the point of using the CLI rather than hand-assembling a `.specify/` tree.

**Rationale**: FR-001 requires a throwaway project that is never the developer's own. A
`mktemp -d` guarantees isolation; letting the CLI populate it guarantees fidelity.

---

## R2: The hook is aggregated into `.specify/extensions.yml` with our exact values

**Decision**: Validate the hook by reading `.specify/extensions.yml` after install and
asserting our entry's `optional`, `priority`, and `prompt` match the manifest. This is a
structured file, so no fragile text parsing is needed.

**Evidence**: After `specify extension add --dev extension/`:

```python
{'command': 'speckit.llm-wiki-graphify.build', 'optional': True,
 'priority': 20, 'prompt': 'Build or refresh the project knowledge graph now?'}
```

read straight from `hooks.after_specify` in the aggregated file. The values are exactly what
`extension/extension.yml` declares.

**Rationale**: FR-006 (confirm the hook is registered with the declared optionality,
prompt, and description) is satisfied by a structured read, not by observing the hook fire
— which would require driving a full agent workflow.

---

## R3: The command installs as an agent SKILL, and cannot be executed by a shell

**Decision**: Validate the command at two levels, and be honest that they are different
levels. **Registration**: assert the CLI installed `commands/build.md` and generated the
agent skill. **Execution**: invoke the *underlying script* the command delegates to, which
is the part a shell can actually run.

**Evidence**: After install, the CLI produced:

```text
.specify/extensions/llm-wiki-graphify/commands/build.md
.specify/extensions/llm-wiki-graphify/.specify-dev/agent-commands/claude/
    speckit-llm-wiki-graphify-build/SKILL.md
```

The command is a Markdown instruction the *agent* executes, not an executable. There is no
shell entry point for `build.md` itself.

**Consequence — a limitation stated plainly**: FR-005 says "invoke every declared command
and check its observable result". For a command that is agent-executed prose, "invoke" at
the shell level means invoking the script it delegates to, with the arguments the command
contract specifies, and asserting the same observable results the command would produce —
the graph, the counts, the coverage statement. The prose layer itself is validated by
presence and by a check that its declared `scripts.sh` / `scripts.ps` targets exist and
match the shipped scripts. Claiming a shell test "executed the command" would overstate
what happened; the plan says script instead.

This is not a gap in coverage — the script *is* where every observable effect originates,
and the feature-002 suites already exercise it in isolation. What feature 003 adds is
proving the script is reachable and correct **as installed**, at the path the CLI placed
it, rather than from the source tree.

---

## R4: Config is not installed as `config.yml`; only the template ships

**Decision**: Test the three config states by writing `config.yml` into the installed
extension's own directory before invoking, and by testing its absence with no file present.

**Evidence**: After install, the extension directory contains `config-template.yml` but no
`config.yml`:

```text
CHANGELOG.md  commands  config-template.yml  extension.yml  LICENSE  README.md  scripts
```

The template is the shipped default; the live config is something the maintainer creates.
Its declared location is `.specify/extensions/llm-wiki-graphify/config.yml`
(data-model.md, feature 002).

**Rationale**: FR-008 requires covering missing, behaviour-changing, and malformed config.
"Missing" is the default install state — nothing to construct. The other two are
constructed by writing a `config.yml` and asserting an observable difference (a narrowed
scope root; a raised version floor that trips `dependency-too-old`).

**Caveat to verify at implementation time**: feature 002 shipped the config *contract* and
the script's version-range handling, but the script does not yet *read* a project
`config.yml` — the defaults are compiled in. So FR-009's "a configured value takes effect"
may require a small feature-002 follow-up (the script reading the config file) before US3
can pass. This is flagged in the plan as a dependency, not smuggled in as scope. If the
read does not exist, US3's config-honouring scenarios must be reported as **failing**, not
skipped — the promise exists in the manifest, so an unmet promise is a failure.

---

## R5: `specify extension list` and `info` are human-readable, not structured

**Decision**: Where the CLI emits only human-readable text, match on stable substrings (the
extension id, the version, the ✓/✗ marker) and **fail loudly on an unrecognised format**
rather than concluding the extension is absent.

**Evidence**: `specify extension list` prints:

```text
  ✓ LLM Wiki Graphify (v1.0.0)
     llm-wiki-graphify
     Builds and refreshes a graphify knowledge graph of the project...
```

No `--json` flag is exposed on `list` or `info`. The registry file
`.specify/extensions/.registry` is structured, so identity and version are read from there;
the CLI text is used only to confirm the CLI itself agrees.

**Rationale**: Edge case "the CLI changes its output format". Reading the registry for facts
and the CLI text only for corroboration means a format change degrades one check rather than
silently inverting a result.

---

## R6: Removal restores the tree, backing config up rather than deleting it

**Decision**: Assert removal by re-reading the registry and the CLI listing, and assert no
extension file remains outside `.specify/extensions/.backup/`.

**Evidence**: `scripts/install-test.sh` already exercises this for both packages and
observed the CLI reporting `Config files backed up to .specify/extensions/.backup/`. Removal
is clean but not destructive — the backup location is expected and must be excluded from the
"nothing left behind" assertion.

**Rationale**: FR-003 says "no extension-created file remains outside the CLI's own backup
location". The backup *is* the CLI's own, so it is explicitly carved out.

---

## Resolved unknowns

| Unknown | Resolved by |
|---|---|
| How to create an isolated real project | R1 |
| How to check the hook without driving an agent | R2 |
| Whether the command can be shell-executed | R3 (no — validate the script it delegates to) |
| How config install actually works | R4 |
| Whether CLI output is machine-readable | R5 (registry yes, list/info no) |
| What removal leaves behind | R6 |

One dependency is surfaced rather than resolved: R4's note that the script may not yet read
a project `config.yml`. The plan treats it as a prerequisite for US3, not as hidden scope.
