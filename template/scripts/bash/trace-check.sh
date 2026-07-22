#!/usr/bin/env bash
# trace-check.sh
#
# Traceability check for a single Spec Kit feature directory.
#
# Compares spec.md, plan.md and tasks.md against each other and reports the
# inconsistencies that are mechanically decidable:
#
#   * a required artifact is missing
#   * a user story in spec.md has no task tagged with it in tasks.md
#   * a task is tagged with a user story that spec.md does not define
#   * a task cites a requirement ID that spec.md does not define
#   * a requirement ID is defined twice in spec.md
#   * a task ID is used twice in tasks.md
#   * an unresolved [NEEDS CLARIFICATION] marker survives in spec.md
#   * (optional) a requirement in spec.md that no task cites
#
# The script only reads files. It never writes, never touches git state, and
# never looks outside the feature directory it was pointed at.
#
# Usage:
#   trace-check.sh [--feature <dir-or-name>] [--json] [--warn-only] [--help]
#
# Feature resolution order:
#   1. --feature <path>            an existing directory, used as-is
#   2. --feature <name>            resolved to <repo>/specs/<name>
#   3. $SPECIFY_FEATURE            resolved to <repo>/specs/$SPECIFY_FEATURE
#   4. current git branch name     resolved to <repo>/specs/<branch>
#   5. the most recently modified  <repo>/specs/*/spec.md
#
# Exit codes:
#   0  no findings, or --warn-only / warn_only: true
#   1  at least one finding
#   2  usage error, or no feature directory could be resolved

set -euo pipefail

SCRIPT_NAME="trace-check"

usage() {
  sed -n '3,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --------------------------------------------------------------------------
# Repository root
# --------------------------------------------------------------------------

repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

REPO_ROOT="$(repo_root)"

# --------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------

FEATURE_ARG=""
JSON_MODE=false
WARN_ONLY_FLAG=false

while [ $# -gt 0 ]; do
  case "$1" in
    --feature)
      [ $# -ge 2 ] || { echo "$SCRIPT_NAME: --feature requires a value" >&2; exit 2; }
      FEATURE_ARG="$2"
      shift 2
      ;;
    --feature=*)
      FEATURE_ARG="${1#--feature=}"
      shift
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    --warn-only)
      WARN_ONLY_FLAG=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "$SCRIPT_NAME: unknown argument '$1' (try --help)" >&2
      exit 2
      ;;
  esac
done

# --------------------------------------------------------------------------
# Configuration
#
# Flat `key: value` pairs only. local-config.yml wins over trace-config.yml,
# and both are optional.
# --------------------------------------------------------------------------

CONFIG_DIR="$REPO_ROOT/.specify/extensions/trace"

config_lookup() {
  # $1 = key, $2 = default
  local key="$1" default="$2" file value=""
  for file in "$CONFIG_DIR/local-config.yml" "$CONFIG_DIR/trace-config.yml"; do
    [ -f "$file" ] || continue
    value="$(grep -E "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 || true)"
    [ -n "$value" ] || continue
    value="${value#*:}"
    # Trim surrounding whitespace, then a trailing comment, then quotes.
    value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    value="$(printf '%s' "$value" | sed -e 's/[[:space:]]\{1,\}#.*$//')"
    value="$(printf '%s' "$value" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")"
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
  done
  printf '%s' "$default"
}

is_true() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    true|yes|on|1) return 0 ;;
    *) return 1 ;;
  esac
}

REQUIREMENT_PATTERN="$(config_lookup requirement_pattern '(FR|NFR|SC)-[0-9]+')"
REQUIRE_COVERAGE="$(config_lookup require_requirement_coverage 'false')"
FAIL_ON_CLARIFICATION="$(config_lookup fail_on_needs_clarification 'true')"
WARN_ONLY="$(config_lookup warn_only 'false')"

if $WARN_ONLY_FLAG; then
  WARN_ONLY="true"
fi

# --------------------------------------------------------------------------
# Feature resolution
# --------------------------------------------------------------------------

