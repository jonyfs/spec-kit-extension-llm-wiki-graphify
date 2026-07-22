# Changelog

All notable changes to the `trace` extension are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-22

### Added

- `speckit.trace.check` command (alias `speckit.trace.verify`): a read-only
  traceability report for the current feature's `spec.md`, `plan.md` and
  `tasks.md`.
- Checks: missing artifacts, `tasks.md` without a `plan.md`, user stories with no
  tasks, tasks tagged with an undefined user story, tasks citing an undefined
  requirement ID, duplicate requirement IDs, duplicate task IDs, unresolved
  `[NEEDS CLARIFICATION]` markers, and optional requirement coverage.
- Paired implementations `scripts/bash/trace-check.sh` and
  `scripts/powershell/trace-check.ps1` with identical options, output and exit
  codes; `--json` / `-Json` for machine consumption.
- Feature resolution from an explicit selector, `SPECIFY_FEATURE`, the current
  git branch, or the most recently modified `specs/*/spec.md`.
- Optional `after_tasks` lifecycle hook, `optional: true` with a prompt.
- Optional configuration at `.specify/extensions/trace/trace-config.yml` with
  `requirement_pattern`, `require_requirement_coverage`,
  `fail_on_needs_clarification` and `warn_only`, overridable via
  `local-config.yml`.

[Unreleased]: https://github.com/jonyfs/spec-kit-extension-template/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jonyfs/spec-kit-extension-template/releases/tag/v1.0.0
