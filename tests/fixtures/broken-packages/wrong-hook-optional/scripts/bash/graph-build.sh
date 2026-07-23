#!/usr/bin/env bash
#
# graph-build.sh — build or refresh a graphify knowledge graph for a project.
#
# Contract: specs/002-graph-build-command/contracts/build-script.md
#
# This script delegates every part of graph construction to the graphify CLI.
# It implements no extraction, clustering, or rendering of its own, and it never
# installs or upgrades graphify.
#
# Modes:
#   check   verify the graphify installation and version range
#   scope   report what a build would examine; writes nothing
#   build   build or refresh the graph; requires --confirmed
#   status  report the current graph's state; builds nothing
#
# Exit codes:
#   0  built | current
#   2  usage error, or `build` without --confirmed
#   3  nothing-to-examine   (NOT success)
#   4  dependency-missing
#   5  dependency-too-old   (below floor, at/above ceiling, or unparseable)
#   6  already-running
#   7  interrupted-state
#   8  failed

set -u

# `pipefail` is deliberately NOT set globally. Under pipefail, `grep -q` exits at
# its first match and sends SIGPIPE upstream, which turns a successful match into
# a pipeline failure. That exact defect has already broken a script in this
# repository. Where a pipeline's exit status matters, it is checked explicitly.

readonly EXIT_USAGE=2
readonly EXIT_NOTHING=3
readonly EXIT_MISSING=4
readonly EXIT_TOO_OLD=5
readonly EXIT_RUNNING=6
readonly EXIT_INTERRUPTED=7
readonly EXIT_FAILED=8

readonly DEFAULT_MIN_VERSION="0.9.9"
readonly DEFAULT_MAX_VERSION="0.10.0"
readonly OUT_DIR="graphify-out"
# Resolved to absolute paths in main(), BEFORE any cd. mode_build enters the scope
# root, and a relative lock path would then resolve against the wrong directory —
# the lock would be acquired in one place and released in another, which is to say
# never released at all.
EXT_DIR=".specify/extensions/llm-wiki-graphify"
LOCK_DIR="${EXT_DIR}/build.lock"

MODE=""
ARG_PATH="."
ARG_MIN_VERSION="$DEFAULT_MIN_VERSION"
ARG_MAX_VERSION="$DEFAULT_MAX_VERSION"
ARG_FULL=0
ARG_CONFIRMED=0
LOCK_HELD=0

# ---------------------------------------------------------------------------
# Configuration
#
# Read from ${EXT_DIR}/config.yml when present. The file is optional: a missing
# file is silent and defaulted (config is required: false). A malformed file is
# NOT silent — it stops with a distinct outcome, because falling back to defaults
# would run the build in a way the maintainer did not configure and could not see.
#
# Precedence: an explicit command-line argument wins over the config file, which
# wins over the compiled defaults. A config value is applied only where the
# argument still holds its default, so `--path X` is never overridden by config.
# ---------------------------------------------------------------------------