resolve_feature_dir() {
  local candidate branch newest

  if [ -n "$FEATURE_ARG" ]; then
    if [ -d "$FEATURE_ARG" ]; then
      (cd "$FEATURE_ARG" && pwd)
      return 0
    fi
    candidate="$REPO_ROOT/specs/$FEATURE_ARG"
    if [ -d "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
    return 1
  fi

  if [ -n "${SPECIFY_FEATURE:-}" ] && [ -d "$REPO_ROOT/specs/$SPECIFY_FEATURE" ]; then
    printf '%s' "$REPO_ROOT/specs/$SPECIFY_FEATURE"
    return 0
  fi

  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -n "$branch" ] && [ -d "$REPO_ROOT/specs/$branch" ]; then
    printf '%s' "$REPO_ROOT/specs/$branch"
    return 0
  fi

  newest=""
  while IFS= read -r spec_file; do
    [ -n "$spec_file" ] || continue
    if [ -z "$newest" ] || [ "$spec_file" -nt "$newest" ]; then
      newest="$spec_file"
    fi
  done < <(find "$REPO_ROOT/specs" -mindepth 2 -maxdepth 2 -name spec.md 2>/dev/null || true)

  if [ -n "$newest" ]; then
    dirname "$newest"
    return 0
  fi

  return 1
}

if ! FEATURE_DIR="$(resolve_feature_dir)"; then
  echo "$SCRIPT_NAME: no feature directory found." >&2
  echo "  Looked for: --feature, \$SPECIFY_FEATURE, specs/<current-branch>, specs/*/spec.md" >&2
  echo "  Run /speckit.specify first, or pass --feature <dir>." >&2
  exit 2
fi

SPEC_FILE="$FEATURE_DIR/spec.md"
PLAN_FILE="$FEATURE_DIR/plan.md"
TASKS_FILE="$FEATURE_DIR/tasks.md"

FEATURE_NAME="$(basename "$FEATURE_DIR")"

# --------------------------------------------------------------------------
# Findings
# --------------------------------------------------------------------------

FINDINGS_FILE="$(mktemp)"
NOTES_FILE="$(mktemp)"
trap 'rm -f "$FINDINGS_FILE" "$NOTES_FILE"' EXIT

finding() { printf '%s\n' "$1" >> "$FINDINGS_FILE"; }
note()    { printf '%s\n' "$1" >> "$NOTES_FILE"; }

# --------------------------------------------------------------------------
# Extraction helpers. Each prints a sorted, unique list on stdout.
# --------------------------------------------------------------------------

spec_story_numbers() {
  grep -oE '^#{2,4}[[:space:]]+User Story[[:space:]]+[0-9]+' "$SPEC_FILE" 2>/dev/null |
    grep -oE '[0-9]+$' | sort -un || true
}

task_story_numbers() {
  grep -oE '\[US[0-9]+\]' "$TASKS_FILE" 2>/dev/null |
    grep -oE '[0-9]+' | sort -un || true
}

spec_requirement_ids() {
  # A definition is a list item whose first bold run is the identifier:
  #   - **FR-001**: System MUST ...
  grep -oE "^[[:space:]]*[-*][[:space:]]+\*\*${REQUIREMENT_PATTERN}\*\*" "$SPEC_FILE" 2>/dev/null |
    grep -oE "${REQUIREMENT_PATTERN}" | sort || true
}

task_requirement_ids() {
  grep -oE "${REQUIREMENT_PATTERN}" "$TASKS_FILE" 2>/dev/null | sort -u || true
}

task_ids() {
  grep -oE '^[[:space:]]*[-*][[:space:]]+\[[ xX]\][[:space:]]*T[0-9]+' "$TASKS_FILE" 2>/dev/null |
    grep -oE 'T[0-9]+' | sort || true
}

# --------------------------------------------------------------------------
# Check 1 — artifact presence
# --------------------------------------------------------------------------

HAS_SPEC=false
HAS_PLAN=false
HAS_TASKS=false

if [ -f "$SPEC_FILE" ]; then HAS_SPEC=true; fi
if [ -f "$PLAN_FILE" ]; then HAS_PLAN=true; fi
if [ -f "$TASKS_FILE" ]; then HAS_TASKS=true; fi

