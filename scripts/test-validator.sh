#!/usr/bin/env bash
# Constitution Principle XV: a check that cannot fail is not a check.
#
# scripts/validate-extension.py gates every extension package in this repository.
# Until it has been observed rejecting something, its green tells us nothing —
# passing and being unreachable produce identical output. This asserts it fails,
# and fails for the right reasons.
#
# The companion failure this repository actually shipped: install-test.sh was green
# in CI while being incapable of passing on macOS, because it exited early with
# "no packages found" before reaching the bug.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/invalid-extension"
VALIDATOR="$REPO_ROOT/scripts/validate-extension.py"

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

echo "Asserting the validator rejects a deliberately invalid package"

output="$(python3 "$VALIDATOR" "$FIXTURE" 2>&1)" && rc=0 || rc=$?

if [ "$rc" -eq 0 ]; then
  echo "$output"
  fail "validator exited 0 on a package that violates six rules"
  exit 1
fi

# Each expected error, and the principle it enforces. If the validator stops
# detecting any of these, this test says which one — a bare non-zero exit would
# not, and a validator that fails for the wrong reason is still broken.
declare -a expectations=(
  "must match \^\[a-z0-9-\]\+\\\$|I: extension.id pattern"
  "must be X.Y.Z|VIII: semantic version shape"
  "must be a specifier with no spaces|I: speckit_version specifier"
  "shadows a core Spec Kit command|II: no core command shadowing"
  "references missing file|I: every referenced path exists"
  "not a recognized Spec Kit lifecycle event|XI: known hook events only"
)

for expectation in "${expectations[@]}"; do
  pattern="${expectation%%|*}"
  label="${expectation#*|}"
  if ! grep -qE "$pattern" <<< "$output"; then
    fail "validator did not report — $label"
  fi
done

if [ "$failures" -gt 0 ]; then
  echo
  echo "Validator output was:"
  echo "$output"
  exit 1
fi

echo "OK: validator exited $rc and reported all six expected violations"