load_config() {
    local config="${EXT_DIR}/config.yml"
    [ -f "$config" ] || return 0

    local parsed
    parsed="$(
        python3 - "$config" <<'PY'
import sys

try:
    import yaml
except ImportError:
    yaml = None

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
except OSError as exc:
    print(f"__ERROR__ {exc}")
    sys.exit(0)

if yaml is not None:
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        print(f"__ERROR__ {str(exc).splitlines()[0]}")
        sys.exit(0)
else:
    # Minimal fallback parser for the flat two-level shape this config uses.
    # Only scope.root, graphify.min_version, graphify.max_version are read.
    data, section = {}, None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if not line.startswith(" "):
            key = line.split(":", 1)[0].strip()
            section = key
            data[section] = {}
        else:
            if ":" not in line:
                print("__ERROR__ malformed line (no colon)")
                sys.exit(0)
            k, v = line.split(":", 1)
            data.setdefault(section, {})[k.strip()] = v.strip().strip('"').strip("'")

if data is None:
    data = {}
if not isinstance(data, dict):
    print("__ERROR__ top level is not a mapping")
    sys.exit(0)

scope = data.get("scope") or {}
graphify = data.get("graphify") or {}
if not isinstance(scope, dict) or not isinstance(graphify, dict):
    print("__ERROR__ scope/graphify are not mappings")
    sys.exit(0)

for key, value in (
    ("scope_root", scope.get("root")),
    ("min_version", graphify.get("min_version")),
    ("max_version", graphify.get("max_version")),
):
    if value is not None:
        print(f"{key}={value}")
PY
    )"

    if printf '%s\n' "$parsed" | grep -q '^__ERROR__'; then
        local reason
        reason="$(printf '%s\n' "$parsed" | grep '^__ERROR__' | head -n 1 | sed 's/^__ERROR__ //')"
        note "config file is malformed: ${config}"
        note "  ${reason}"
        note ""
        note "Refusing to fall back to defaults — that would run the build in a way you"
        note "did not configure and could not see. Fix the file, or remove it to use"
        note "defaults deliberately."
        emit outcome config-invalid
        exit "$EXIT_USAGE"
    fi

    local cfg_root cfg_min cfg_max
    cfg_root="$(printf '%s\n' "$parsed" | grep '^scope_root=' | cut -d= -f2-)"
    cfg_min="$(printf '%s\n' "$parsed" | grep '^min_version=' | cut -d= -f2-)"
    cfg_max="$(printf '%s\n' "$parsed" | grep '^max_version=' | cut -d= -f2-)"

    [ -n "$cfg_root" ] && [ "$ARG_PATH" = "." ] && ARG_PATH="$cfg_root"
    [ -n "$cfg_min" ] && [ "$ARG_MIN_VERSION" = "$DEFAULT_MIN_VERSION" ] && ARG_MIN_VERSION="$cfg_min"
    [ -n "$cfg_max" ] && [ "$ARG_MAX_VERSION" = "$DEFAULT_MAX_VERSION" ] && ARG_MAX_VERSION="$cfg_max"
}

# ---------------------------------------------------------------------------
# Output helpers
#
# stdout carries machine-readable key=value lines only. Everything a human reads
# while diagnosing goes to stderr, including graphify's own output, which is
# passed through unmodified — never suppressed, never re-worded.
# ---------------------------------------------------------------------------

emit() { printf '%s=%s\n' "$1" "$2"; }
note() { printf '%s\n' "$*" >&2; }

die() {
    local code="$1"
    shift
    note "$*"
    release_lock
    exit "$code"
}

usage() {
    cat >&2 <<'USAGE'
Usage:
  graph-build.sh check  [--path <p>] [--min-version <v>] [--max-version <v>]
  graph-build.sh scope  [--path <p>]
  graph-build.sh build  --confirmed [--path <p>] [--full]
  graph-build.sh status [--path <p>]

`build` refuses to run without --confirmed. The flag is the caller asserting
that a human authorised this run; it is not a convenience bypass.
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
    if [ $# -eq 0 ]; then
        usage
        exit "$EXIT_USAGE"
    fi

    MODE="$1"
    shift

    case "$MODE" in
        check | scope | build | status) ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            note "unknown mode: ${MODE}"
            usage
            exit "$EXIT_USAGE"
            ;;
    esac

    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                [ $# -ge 2 ] || { note "--path requires a value"; exit "$EXIT_USAGE"; }
                ARG_PATH="$2"
                shift 2
                ;;
            --min-version)
                [ $# -ge 2 ] || { note "--min-version requires a value"; exit "$EXIT_USAGE"; }
                ARG_MIN_VERSION="$2"
                shift 2
                ;;
            --max-version)
                [ $# -ge 2 ] || { note "--max-version requires a value"; exit "$EXIT_USAGE"; }
                ARG_MAX_VERSION="$2"
                shift 2
                ;;
            --full)
                ARG_FULL=1
                shift
                ;;
            --confirmed)
                ARG_CONFIRMED=1
                shift
                ;;
            *)
                # Never ignored. A silently dropped --full produces a refresh the
                # caller believes was a rebuild.
                note "unknown argument: $1"
                usage
                exit "$EXIT_USAGE"
                ;;
        esac
    done

    if [ "$MODE" = "build" ] && [ "$ARG_CONFIRMED" -ne 1 ]; then
        note "build requires --confirmed: the caller must assert that a human authorised this run"
        exit "$EXIT_USAGE"
    fi
}

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