if ! $HAS_SPEC; then
  finding "spec.md is missing from $FEATURE_NAME; nothing can be traced without it"
fi
if $HAS_TASKS && ! $HAS_PLAN; then
  finding "tasks.md exists but plan.md does not; tasks were derived from nothing reviewable"
fi
if ! $HAS_TASKS; then
  note "tasks.md not present yet; task-side checks were skipped"
fi
if ! $HAS_PLAN; then
  note "plan.md not present yet"
fi

# --------------------------------------------------------------------------
# Check 2 — user story coverage, both directions
# --------------------------------------------------------------------------

STORY_TOTAL=0
STORY_COVERED=0

if $HAS_SPEC && $HAS_TASKS; then
  spec_stories="$(spec_story_numbers)"
  task_stories="$(task_story_numbers)"

  for story in $spec_stories; do
    STORY_TOTAL=$((STORY_TOTAL + 1))
    if printf '%s\n' $task_stories | grep -qx "$story"; then
      STORY_COVERED=$((STORY_COVERED + 1))
    else
      finding "User Story $story is specified but no task in tasks.md is tagged [US$story]"
    fi
  done

  for story in $task_stories; do
    if ! printf '%s\n' $spec_stories | grep -qx "$story"; then
      finding "tasks.md tags [US$story] but spec.md defines no User Story $story"
    fi
  done

  if [ "$STORY_TOTAL" -eq 0 ]; then
    note "spec.md declares no '### User Story N' headings; story coverage was not evaluated"
  fi
fi

# --------------------------------------------------------------------------
# Check 3 — requirement IDs
# --------------------------------------------------------------------------

REQ_TOTAL=0
REQ_CITED=0

if $HAS_SPEC; then
  spec_reqs_all="$(spec_requirement_ids)"
  spec_reqs="$(printf '%s\n' "$spec_reqs_all" | sed '/^$/d' | sort -u)"
  REQ_TOTAL="$(printf '%s\n' "$spec_reqs" | sed '/^$/d' | wc -l | tr -d ' ')"

  duplicates="$(printf '%s\n' "$spec_reqs_all" | sed '/^$/d' | uniq -d)"
  for dup in $duplicates; do
    finding "requirement $dup is defined more than once in spec.md"
  done

  if $HAS_TASKS; then
    task_reqs="$(task_requirement_ids | sed '/^$/d')"

    for req in $task_reqs; do
      if ! printf '%s\n' "$spec_reqs" | grep -qx "$req"; then
        finding "tasks.md cites requirement $req, which spec.md does not define"
      fi
    done

    for req in $spec_reqs; do
      [ -n "$req" ] || continue
      if printf '%s\n' "$task_reqs" | grep -qx "$req"; then
        REQ_CITED=$((REQ_CITED + 1))
      elif is_true "$REQUIRE_COVERAGE"; then
        finding "requirement $req is specified but no task cites it"
      fi
    done

    if ! is_true "$REQUIRE_COVERAGE" && [ "$REQ_TOTAL" -gt 0 ]; then
      note "requirement coverage is informational (require_requirement_coverage is false): $REQ_CITED/$REQ_TOTAL cited by a task"
    fi
  fi
fi

# --------------------------------------------------------------------------
# Check 4 — task IDs and progress
# --------------------------------------------------------------------------

TASK_TOTAL=0
TASK_DONE=0

if $HAS_TASKS; then
  all_task_ids="$(task_ids | sed '/^$/d')"
  TASK_TOTAL="$(printf '%s\n' "$all_task_ids" | sed '/^$/d' | wc -l | tr -d ' ')"
  TASK_DONE="$(grep -cE '^[[:space:]]*[-*][[:space:]]+\[[xX]\][[:space:]]*T[0-9]+' "$TASKS_FILE" 2>/dev/null || true)"
  TASK_DONE="${TASK_DONE:-0}"

  dup_tasks="$(printf '%s\n' "$all_task_ids" | sed '/^$/d' | uniq -d)"
  for dup in $dup_tasks; do
    finding "task id $dup is used by more than one task in tasks.md"
  done

  if [ "$TASK_TOTAL" -eq 0 ]; then
    finding "tasks.md contains no '- [ ] T###' task entries"
  fi
