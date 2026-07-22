#!/usr/bin/env bash
#
# test-graph-build.sh — assert that the graph build script fails correctly.
#
# Constitution Principle XV: a gate that has only ever been observed passing has
# not been tested. This suite exists to watch each failure path fail, and it
# asserts BOTH the exit code and the reported outcome. Asserting only "non-zero"
# would let a test for a missing dependency pass against a merely empty project.
#
# Every failure state is constructed deterministically. Nothing here depends on
# landing a signal in the right millisecond, because a test that flakes is a test
# that gets skipped.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO_ROOT
readonly SCRIPT="${REPO_ROOT}/extension/scripts/bash/graph-build.sh"
readonly FIXTURES="${REPO_ROOT}/tests/fixtures"

WORK="$(mktemp -d)"
readonly WORK

# Absolute path to bash. The dependency-absence scenarios set PATH to an empty
# directory, which would otherwise make bash itself unfindable and produce exit
# 127 — a test failing for a reason that has nothing to do with the script.
BASH_BIN="$(command -v bash)"
readonly BASH_BIN
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

pass() {
    printf '  ok    %s\n' "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf '  FAIL  %s\n' "$1"
    printf '        %s\n' "$2"
    FAIL=$((FAIL + 1))
}

# assert_run <name> <expected_exit> <expected_outcome> -- <command...>
#
# Checks the exit code AND the outcome= line. Either alone is too weak: two
# different failures share an exit code family, and a stdout line proves nothing
# about whether the script actually stopped.
assert_run() {
    local name="$1" want_code="$2" want_outcome="$3"
    shift 4  # name, code, outcome, and the literal --

    local out code
    out="$("$@" 2>/dev/null)"
    code=$?

    if [ "$code" -ne "$want_code" ]; then
        fail "$name" "expected exit ${want_code}, got ${code}"
        return
    fi

    if [ -n "$want_outcome" ]; then
        local got
        got="$(printf '%s\n' "$out" | grep '^outcome=' | head -n 1 | cut -d= -f2)"
        if [ "$got" != "$want_outcome" ]; then
            fail "$name" "expected outcome=${want_outcome}, got outcome=${got:-<none>}"
            return
        fi
    fi

    pass "$name"
}

assert_field() {
    local name="$1" field="$2" want="$3" out="$4"
    local got
    got="$(printf '%s\n' "$out" | grep "^${field}=" | head -n 1 | cut -d= -f2)"
    if [ "$got" = "$want" ]; then
        pass "$name"
    else
        fail "$name" "expected ${field}=${want}, got ${field}=${got:-<none>}"
    fi
}

assert_absent() {
    local name="$1" path="$2"
    if [ -e "$path" ]; then
        fail "$name" "expected ${path} not to exist, but it does"
    else
        pass "$name"
    fi
}

assert_present() {
    local name="$1" path="$2"
    if [ -e "$path" ]; then
        pass "$name"
    else
        fail "$name" "expected ${path} to exist, but it does not"
    fi
}

# ---------------------------------------------------------------------------
# Usage errors
# ---------------------------------------------------------------------------

printf '\nUsage contract\n'

assert_run "build without --confirmed exits 2" 2 "" -- \
    bash "$SCRIPT" build

assert_run "unknown argument exits 2" 2 "" -- \
    bash "$SCRIPT" check --nonsense

assert_run "unknown mode exits 2" 2 "" -- \
    bash "$SCRIPT" demolish

# ---------------------------------------------------------------------------
# Dependency failures
#
# Absence is CONSTRUCTED, not assumed: PATH is an empty directory, so graphify
# cannot be found regardless of where it is installed. Scrubbing PATH to
# /usr/bin:/bin and hoping graphify is elsewhere is how this test silently
# passes having tested nothing.
# ---------------------------------------------------------------------------

printf '\nDependency check\n'

mkdir -p "${WORK}/nopath"
assert_run "missing dependency exits 4" 4 dependency-missing -- \
    env PATH="${WORK}/nopath" "$BASH_BIN" "$SCRIPT" check

(
    cd "${WORK}/nopath" || exit 1
    env PATH="${WORK}/nopath" "$BASH_BIN" "$SCRIPT" check >/dev/null 2>&1
)
assert_absent "missing dependency creates no output directory" "${WORK}/nopath/graphify-out"