resolve_root() {
    local project_root resolved
    project_root="$(pwd -P)"

    if [ ! -d "$ARG_PATH" ]; then
        die "$EXIT_USAGE" "scope root does not exist: ${ARG_PATH}"
    fi

    resolved="$(cd "$ARG_PATH" 2>/dev/null && pwd -P)" || {
        die "$EXIT_USAGE" "scope root is not readable: ${ARG_PATH}"
    }

    case "$resolved" in
        "$project_root" | "$project_root"/*) ;;
        *)
            die "$EXIT_USAGE" "scope root escapes the project root: ${resolved}"
            ;;
    esac

    printf '%s\n' "$resolved"
}

# ---------------------------------------------------------------------------
# Version handling
#
# Parsing uses POSIX-portable tooling only. `sed -E` with `\s` is a GNU
# extension that BSD sed silently ignores, producing a wrong answer rather than
# an error — the failure mode that already broke install-test.sh here.
# ---------------------------------------------------------------------------

parse_version() {
    printf '%s\n' "$1" | tr -c '0-9.\n' ' ' | tr -s ' ' '\n' |
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1
}

# Returns 0 when $1 < $2, using numeric comparison field by field.
version_lt() {
    local a="$1" b="$2" i a_part b_part
    for i in 1 2 3; do
        a_part="$(printf '%s' "$a" | cut -d. -f"$i")"
        b_part="$(printf '%s' "$b" | cut -d. -f"$i")"
        a_part="${a_part:-0}"
        b_part="${b_part:-0}"
        if [ "$a_part" -lt "$b_part" ]; then return 0; fi
        if [ "$a_part" -gt "$b_part" ]; then return 1; fi
    done
    return 1
}

check_dependency() {
    local raw parsed

    if ! command -v graphify >/dev/null 2>&1; then
        note "graphify is not installed, or is not on PATH."
        note ""
        note "This extension delegates all graph construction to graphify and never"
        note "installs it for you. To install it:"
        note ""
        note "    uv tool install graphifyy"
        note "    # or: python3 -m pip install graphifyy"
        note ""
        note "Then re-run this command. Nothing was written."
        emit outcome dependency-missing
        exit "$EXIT_MISSING"
    fi

    raw="$(graphify --version 2>&1 | head -n 1)"
    parsed="$(parse_version "$raw")"

    # Fail closed. The version string's own format is unversioned and could
    # change; an unparseable version is never treated as new enough.
    if [ -z "$parsed" ]; then
        note "could not parse a version from graphify --version"
        note "  output was: ${raw}"
        note "  required:   >=${ARG_MIN_VERSION},<${ARG_MAX_VERSION}"
        emit outcome dependency-too-old
        exit "$EXIT_TOO_OLD"
    fi

    if version_lt "$parsed" "$ARG_MIN_VERSION"; then
        note "graphify ${parsed} is older than this extension supports."
        note "  found:    ${parsed}"
        note "  required: >=${ARG_MIN_VERSION},<${ARG_MAX_VERSION}"
        emit outcome dependency-too-old
        exit "$EXIT_TOO_OLD"
    fi

    if ! version_lt "$parsed" "$ARG_MAX_VERSION"; then
        note "graphify ${parsed} is newer than this extension has been verified against."
        note "  found:    ${parsed}"
        note "  required: >=${ARG_MIN_VERSION},<${ARG_MAX_VERSION}"
        note ""
        note "graphify is pre-1.0 and promises no compatibility between minor versions."
        note "This extension reads fields observed in ${ARG_MIN_VERSION}; a newer release"
        note "may have changed them. Proceeding could silently report a wrong graph."
        emit outcome dependency-too-old
        exit "$EXIT_TOO_OLD"
    fi

    GRAPHIFY_VERSION="$parsed"
}

# ---------------------------------------------------------------------------
# Locking
#
# The lock lives in the extension's own directory, never under graphify-out/,
# which the tool owns. A directory is created atomically on POSIX and Windows
# filesystems alike; a check-then-create lock file is not.
# ---------------------------------------------------------------------------

acquire_lock() {
    local owner age_pid

    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" >"${LOCK_DIR}/pid"
        LOCK_HELD=1
        return 0
    fi

    owner="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
    age_pid="${owner:-unknown}"

    if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
        note "another build is already running for this project (process ${owner})."
        note "Nothing was written. Wait for it to finish, or stop it."
        emit outcome already-running
        exit "$EXIT_RUNNING"
    fi

    # Stale lock. Without reclamation, a single crash would disable the command
    # permanently — a safety mechanism becoming an availability failure.
    note "reclaiming a stale lock left by process ${age_pid}, which is no longer running."
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" >"${LOCK_DIR}/pid"
        LOCK_HELD=1
        return 0
    fi

    note "could not acquire the build lock at ${LOCK_DIR}"
    emit outcome already-running
    exit "$EXIT_RUNNING"
}

release_lock() {
    if [ "$LOCK_HELD" -eq 1 ]; then
        rm -rf "$LOCK_DIR"
        LOCK_HELD=0
    fi
}

trap release_lock EXIT INT TERM

# ---------------------------------------------------------------------------
# Graph inspection
#
# The edge array is named `links`, not `edges`. Reading graph["edges"] returns an
# empty list and reports a graph with zero relationships as a success — a silent
# wrong answer rather than an error.
# ---------------------------------------------------------------------------

count_files() {
    find "$1" -type f -not -path "*/${OUT_DIR}/*" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' '
}

graph_counts() {
    local graph="$1"
    python3 - "$graph" <<'PY'
import json
import sys
from collections import Counter

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        graph = json.load(handle)
except (OSError, ValueError) as exc:
    print(f"error={exc}")
    sys.exit(1)

links = graph.get("links", [])
labels = Counter(link.get("confidence", "UNLABELLED") for link in links)

print(f"entities={len(graph.get('nodes', []))}")
print(f"relationships={len(links)}")
for label in ("EXTRACTED", "INFERRED", "AMBIGUOUS"):
    print(f"evidence_{label}={labels.get(label, 0)}")
for label, count in sorted(labels.items()):
    if label not in ("EXTRACTED", "INFERRED", "AMBIGUOUS"):
        print(f"evidence_{label}={count}")
PY
}

detect_interrupted() {
    # manifest.json records what the tool believed it had processed. That record
    # surviving without the graph it describes is what an interrupted run leaves.
    [ -f "${OUT_DIR}/manifest.json" ] && [ ! -f "${OUT_DIR}/graph.json" ]
}

latest_backup() {
    find "$OUT_DIR" -maxdepth 1 -type d -name '20*' 2>/dev/null | sort | tail -n 1
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

mode_check() {
    check_dependency
    emit outcome dependency-ok
    emit graphify_version "$GRAPHIFY_VERSION"
    emit version_range ">=${ARG_MIN_VERSION},<${ARG_MAX_VERSION}"
}

mode_scope() {
    local root files
    root="$(resolve_root)"
    files="$(count_files "$root")"

    emit outcome scope
    emit root "$root"
    emit files "$files"
    emit exclusions none
    emit coverage structural

    note "This build will examine ${files} file(s) under ${root}."
    note ""
    note "No exclusions are applied. graphify offers no exclusion mechanism, so"
    note "everything inside the scope root is read — including vendored code and"
    note "any secrets stored in files. Narrow the scope root if that matters."
    note ""
    note "Structure is extracted from code and documents alike. The semantic layer —"
    note "concepts spanning documents, and inferred relationships — requires a separate"
    note "model-assisted pass; see the build report for the handoff."
}

mode_status() {
    local root graph
    root="$(resolve_root)"
    graph="${root}/${OUT_DIR}/graph.json"

    emit outcome status

    if [ ! -f "$graph" ]; then
        emit graph_present no
        note "No graph has been built for ${root}."
        note "Run the build command to create one. Absence is a state, not an error."
        return 0
    fi

    emit graph_present yes
    graph_counts "$graph"
    emit output "${root}/${OUT_DIR}"
}

mode_build() {
    local root started finished elapsed tool_out tool_status backup graph

    check_dependency
    root="$(resolve_root)"

    mkdir -p "$EXT_DIR"
    acquire_lock

    cd "$root" || die "$EXIT_USAGE" "could not enter scope root: ${root}"

    # graphify writes graphify-out/manifest.json into the WORKING directory while
    # writing the graph to the target path. Entering the scope root first
    # collapses the two locations into one, so no stray output is left behind.

    if detect_interrupted && [ "$ARG_FULL" -ne 1 ]; then
        note "a previous build left an incomplete graph: ${OUT_DIR}/manifest.json exists"
        note "but ${OUT_DIR}/graph.json does not."
        note ""
        note "Refusing to refresh from an incomplete state. Re-run with --full to"
        note "rebuild from the sources — that is the recovery path, and it works from"
        note "this state by design."
        emit outcome interrupted-state
        release_lock
        exit "$EXIT_INTERRUPTED"
    fi

    local prev_entities=0 prev_relationships=0
    if [ -f "${OUT_DIR}/graph.json" ]; then
        prev_entities="$(graph_counts "${OUT_DIR}/graph.json" | grep '^entities=' | cut -d= -f2)"
        prev_relationships="$(graph_counts "${OUT_DIR}/graph.json" | grep '^relationships=' | cut -d= -f2)"
    fi

    if [ "$ARG_FULL" -eq 1 ]; then
        # There is no --full flag on graphify, and --force is not equivalent: it
        # leaves outputs untouched on an unchanged corpus. Removing graph.json
        # forces a rebuild. This deletes exactly one derived file so the tool
        # regenerates it — cache/, manifest.json, and the dated backups survive,
        # because removing those would turn a rebuild into data loss.
        note "full rebuild: removing ${OUT_DIR}/graph.json so graphify regenerates it"
        rm -f "${OUT_DIR}/graph.json"
    fi

    started="$(date +%s)"
    tool_out="$(graphify update . 2>&1)"
    tool_status=$?
    finished="$(date +%s)"
    elapsed=$((finished - started))

    # graphify's own output goes through unmodified. A failure is never absorbed.
    printf '%s\n' "$tool_out" >&2

    graph="${OUT_DIR}/graph.json"

    # Classify from the tool's own output, never from a file count. A count
    # cannot distinguish "no files" from "files the tool does not read", and the
    # set it reads is wider than expected: document structure is extracted too.
    if printf '%s' "$tool_out" | grep -F 'No code files found' >/dev/null 2>&1; then
        note "nothing to examine under ${root} — graphify found no readable files."
        note "This is not a successful build. No graph was produced."
        emit outcome nothing-to-examine
        release_lock
        exit "$EXIT_NOTHING"
    fi

    if [ "$tool_status" -ne 0 ]; then
        note "graphify exited with status ${tool_status}. The graph was not updated."
        emit outcome failed
        release_lock
        exit "$EXIT_FAILED"
    fi

    if [ ! -f "$graph" ]; then
        note "graphify reported success but produced no ${graph}."
        emit outcome failed
        release_lock
        exit "$EXIT_FAILED"
    fi

    if printf '%s' "$tool_out" | grep -F 'No code-graph topology changes detected' >/dev/null 2>&1; then
        emit outcome current
    else
        emit outcome built
    fi

    graph_counts "$graph"
    emit output "${root}/${OUT_DIR}"
    emit elapsed_seconds "$elapsed"
    emit coverage structural
    emit exclusions none
    note ""
    note "Coverage: structure was extracted from code and from documents alike — a"
    note "Markdown heading is an entity here, exactly as a function is. What this run"
    note "did NOT produce is the semantic layer: concepts spanning documents, and"
    note "relationships inferred between prose and the code implementing it. Those come"
    note "from the model-assisted pass — run /graphify --update in your AI assistant."
    note "No exclusions were applied; everything under the scope root was read."

    local now_entities now_relationships
    now_entities="$(graph_counts "$graph" | grep '^entities=' | cut -d= -f2)"
    now_relationships="$(graph_counts "$graph" | grep '^relationships=' | cut -d= -f2)"
    emit delta_entities "$((now_entities - prev_entities))"
    emit delta_relationships "$((now_relationships - prev_relationships))"

    backup="$(latest_backup)"
    if [ -n "$backup" ]; then
        emit backup "${root}/${backup}"
        note ""
        note "graphify kept a backup of the previous graph at ${backup}."
        note "It is the only recovery path if this rebuild was a mistake."
    fi

    release_lock
}

# ---------------------------------------------------------------------------

main() {
    parse_args "$@"

    # Absolute before anything can change directory.
    EXT_DIR="$(pwd -P)/.specify/extensions/llm-wiki-graphify"
    LOCK_DIR="${EXT_DIR}/build.lock"

    # Config is read from the project root, before any mode changes directory.
    load_config

    case "$MODE" in
        check) mode_check ;;
        scope) mode_scope ;;
        build) mode_build ;;
        status) mode_status ;;
    esac
}

main "$@"
