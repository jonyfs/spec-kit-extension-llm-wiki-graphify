#!/usr/bin/env bash
# Principle VII: install-test before publish.
#
# Manifest validation proves the YAML parses. Only an install-run-remove cycle
# against a real Spec Kit project proves the extension actually installs, that
# every referenced file resolves at the depth the installer expects, and that
# removal leaves nothing behind.
#
# This covers the local-directory (--dev) distribution form. The ZIP forms are
# proven at release time against the published asset, per Principle XII.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Collect the packages this repository is responsible for. Vendored third-party
# extensions under .specify/extensions/ are excluded: they are already installed
# by definition, and they belong to their upstream authors.
packages=()
while IFS= read -r manifest; do
  package_dir="$(dirname "$manifest")"
  [[ "$package_dir" == "$REPO_ROOT/.specify/extensions/"* ]] && continue
  # Deliberately invalid fixtures exist to prove the validator fails; they are
  # not installable packages.
  [[ "$package_dir" == "$REPO_ROOT/tests/fixtures/"* ]] && continue
  packages+=("$package_dir")
done < <(find "$REPO_ROOT" -name extension.yml -not -path '*/.git/*')

if [ ${#packages[@]} -eq 0 ]; then
  echo "No first-party extension packages found — nothing to install-test."
  echo "This is expected while the template has no extension of its own yet."
  exit 0
fi

echo "Install-testing ${#packages[@]} package(s)"

cd "$WORK_DIR"
specify init test-project --integration claude --ignore-agent-tools
cd test-project

failures=0

for package_dir in "${packages[@]}"; do
  # BSD sed (macOS) has no \s; [[:space:]] is portable across BSD and GNU.
  ext_id="$(grep -E '^[[:space:]]+id:' "$package_dir/extension.yml" | head -1 |
    sed -E 's/.*id:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
  echo
  echo "=== $ext_id ($package_dir)"

  if ! specify extension add --dev "$package_dir"; then
    echo "FAIL: install failed for $ext_id"
    failures=$((failures + 1))
    continue
  fi

  # Capture first: `grep -q` exits on first match, which SIGPIPEs `specify`, and
  # `set -o pipefail` then reports the *matching* case as a failure.
  listing="$(specify extension list)"
  if ! grep -q "$ext_id" <<< "$listing"; then
    echo "FAIL: $ext_id installed but does not appear in 'extension list'"
    failures=$((failures + 1))
    continue
  fi

  if ! specify extension info "$ext_id" > /dev/null; then
    echo "FAIL: 'extension info' failed for $ext_id"
    failures=$((failures + 1))
    continue
  fi

  if ! specify extension remove "$ext_id" --force; then
    echo "FAIL: removal failed for $ext_id"
    failures=$((failures + 1))
    continue
  fi

  if [ -d ".specify/extensions/$ext_id" ]; then
    echo "FAIL: $ext_id left .specify/extensions/$ext_id behind after removal"
    failures=$((failures + 1))
    continue
  fi

  echo "OK: $ext_id install -> list -> info -> remove"
done

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures package(s) failed the install-test cycle"
  exit 1
fi
echo "All ${#packages[@]} package(s) passed the install-test cycle"