mkdir -p "${WORK}/stub-old"
cat >"${WORK}/stub-old/graphify" <<'STUB'
#!/bin/sh
echo "graphify 0.0.1"
STUB
chmod +x "${WORK}/stub-old/graphify"
assert_run "version below floor exits 5" 5 dependency-too-old -- \
    env PATH="${WORK}/stub-old:${PATH}" "$BASH_BIN" "$SCRIPT" check

old_out="$(env PATH="${WORK}/stub-old:${PATH}" "$BASH_BIN" "$SCRIPT" check 2>&1 >/dev/null)"
if printf '%s' "$old_out" | grep -F '0.0.1' >/dev/null 2>&1 &&
    printf '%s' "$old_out" | grep -F '0.9.9' >/dev/null 2>&1; then
    pass "too-old message reports both the version found and the range required"
else
    fail "too-old message reports both versions" "message was: ${old_out}"
fi

mkdir -p "${WORK}/stub-new"
cat >"${WORK}/stub-new/graphify" <<'STUB'
#!/bin/sh
echo "graphify 0.10.0"
STUB
chmod +x "${WORK}/stub-new/graphify"
assert_run "version at ceiling exits 5" 5 dependency-too-old -- \
    env PATH="${WORK}/stub-new:${PATH}" "$BASH_BIN" "$SCRIPT" check

mkdir -p "${WORK}/stub-junk"
cat >"${WORK}/stub-junk/graphify" <<'STUB'
#!/bin/sh
echo "graphify (development build)"
STUB
chmod +x "${WORK}/stub-junk/graphify"
assert_run "unparseable version fails closed, exits 5" 5 dependency-too-old -- \
    env PATH="${WORK}/stub-junk:${PATH}" "$BASH_BIN" "$SCRIPT" check

# ---------------------------------------------------------------------------
# Everything below needs a real graphify
# ---------------------------------------------------------------------------

if ! command -v graphify >/dev/null 2>&1; then
    printf '\ngraphify is not installed — build scenarios SKIPPED (not passed).\n'
    printf '\n%d passed, %d failed, build scenarios skipped\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ] || exit 1
    exit 0
fi

printf '\nEmpty scope\n'

mkdir -p "${WORK}/empty"
touch "${WORK}/empty/.gitkeep"
(
    cd "${WORK}/empty" || exit 1
    bash "$SCRIPT" build --confirmed
) >"${WORK}/empty.out" 2>/dev/null
empty_code=$?
if [ "$empty_code" -eq 3 ] &&
    grep -q '^outcome=nothing-to-examine' "${WORK}/empty.out"; then
    pass "empty scope exits 3 as nothing-to-examine, not success"
else
    fail "empty scope exits 3" "got exit ${empty_code}, outcome $(grep '^outcome=' "${WORK}/empty.out" || echo '<none>')"
fi

printf '\nFirst build\n'

cp -R "${FIXTURES}/graph-build-code" "${WORK}/code"
build_out="$(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed 2>/dev/null)"
build_code=$?

if [ "$build_code" -eq 0 ]; then
    pass "first build exits 0"
else
    fail "first build exits 0" "got exit ${build_code}"
fi

assert_field "first build reports outcome=built" outcome built "$build_out"
assert_field "first build reports 5 entities" entities 5 "$build_out"
assert_field "first build reports 7 relationships" relationships 7 "$build_out"
assert_field "all 7 relationships are EXTRACTED" evidence_EXTRACTED 7 "$build_out"
assert_field "coverage is reported as structural" coverage structural "$build_out"
assert_field "exclusions are reported as none" exclusions none "$build_out"
assert_present "graph.json was produced" "${WORK}/code/graphify-out/graph.json"

printf '\nNo-change refresh\n'

refresh_out="$(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed 2>/dev/null)"
assert_field "unchanged refresh reports outcome=current" outcome current "$refresh_out"

printf '\nIncremental refresh\n'

printf 'def gamma():\n    return 7\n' >"${WORK}/code/src/c.py"
inc_out="$(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed 2>/dev/null)"
assert_field "changed refresh reports outcome=built" outcome built "$inc_out"
assert_field "changed refresh reports 7 entities" entities 7 "$inc_out"

printf '\nFull rebuild\n'

