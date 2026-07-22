# Data Model: SDD Master Skill

**Phase**: 1 — Design & Contracts
**Date**: 2026-07-21
**Spec**: [spec.md](./spec.md) · **Research**: [research.md](./research.md)

The skill holds no runtime state and no database. These entities are *conceptual* —
they define the shapes the skill's reasoning must produce, and each maps to a section
of prose or a reference file rather than to a record. They are specified here because
the spec named them and because getting their fields right is what makes the routing
reproducible rather than vibes-based.

---

## Request Classification

The judgment of how much process a request warrants. Produced on every activation;
never persisted.

| Field | Values | Notes |
|---|---|---|
| `band` | `direct` \| `light` \| `full` \| `defer` | Exactly one. FR-005 forbids returning a menu |
| `deciding_signal` | text | The single signal that set the band. FR-004 requires stating it |
| `overturned_by` | text | What would move it to a different band |
| `stated_cost` | text \| null | Required when `band = defer`; FR-007 requires naming the cost of complying |

**Band definitions**

- `direct` — Do the work. Produce no workflow artifacts, add no process steps. The
  correct band for the majority of requests.
- `light` — One artifact's worth of thinking. The change is real but the scope is
  self-evident.
- `full` — The complete workflow, steps named in dependency order (FR-006).
- `defer` — The user explicitly asked for a path the signals do not warrant. Comply,
  state the cost.

**Validation rules**

- `deciding_signal` must reference an actual signal from the table below, not a
  restatement of the band.
- `band = full` requires at least one raising signal to be present. Absent any, the
  correct band is lower — this is the rule that prevents the ceremony failure mode.
- An explicit user instruction always produces `defer`, never a silent override.

**Signals** (from research D2)

| Direction | Signal |
|---|---|
| Raises | Touches money, security, or permissions |
| Raises | Someone other than the author will maintain it |
| Raises | Multiple subsystems affected |
| Raises | User cannot state the acceptance condition |
| Raises | User states they need something written down |
| Lowers | A single named file |
| Lowers | Reversible change |
| Lowers | Exploratory question |
| Lowers | Stated throwaway prototype |

---

## Workflow Position

Where a piece of work currently sits. Derived by observation, never assumed.

| Field | Values | Derived from |
|---|---|---|
| `tooling_present` | boolean | Existence of `.specify/` |
| `active_feature` | path \| null | `SPECIFY_FEATURE_DIRECTORY`, else `.specify/feature.json`, else null |
| `artifacts_present` | set | Which artifacts exist in the active feature directory |
| `staleness` | list | Artifacts older than an upstream artifact they derive from |
| `blocked_by` | text \| null | An installed capability preventing a step |

**Validation rules**

- `active_feature` MUST NOT be derived from the git branch. Upstream resolves
  `SPECIFY_FEATURE_DIRECTORY` → `.specify/feature.json` → hard error; the branch is
  never consulted (research D4). Inferring it from the branch is the single most likely
  source of operating on the wrong feature.
- `tooling_present = false` means no workflow step may be recommended (spec edge case).
- `staleness` is ordered: an artifact is stale if anything it derives from changed
  after it.

**State transitions** — the dependency chain, enforced upstream by scripts rather than
convention:

```text
(none) → spec → plan → tasks → implementation → review → release
```

Each arrow has a hard prerequisite. `setup-tasks.sh` errors without `plan.md`;
`check-prerequisites.sh --require-tasks` errors without `tasks.md`. A refusal is
therefore diagnostic information, not a malfunction.

---

## Knowledge Domain

A separately maintainable body of guidance. One reference file each (research D3).

| Field | Type | Notes |
|---|---|---|
| `name` | text | `workflow` \| `craft` \| `recovery` \| `ecosystem` |
| `source_of_truth` | text | Where its facts come from |
| `verified_against` | text | Tool name and version |
| `verified_on` | date | ISO `YYYY-MM-DD` |
| `answers` | text | The question class it handles — what the router matches against |

**Validation rules**

- `verified_against` and `verified_on` are mandatory in every reference header
  (FR-008). A reference without them cannot be trusted to be current.
- Domains partition by `source_of_truth`, not by topic. Two domains must never own the
  same fact — that is how they drift apart (FR-016).

**Instances**

| name | source_of_truth | verified_against |
|---|---|---|
| `workflow` | Upstream `github/spec-kit` command templates and scripts | spec-kit CLI 0.13.3.dev0 |
| `craft` | External practitioner literature, named authors | 2026-07-21 snapshot |
| `recovery` | Local install behavior + upstream docs | specify-cli 0.11.3 |
| `ecosystem` | Live `.specify/` state + external tool comparison | Read at use time |

---

## Evidence Grade

The strength behind an outcome claim. Attached to any assertion about whether something
works, never to a factual claim about tool behavior.

| Grade | Meaning | Presentation |
|---|---|---|
| `controlled` | Controlled study or measured telemetry | State the finding and its scope |
| `practitioner` | Named author reporting real project experience | Attribute it; note n=1 where it is |
| `vendor` | Tool marketing or unmethodologized claim | Name it as marketing, or omit |

**Validation rules**

- FR-009: a response comparing outcomes must not present all three as equivalent.
- FR-010: absent any grade, the answer is "not established" — not a confident guess.
- The known `controlled` findings (research D6) point *against* the intuition that more
  written context helps. Encoding them is required, not optional; omitting them would
  make the skill oversell the methodology it exists to apply proportionately.

---

## Precondition

A condition a recommended action requires, plus how to check it.

| Field | Type | Notes |
|---|---|---|
| `action` | text | The step being recommended |
| `requires` | list | Conditions that must hold |
| `check` | text | The observable way to verify each |
| `on_unmet` | text | What to tell the user — FR-013 forbids silent recommendation |
| `destructive` | boolean | Whether it discards work — FR-014 requires stating this first |

**Validation rules**

- A recommendation whose preconditions are unmet must say so rather than being issued
  and failing (FR-013).
- `destructive = true` requires the consequence be stated *before* the recommendation,
  not after (FR-014).

**Worked examples** — illustrative of this project's install, not a fixed catalog. Per
FR-011, the real set is read from `.specify/` at use time.

| action | requires | on_unmet |
|---|---|---|
| Generate tasks | `plan.md` exists | Name the step that produces it |
| Review implementation | `tasks.md` exists; changes exist | Implementation must come first |
| Release | Review passed; tree clean; remote configured | Name which precondition failed |
| Create isolated worktree | Inside a git repository | Say so; offer initialization |
| Implement | No handoff in `executing` state | Name the extension and how to clear it |

---

## Relationships

```text
Request Classification ──uses──> Workflow Position
         │                              │
      selects                        informs
         ▼                              ▼
  Knowledge Domain              Precondition ──gates──> recommended action
         │
      may carry
         ▼
   Evidence Grade
```

Read as: classification consults observed position; position selects which domain
answers; the domain supplies the recommendation; preconditions gate whether it can be
issued; evidence grades qualify any outcome claim it makes along the way.