fi

# --------------------------------------------------------------------------
# Check 5 — unresolved clarifications
# --------------------------------------------------------------------------

CLARIFICATIONS=0
if $HAS_SPEC; then
  CLARIFICATIONS="$(grep -c 'NEEDS CLARIFICATION' "$SPEC_FILE" 2>/dev/null || true)"
  CLARIFICATIONS="${CLARIFICATIONS:-0}"
  if [ "$CLARIFICATIONS" -gt 0 ]; then
    if is_true "$FAIL_ON_CLARIFICATION"; then
      finding "spec.md still has $CLARIFICATIONS unresolved [NEEDS CLARIFICATION] marker(s); run /speckit.clarify"
    else
      note "spec.md has $CLARIFICATIONS unresolved [NEEDS CLARIFICATION] marker(s)"
    fi
  fi
fi

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------

FINDING_COUNT="$(wc -l < "$FINDINGS_FILE" | tr -d ' ')"
NOTE_COUNT="$(wc -l < "$NOTES_FILE" | tr -d ' ')"

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

json_array_from_file() {
  local file="$1" first=1 line
  printf '['
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ $first -eq 1 ] || printf ','
    first=0
    printf '"%s"' "$(json_escape "$line")"
  done < "$file"
  printf ']'
}

if $JSON_MODE; then
  printf '{'
  printf '"feature":"%s",' "$(json_escape "$FEATURE_NAME")"
  printf '"feature_dir":"%s",' "$(json_escape "$FEATURE_DIR")"
  printf '"artifacts":{"spec":%s,"plan":%s,"tasks":%s},' "$HAS_SPEC" "$HAS_PLAN" "$HAS_TASKS"
  printf '"user_stories":{"total":%s,"with_tasks":%s},' "$STORY_TOTAL" "$STORY_COVERED"
  printf '"requirements":{"total":%s,"cited_by_tasks":%s},' "$REQ_TOTAL" "$REQ_CITED"
  printf '"tasks":{"total":%s,"completed":%s},' "$TASK_TOTAL" "$TASK_DONE"
  printf '"needs_clarification":%s,' "$CLARIFICATIONS"
  printf '"findings":%s,' "$(json_array_from_file "$FINDINGS_FILE")"
  printf '"notes":%s,' "$(json_array_from_file "$NOTES_FILE")"
  printf '"finding_count":%s,' "$FINDING_COUNT"
  printf '"warn_only":%s' "$(is_true "$WARN_ONLY" && echo true || echo false)"
  printf '}\n'
else
  echo "Traceability check: $FEATURE_NAME"
  echo "  directory   $FEATURE_DIR"
  printf '  artifacts   spec.md=%s plan.md=%s tasks.md=%s\n' "$HAS_SPEC" "$HAS_PLAN" "$HAS_TASKS"
  echo "  stories     $STORY_COVERED/$STORY_TOTAL have at least one task"
  echo "  requirements $REQ_CITED/$REQ_TOTAL cited by a task"
  echo "  tasks       $TASK_DONE/$TASK_TOTAL complete"
  echo "  clarify     $CLARIFICATIONS unresolved marker(s)"

  if [ "$NOTE_COUNT" -gt 0 ]; then
    echo
    echo "Notes"
    while IFS= read -r line; do
      if [ -n "$line" ]; then echo "  - $line"; fi
    done < "$NOTES_FILE"
  fi

  echo
  if [ "$FINDING_COUNT" -eq 0 ]; then
    echo "No traceability findings."
  else
    echo "Findings ($FINDING_COUNT)"
    while IFS= read -r line; do
      if [ -n "$line" ]; then echo "  ! $line"; fi
    done < "$FINDINGS_FILE"
  fi
fi

if [ "$FINDING_COUNT" -gt 0 ] && ! is_true "$WARN_ONLY"; then
  exit 1
fi
exit 0