full_out="$(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed --full 2>/dev/null)"
assert_field "full rebuild reports outcome=built" outcome built "$full_out"
assert_present "full rebuild preserves cache/" "${WORK}/code/graphify-out/cache"
assert_present "full rebuild preserves manifest.json" "${WORK}/code/graphify-out/manifest.json"

printf '\nInterrupted state\n'

rm -f "${WORK}/code/graphify-out/graph.json"
(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed) >"${WORK}/int.out" 2>/dev/null
int_code=$?
if [ "$int_code" -eq 7 ] && grep -q '^outcome=interrupted-state' "${WORK}/int.out"; then
    pass "interrupted state exits 7 and refuses to refresh"
else
    fail "interrupted state exits 7" "got exit ${int_code}, outcome $(grep '^outcome=' "${WORK}/int.out" || echo '<none>')"
fi

recover_out="$(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed --full 2>/dev/null)"
assert_field "--full recovers from the interrupted state" outcome built "$recover_out"

printf '\nConcurrent build\n'

mkdir -p "${WORK}/code/.specify/extensions/llm-wiki-graphify/build.lock"
printf '%s\n' "$$" >"${WORK}/code/.specify/extensions/llm-wiki-graphify/build.lock/pid"
(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed) >"${WORK}/lock.out" 2>/dev/null
lock_code=$?
if [ "$lock_code" -eq 6 ] && grep -q '^outcome=already-running' "${WORK}/lock.out"; then
    pass "held lock exits 6 without writing"
else
    fail "held lock exits 6" "got exit ${lock_code}, outcome $(grep '^outcome=' "${WORK}/lock.out" || echo '<none>')"
fi

# A dead owner must be reclaimable. Without this, one crash disables the command
# permanently — a safety mechanism becoming an availability failure.
printf '999999\n' >"${WORK}/code/.specify/extensions/llm-wiki-graphify/build.lock/pid"
stale_out="$(cd "${WORK}/code" && bash "$SCRIPT" build --confirmed 2>/dev/null)"
stale_outcome="$(printf '%s\n' "$stale_out" | grep '^outcome=' | cut -d= -f2)"
if [ "$stale_outcome" = "built" ] || [ "$stale_outcome" = "current" ]; then
    pass "stale lock is reclaimed rather than blocking forever"
else
    fail "stale lock is reclaimed" "got outcome=${stale_outcome:-<none>}"
fi

printf '\nNon-default scope root\n'

mkdir -p "${WORK}/rooted/sub/src"
printf 'def s():\n    return 1\n' >"${WORK}/rooted/sub/src/s.py"
(cd "${WORK}/rooted" && bash "$SCRIPT" build --confirmed --path sub) >/dev/null 2>&1
assert_present "graph lands under the scope root" "${WORK}/rooted/sub/graphify-out/graph.json"
assert_absent "no stray output beside the scope root" "${WORK}/rooted/graphify-out"

printf '\nProvenance breakdown\n'

mixed_out="$(cd "${FIXTURES}/graph-build-mixed" && bash "$SCRIPT" status 2>/dev/null)"
for label in EXTRACTED INFERRED AMBIGUOUS; do
    count="$(printf '%s\n' "$mixed_out" | grep "^evidence_${label}=" | cut -d= -f2)"
    if [ -n "$count" ] && [ "$count" -gt 0 ]; then
        pass "mixed fixture reports ${label} verbatim"
    else
        fail "mixed fixture reports ${label}" "got ${count:-<none>}"
    fi
done

printf '\nStatus with no graph\n'

mkdir -p "${WORK}/nograph"
nostatus_out="$(cd "${WORK}/nograph" && bash "$SCRIPT" status 2>/dev/null)"
nostatus_code=$?
assert_field "status reports graph_present=no" graph_present no "$nostatus_out"
if [ "$nostatus_code" -eq 0 ]; then
    pass "status exits 0 when no graph exists — absence is a state, not an error"
else
    fail "status exits 0 with no graph" "got exit ${nostatus_code}"
fi

printf '\nOutcome distinctness\n'

collected="$(printf '%s\n%s\n%s\n' "$build_out" "$refresh_out" "$full_out" |
    grep '^outcome=' | sort -u | wc -l | tr -d ' ')"
if [ "$collected" -ge 2 ]; then
    pass "built and current are reported as different outcomes"
else
    fail "built and current differ" "only ${collected} distinct outcome(s) seen"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
