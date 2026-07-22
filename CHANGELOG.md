# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `trace` reference extension in `template/` — a read-only feature-traceability check
  (`speckit.trace.check`) that reports stories with no tagged tasks, tasks citing
  undefined requirement IDs, duplicate IDs, and surviving `[NEEDS CLARIFICATION]`
  markers. Ships bash and PowerShell at parity and exists to be copied as the starting
  point for a new extension.

### Fixed

- `scripts/install-test.sh` could not pass on macOS for any package. The extension id
  was extracted with sed's `\s`, a GNU extension BSD sed silently ignores; and
  `specify extension list | grep -q` under `set -o pipefail` reported the *matching*
  case as a failure, because `grep -q` exits at first match and `specify` takes SIGPIPE.
  Both were invisible while the repository had no extension to test.

- `sdd-master` skill (`.claude/skills/sdd-master/`) — proactive expertise on
  spec-driven development and Spec Kit. A router holding the four-band effort
  classification and signal table, plus four references loaded on demand and split
  by source of truth: `workflow.md`, `craft.md`, `recovery.md`, `ecosystem.md`.
  Its guidance is deliberately proportionate — the documented failure of
  spec-driven development is applying it uniformly, not skipping it. Evaluated
  against a no-skill baseline on three behavioral cases (17 of 17 assertions) and
  a 20-query trigger set.

- Project constitution (`.specify/memory/constitution.md`) defining thirteen
  principles for authoring Spec Kit extensions.
- `docs/HOOKS.md` — reference for both hook layers: Spec Kit lifecycle hooks
  declared in `extension.yml`, and harness hooks that execute shell commands.
- `docs/PACKAGING.md` — reference for all four distribution forms the `specify`
  CLI supports, verified against specify-cli 0.11.3.
- `scripts/validate-extension.py` — manifest, command-namespacing, hook, and
  script-parity validation.
- `scripts/check-placeholders.sh` — guards against template placeholders
  surviving into a release.
- `scripts/install-test.sh` — the install → list → info → remove cycle.
- GitHub Actions CI running lint, manifest validation, the placeholder guard,
  and the install-test cycle on every pull request.
- Vendored `caveman` skill from `juliusbrussee/caveman` (MIT) with provenance.
- Six community Spec Kit extensions installed as the project baseline:
  `worktrees`, `ship`, `critique`, `staff-review`,
  `speckit-superpowers-bridge`, and `onboard`.
