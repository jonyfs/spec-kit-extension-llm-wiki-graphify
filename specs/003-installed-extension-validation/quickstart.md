# Quickstart: Installed Extension Validation

**Feature**: 003-installed-extension-validation
**Date**: 2026-07-22

How to prove the harness works — which, per Constitution Principle XV, means proving it can
**fail**, not only that it passes against a correct package.

## Prerequisites

- `specify` CLI on `PATH`
- graphify `>=0.9.9,<0.10.0` for the build and config scenarios (absence → those scenarios
  skip, and the run reports `INCOMPLETE`)

## The one command

```bash
bash scripts/validate-installed-extension.sh
```

No arguments (FR-015). Expected on a healthy machine with the current package:

```text
US1  install and register ................. PASS
US1  remove and restore ................... PASS
US2  command script runs as installed ..... PASS
US2  command prose registered ............. PASS
US2  hook aggregated as declared .......... PASS
US2  dependency failure as installed ...... PASS
US3  missing config is silent ............. PASS
US3  config narrows scope ................. FAIL   (script does not read config.yml yet — R4)
US3  config raises the floor .............. FAIL   (same)

Verdict: FAIL — 7 passed, 2 failed, 0 skipped
```

The two `FAIL`s are expected until the feature-002 config-read follow-up lands. They are red
on purpose: the manifest promises config support, and a red test is the honest record of an
unmet promise. This is the decision the plan hands to `/speckit-tasks` — do the follow-up
first, hold US3, or ship US1+US2 with US3's reds tracked to an expiry.

## Proving the harness can fail (FR-012, SC-002)

Run it against each broken-package fixture and confirm the *right* scenario fails:

```bash
bash scripts/validate-installed-extension.sh --package tests/fixtures/broken-packages/missing-command-file
# Expected: US1 install/register FAILs, naming the missing commands/build.md

bash scripts/validate-installed-extension.sh --package tests/fixtures/broken-packages/wrong-command-name
# Expected: US1 register FAILs on the namespace violation

bash scripts/validate-installed-extension.sh --package tests/fixtures/broken-packages/missing-script
# Expected: US2 "command prose registered" FAILs on the unresolved script reference
```

A fixture that produces a *green* run has proven nothing, and the assertion it was meant to
exercise is not an assertion.

## Proving isolation (SC-004)

```bash
git status --porcelain > /tmp/before
bash scripts/validate-installed-extension.sh
git status --porcelain > /tmp/after
diff /tmp/before /tmp/after   # must be empty
```

The developer's own working tree must be byte-for-byte unchanged. The harness works entirely
inside its throwaway project.

## Proving the skip path (SC-005)

```bash
env PATH=/tmp/empty-dir bash scripts/validate-installed-extension.sh
```

With graphify unreachable, expected: the dependency-failure scenario still `PASS`es, the
build and config scenarios report `SKIP`, and the verdict is `INCOMPLETE` — never `PASS`. A
green result on a machine that could not run half the scenarios is the exact failure this
criterion exists to catch.

## Coverage

| Scenario | Requirements |
|---|---|
| install and register | FR-001, FR-002, FR-013 |
| remove and restore | FR-003 |
| command script runs | FR-005, FR-013 |
| command prose registered | FR-005 |
| hook aggregated | FR-006 |
| dependency failure | FR-005 |
| declining the hook | FR-007 |
| config missing / narrows / floor | FR-008, FR-009 |
| broken-package fixtures | FR-012 |
| skip path | FR-010, FR-011 |
| isolation | FR-004 |
| CI on both runners | FR-014 |
