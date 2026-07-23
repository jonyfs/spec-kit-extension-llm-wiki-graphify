#!/usr/bin/env bash
#
# validate-installed-extension.sh — prove the llm-wiki-graphify package works
# AS INSTALLED, not just that its manifest parses.
#
# Contract: specs/003-installed-extension-validation/contracts/validation-harness.md
#
# This is the layer above scripts/test-graph-build.sh: that suite tests the scripts
# in isolation; this installs the package into a throwaway Spec Kit project via the
# real `specify` CLI, exercises the registered command's script and the aggregated
# hook, tests the three config states, removes the extension, and confirms nothing
# was left behind. It mechanizes Constitution Principle VII.
#
# Result model: every scenario is PASS, FAIL, or SKIP. The overall verdict is PASS
# only if all pass; FAIL on any fail; INCOMPLETE on any skip. A bare pass/fail is
# never emitted — collapsing skipped into passed is how coverage disappears.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO_ROOT
readonly FIXTURES="${REPO_ROOT}/tests/fixtures"

PACKAGE="${REPO_ROOT}/extension"

while [ $# -gt 0 ]; do
    case "$1" in
        --package)
            [ $# -ge 2 ] || { echo "--package requires a value" >&2; exit 2; }
            PACKAGE="$2"
            shift 2
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 2
            ;;
    esac
done
# Absolute, because install_into cd's into the throwaway project first and a
# relative package path would then resolve against the wrong directory.
PACKAGE="$(cd "$PACKAGE" 2>/dev/null && pwd -P || echo "$PACKAGE")"
readonly PACKAGE

WORK="$(mktemp -d)"
readonly WORK
trap 'rm -rf "$WORK"' EXIT INT TERM

BASH_BIN="$(command -v bash)"
readonly BASH_BIN

PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
skip() { printf '  SKIP  %s — %s\n' "$1" "$2"; SKIP=$((SKIP + 1)); }
fail() {
    printf '  FAIL  %s\n' "$1"
    [ -n "${2:-}" ] && printf '        %s\n' "$2"
    FAIL=$((FAIL + 1))
}

# --- Prerequisites -----------------------------------------------------------

if ! command -v specify >/dev/null 2>&1; then
    echo "PREREQUISITE MISSING: the specify CLI is not installed." >&2
    echo "This is not a failure of the package. Install specify and re-run." >&2
    echo
    echo "Verdict: INCOMPLETE — specify CLI absent"
    exit 0
fi

GRAPHIFY_PRESENT=0
command -v graphify >/dev/null 2>&1 && GRAPHIFY_PRESENT=1

# make_project <name> — a fresh throwaway Spec Kit project. Prints its path.
make_project() {
    local dir="${WORK}/$1"
    mkdir -p "$dir"
    (cd "$dir" && specify init --here --integration claude --script sh --force >/dev/null 2>&1)
    printf '%s\n' "$dir"
}

install_into() {
    (cd "$1" && specify extension add --dev "$2" >/dev/null 2>&1)
}

# --- US1: install cycle ------------------------------------------------------

printf '\nUS1 — install cycle\n'

P1="$(make_project p1)"
if install_into "$P1" "$PACKAGE"; then
    registry="${P1}/.specify/extensions/.registry"
    if [ -f "$registry" ] && grep -q 'llm-wiki-graphify' "$registry"; then
        pass "install and register — extension is in the registry"
    else
        fail "install and register — extension is in the registry" "registry missing the id"
    fi

    if (cd "$P1" && specify extension list 2>/dev/null | grep -qi 'graphify'); then
        pass "install and register — the CLI listing agrees"
    else
        fail "install and register — the CLI listing agrees" "not shown by 'extension list'"
    fi

    manifest="${P1}/.specify/extensions/llm-wiki-graphify/extension.yml"
    if [ -f "$manifest" ] && grep -q 'speckit.llm-wiki-graphify.build' "$manifest"; then
        pass "install and register — the declared command name is present"
    else
        fail "install and register — the declared command name is present" ""
    fi

    if (cd "$P1" && specify extension remove llm-wiki-graphify --force >/dev/null 2>&1); then
        if grep -q 'llm-wiki-graphify' "$registry" 2>/dev/null; then
            fail "remove and restore — gone from the registry" "still present"
        else
            pass "remove and restore — gone from the registry"
        fi
        leftover="$(find "${P1}/.specify/extensions" -path '*/llm-wiki-graphify/*' \
            -not -path '*/.backup/*' 2>/dev/null | head -n 1)"
        if [ -z "$leftover" ]; then
            pass "remove and restore — nothing left outside the backup location"
        else
            fail "remove and restore — nothing left outside the backup location" "found ${leftover}"
        fi
    else
        fail "remove and restore — remove succeeded" ""
    fi
else
    # For a correct package this is a failure; for a broken fixture this is the
    # expected outcome and the scenario correctly reports FAIL.
    fail "install and register — the package installs at all" \
        "specify extension add rejected the package"
fi

# --- US2: command and hook execute -------------------------------------------

printf '\nUS2 — command and hook execute\n'

P2="$(make_project p2)"
if install_into "$P2" "$PACKAGE"; then
    ext="${P2}/.specify/extensions/llm-wiki-graphify"

    # Command prose registered, and its declared scripts resolve.
    cmd="${ext}/commands/build.md"
    if [ -f "$cmd" ]; then
        sh_ref="$(grep -E '^[[:space:]]*sh:' "$cmd" | head -n 1 | awk -F'sh:' '{gsub(/^[[:space:]]+/,"",$2); print $2}')"
        if [ -n "$sh_ref" ] && [ -f "${ext}/${sh_ref}" ]; then
            pass "command prose registered — its declared script resolves"
        else
            fail "command prose registered — its declared script resolves" \
                "frontmatter names ${sh_ref:-<none>}, which is absent"
        fi
    else
        fail "command prose registered — commands/build.md installed" "not found"
    fi

    # Hook aggregated as declared.
    hook_ok="$(python3 - "${P2}/.specify/extensions.yml" <<'PY'
import sys
try:
    import yaml
    d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
except Exception as exc:
    print(f"error {exc}")
    sys.exit(0)
for h in (d.get("hooks", {}) or {}).get("after_specify", []) or []:
    if h.get("extension") == "llm-wiki-graphify":
        ok = (h.get("optional") is True and h.get("priority") == 20
              and h.get("prompt") and h.get("description"))
        print("ok" if ok else "wrong")
        sys.exit(0)
print("absent")
PY
)"
    case "$hook_ok" in
        ok) pass "hook aggregated — after_specify is optional:true, priority 20, with prompt and description" ;;
        *) fail "hook aggregated as declared" "hook state: ${hook_ok}" ;;
    esac

    # Command script runs as installed — needs graphify.
    installed_sh="${ext}/scripts/bash/graph-build.sh"
    if [ "$GRAPHIFY_PRESENT" -eq 1 ] && [ -f "$installed_sh" ]; then
        run="${WORK}/p2run"
        cp -R "${FIXTURES}/graph-build-code" "$run"
        out="$(cd "$run" && "$BASH_BIN" "$installed_sh" build --confirmed 2>/dev/null)"
        oc="$(printf '%s\n' "$out" | grep '^outcome=' | cut -d= -f2)"
        ent="$(printf '%s\n' "$out" | grep '^entities=' | cut -d= -f2)"
        if [ "$oc" = "built" ] && [ "$ent" = "5" ]; then
            pass "command script runs as installed — builds with the expected counts"
        else
            fail "command script runs as installed" "outcome=${oc}, entities=${ent}"
        fi
    elif [ ! -f "$installed_sh" ]; then
        fail "command script runs as installed — the script is present" "not installed"
    else
        skip "command script runs as installed" "graphify not installed"
    fi

    # Dependency failure as installed.
    if [ -f "$installed_sh" ]; then
        mkdir -p "${WORK}/nopath"
        dep_out="$(env PATH="${WORK}/nopath" "$BASH_BIN" "$installed_sh" check 2>/dev/null)"
        dep_code=$?
        if [ "$dep_code" -eq 4 ] && printf '%s' "$dep_out" | grep -q 'dependency-missing'; then
            pass "dependency failure as installed — reports dependency-missing"
        else
            fail "dependency failure as installed" "exit ${dep_code}"
        fi
    fi
