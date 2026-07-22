# Implementation Plan: SDD Master Skill

**Branch**: `001-sdd-master-skill` | **Date**: 2026-07-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-sdd-master-skill/spec.md`

## Summary

Build `sdd-master` as a Claude Code skill: a `SKILL.md` router that classifies an
incoming request into one of four effort bands, plus four on-demand reference files
split by source of truth. The router carries the judgment; the references carry the
facts.

The primary requirement is discrimination, not coverage. Per spec US1, a skill that
routes everything into the full workflow is worse than no skill. The design therefore
puts the threshold logic in the always-loaded body and pushes everything else behind
explicit pointers, so the cheap path — recognizing that a request needs nothing — stays
cheap.

## Technical Context

**Language/Version**: Markdown with YAML frontmatter (skill format); Python 3.12 for
validation tooling, matching CI

**Primary Dependencies**: None at runtime. The skill is prose. Authoring and evaluation
use the `skill-creator` skill's bundled scripts; validation reuses this repository's
existing `scripts/`

**Storage**: Files under `.claude/skills/sdd-master/`. No database, no runtime state

**Testing**: Behavioral evaluation — three test cases run with and without the skill by
independent subagents, graded against per-case assertions. Trigger evaluation — a
20-query set measuring activation rate, scored separately

**Target Platform**: Claude Code. The content is environment-aware (spec edge case:
invocation syntax differs across agent integrations) but the packaging is Claude Code's
skill format

**Project Type**: Documentation artifact — a skill package, not source code

**Performance Goals**: `SKILL.md` body under 500 lines so it stays cheap to load on
every activation. Reference files loaded only when the body points at them (FR-015)

**Constraints**: English content only (constitution Principle IX). No network access at
runtime. Must not assume this project's installed extensions exist elsewhere
(spec assumption). Claims must record the version they were verified against (FR-008)

**Scale/Scope**: One skill, one router, four references, two evaluation sets. Research
is complete — no unknowns carried into Phase 1

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v1.6.0. Most principles govern *extension packages*; this feature ships a
skill, so those apply by analogy or not at all. Assessed honestly rather than
ceremonially:

| Principle | Applies? | Assessment |
|---|---|---|
| I. Manifest Is the Contract | No | No `extension.yml`. The skill's frontmatter is the analogue and must be valid |
| II. Namespaced Commands | No | The skill provides no slash commands |
| III. Obvious Placeholders | Yes | ✅ Gate — no `CUSTOMIZE:` markers may ship. `scripts/check-placeholders.sh` only scans extension packages, so this is a review item, not a CI gate |
| IV. Hooks Are Opt-In | No | The skill declares no hooks |
| V. Cross-Platform Script Parity | No | No scripts shipped |
| VI. Additive, Non-Destructive | Yes | ✅ Writes confined to `.claude/skills/sdd-master/` and this feature's `specs/` directory |
| VII. Install-Test Before Publish | By analogy | ✅ The behavioral evaluation is the equivalent proof. A skill that loads but misroutes is the failure this catches |
| VIII. Semantic Versioning | Yes | ✅ `CHANGELOG.md` entry required in the same change |
| IX. English Artifacts | Yes | ✅ Gate — all skill content in English regardless of conversation language |
| X. Compressed Communication | Yes | ✅ The skill is an artifact: full prose, not compressed |
| XI. Hook Literacy | Yes | ✅ `recovery.md` must distinguish the two hook layers per `docs/HOOKS.md`, and must not conflate them |
| XII. Every Distribution Form | No | Not distributed as an extension package |
| XIII. Proactive Use of Extensions | Yes | ✅ `ecosystem.md` must reflect installed extensions dynamically (FR-011), not hardcode this project's seven |
| XIV. Trunk-Based Delivery | Yes | ✅ Gate — lands on `main` via PR from `001-sdd-master-skill` with CI green |

**Gate result: PASS.** No violations requiring justification. Complexity Tracking is
therefore empty and omitted.

One tension worth recording rather than hiding: Principle XIII directs proactive use of
installed extensions, while spec FR-011 requires deriving the capability set from what
is actually installed. These agree here, but a future maintainer might be tempted to
hardcode this project's baseline into `ecosystem.md` for convenience. FR-011 forbids it,
and the skill would then give wrong advice in any other project.

## Project Structure

### Documentation (this feature)

```text
specs/001-sdd-master-skill/
├── plan.md              # This file (/speckit-plan command output)
├── spec.md              # Feature specification
├── research.md          # Phase 0 output — eight decisions, D1-D8
├── data-model.md        # Phase 1 output — the five spec entities, made concrete
├── quickstart.md        # Phase 1 output — how to validate the skill works
├── contracts/           # Phase 1 output — the skill's observable interface
│   ├── skill-frontmatter.md
│   └── routing-contract.md
├── checklists/
│   └── requirements.md  # Spec quality checklist — 16/16 passing
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
.claude/skills/sdd-master/
├── SKILL.md                    # Router: frontmatter + threshold logic + pointers
├── references/
│   ├── workflow.md             # The eight steps, prerequisites, artifacts
│   ├── craft.md                # Spec writing, sizing, layering, drift
│   ├── recovery.md             # Broken-state diagnosis and repair
│   └── ecosystem.md            # Installed extensions; competing tools
└── evals/
    ├── evals.json              # Three behavioral cases (drafted)
    └── trigger-evals.json      # Twenty activation queries

.claude/skills/sdd-master-workspace/   # gitignored — evaluation runs
└── iteration-N/
    └── <case>/{with_skill,without_skill}/
```

**Structure Decision**: A single skill package with a router body and four references
split by source of truth, per research D1 and D3. The split is by where a fact comes
from — upstream tooling, external practice, local install — not by user story, so a
re-verification pass has exactly one file to touch (FR-016). The evaluation workspace
sits beside the skill and is gitignored; the existing `.gitignore` already excludes
`.claude/skills/*-workspace/`.

## Phase 1 Design Notes

**The router's job.** `SKILL.md` holds the four-band classification (Direct, Light,
Full, Defer), the signal table that decides the band, and pointers to references. It
does not hold facts about individual commands — those live in `workflow.md`. This is
what keeps the body under 500 lines and makes the common case, where the answer is "do
nothing special", cheap.

**Reference loading is explicit.** The body names which reference answers which kind of
question, so the model reads one file rather than all four. FR-015 is satisfied by
construction, not by hoping.

**Version stamping.** Each reference header records what it was verified against and
when — upstream at CLI `0.13.3.dev0`, local install at `specify-cli 0.11.3`. FR-008
requires this, and it makes staleness visible instead of silent.

**Dynamic capability discovery.** `ecosystem.md` instructs reading
`.specify/extensions.yml` and `.specify/extensions/.registry` at use time rather than
listing extensions inline. This project's seven appear only as worked examples, clearly
labeled as such.

## Complexity Tracking

Not applicable — the Constitution Check passed with no violations.