else
    fail "US2 could not run — the package installs" "add rejected the package"
fi

# --- US3: configuration ------------------------------------------------------

printf '\nUS3 — configuration honoured\n'

P3="$(make_project p3)"
if install_into "$P3" "$PACKAGE"; then
    ext3="${P3}/.specify/extensions/llm-wiki-graphify"
    installed_sh3="${ext3}/scripts/bash/graph-build.sh"

    if [ -f "$installed_sh3" ]; then
        # Missing config is silent.
        none_out="$(cd "$P3" && "$BASH_BIN" "$installed_sh3" check 2>&1 >/dev/null || true)"
        if printf '%s' "$none_out" | grep -qi 'config'; then
            fail "missing config is silent" "warned: ${none_out}"
        else
            pass "missing config is silent — no warning about the absent file"
        fi

        # Config raises the floor — proves the value was read.
        printf 'graphify:\n  min_version: "99.0.0"\n' >"${ext3}/config.yml"
        floor_out="$(cd "$P3" && "$BASH_BIN" "$installed_sh3" check 2>/dev/null)"
        floor_code=$?
        if [ "$floor_code" -eq 5 ] && printf '%s' "$floor_out" | grep -q 'dependency-too-old'; then
            pass "config raises the floor — proves config.yml was read"
        else
            fail "config raises the floor" "exit ${floor_code}"
        fi

        # Malformed config stops distinctly.
        printf 'scope\n  root no colon\n' >"${ext3}/config.yml"
        bad_out="$(cd "$P3" && "$BASH_BIN" "$installed_sh3" check 2>/dev/null)"
        bad_code=$?
        if [ "$bad_code" -eq 2 ] && printf '%s' "$bad_out" | grep -q 'config-invalid'; then
            pass "malformed config stops distinctly, not silently defaulted"
        else
            fail "malformed config stops distinctly" "exit ${bad_code}"
        fi
    else
        fail "US3 could not run — the installed script is present" ""
    fi
else
    fail "US3 could not run — the package installs" ""
fi

# --- Verdict -----------------------------------------------------------------

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
    echo "Verdict: FAIL"
    exit 1
elif [ "$SKIP" -gt 0 ]; then
    echo "Verdict: INCOMPLETE — some scenarios were skipped"
    exit 0
else
    echo "Verdict: PASS"
    exit 0
fi
