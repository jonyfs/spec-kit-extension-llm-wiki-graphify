# Research: SDD Master Skill

**Phase**: 0 — Outline & Research
**Date**: 2026-07-21
**Spec**: [spec.md](./spec.md)

Three parallel research tracks were run before planning: upstream `github/spec-kit`
(read via the GitHub API at `main`, CLI `0.13.3.dev0`), external SDD practice and
discourse (web sources, named authors prioritized), and the seven extensions actually
installed in this project (read from local files). Findings are consolidated here as
decisions. Every decision names what it rejected and why.

---

## D1: What the skill actually is

**Decision**: A single Claude Code skill at `.claude/skills/sdd-master/`, with a
`SKILL.md` router plus per-domain reference files loaded on demand.

**Rationale**: The spec's FR-015 (load only relevant guidance) and FR-016 (per-domain
maintenance) are structural requirements, and the skill format's three-level loading
model satisfies both directly: metadata always in context, `SKILL.md` body on trigger,
bundled references only when the body points at them. Nothing else in reach offers
that gradient.

**Alternatives considered**:

- *A Spec Kit extension providing `speckit.sdd.*` commands.* Rejected: extension
  commands must be explicitly invoked. FR-001 requires activation without the user
  naming anything, which is precisely what a skill description does and a slash
  command cannot.
- *Additions to `CLAUDE.md`.* Rejected on evidence, not taste — see D6. Repository
  context files load unconditionally on every turn, which is the opposite of FR-015.
- *One flat `SKILL.md` holding everything.* Rejected: violates FR-015 by construction,
  and makes FR-016 impossible since every domain edit touches the routing file.

---

## D2: The routing threshold — the core mechanism

**Decision**: Route on **signals present in the request**, not on a size estimate.
Four bands: Direct (no process), Light (one artifact), Full (the complete workflow),
and Defer (explicit user instruction overrides). The skill states which signal decided
the band and what would overturn it.

**Rationale**: This is P1 and therefore the feature. The external research converged
hard here from both directions. Zaninotto's most-quoted datum — Spec Kit generating 8
files and ~1,300 lines to display a date — is the failure mode when there is no
threshold. Böckeler independently reports Kiro "overshoots on complexity for small
fixes." Van Der Linden's two-month field report concludes with the exact framing this
decision adopts: *"The question isn't whether to spec, but how much."*

Signals that raise the band, drawn from the recurring practitioner advice:

| Signal | Why it raises the band |
|---|---|
| The change touches money, security, or permissions | Soto Valero's explicit rule; cost of being wrong is high |
| Someone other than the author will maintain it | The spec's value is handoff, not generation |
| Multiple subsystems are affected | Scope is not self-evident from the request |
| The user cannot state the acceptance condition | Ambiguity is about goals, not implementation |
| The user says they need something written down | Stated need outranks inference |

Signals that lower it: a single named file, a reversible change, an exploratory
question, a stated throwaway prototype.

**Alternatives considered**:

- *Line-count or file-count thresholds.* Rejected: unavailable at request time, and
  wrong anyway — a one-line change to an authorization check clears every bar that
  matters.
- *Always ask the user which path.* Rejected: FR-005 requires one recommendation, and
  a menu offloads the judgment the skill exists to supply.
- *Always run the full workflow.* Rejected: this is the documented failure mode, and
  the user explicitly chose the opinionated posture.

---

## D3: Knowledge domains and their boundaries

**Decision**: Four reference files, one per domain, each carrying its own sources and
a verification date.

| Reference | Covers | Verified against |
|---|---|---|
| `workflow.md` | The eight core steps, what each consumes and produces, prerequisites, artifact structure | spec-kit `main`, CLI 0.13.3.dev0 |
| `craft.md` | Writing specs agents can use, sizing, testable criteria, the three-layer question, drift | External sources, named authors |
| `recovery.md` | Broken-state diagnosis, prerequisite failures, drift repair, hook interference | Local install + upstream docs |
| `ecosystem.md` | Installed extensions and their routing; competing tools and how they differ | Local `.specify/`, external research |

**Rationale**: FR-016 requires that one domain be updatable without touching routing.
The split is by *source of truth* rather than by topic, so a re-verification pass has
exactly one file to change. FR-008's version-recording requirement then lands
naturally: each file's header carries what it was checked against and when.

**Alternatives considered**:

- *Split by user story.* Rejected: the stories share underlying facts, so the same
  workflow detail would live in two files and drift between them.
- *One reference per Spec Kit command.* Rejected: eight thin files with heavy
  cross-references, and no home for the external methodology material.

---

## D4: Facts that must be encoded because they are non-obvious

These came out of the research and are the highest-value payload — each is something a
competent agent gets wrong from general knowledge alone.

**Feature resolution does not follow the git branch.** `get_feature_paths` resolves
`SPECIFY_FEATURE_DIRECTORY` → `.specify/feature.json` → hard error. Git branch is
never consulted. `git checkout` alone does not change which feature the commands
operate on. This is the single most likely source of "why is it editing the wrong
spec".

**`optional` defaults to `true` on hooks.** Omitting it does not make a hook
mandatory. Conversely, six hooks in *this* project are `optional: false` and execute
without prompting.

**A hook can block a core command.** The bridge extension's guard denies
`speckit.implement` while a handoff is `executing`, and denies `speckit.constitution`
outright during a handoff. A user hitting this has no visible cause. The remedy is to
set the handoff status to `blocked` or `complete` — not to delete the state file, and
not to re-run tasks, which just rewrites it.

**Prerequisite chain is enforced by scripts, not convention.** `setup-tasks.sh` hard-
errors without `plan.md`. `check-prerequisites.sh --require-tasks` hard-errors without
`tasks.md`, which is why `ship` and `staff-review` refuse before implementation exists.

**`analyze` and `converge` are read-only in different ways.** `analyze` writes nothing
at all. `converge` is strictly append-only to `tasks.md` and never rewrites or
renumbers existing tasks. Neither is a diff tool against git history.

**Completed tasks are marked `[X]` in `tasks.md`**, which is what makes a scoped or
resumed implementation run work. This is the documented remedy for context exhaustion
on long runs, alongside sub-agent delegation.

**The upstream constitution template ships five generic placeholder principles**, not
the nine articles described in the methodology essay. The nine articles are
illustrative prose, not the shipped default — a real discrepancy worth not repeating.

---

## D5: Recovery procedures

**Decision**: Encode recovery as *diagnosis before prescription*: identify which
artifact is authoritative, which are stale, and what regenerates them — then order the
steps.

**Rationale**: The spec's US2 acceptance scenarios demand naming the actual cause. The
upstream `spec-persistence.md` document is explicit that Spec Kit deliberately does
**not** prescribe a maintenance model, naming three (flow-back, flow-forward, living
spec) and calling the choice "a team convention, not a CLI setting." A skill that
asserts one model as correct would be inventing policy the tool declines to set. So
the skill diagnoses drift and presents the repair consistent with the model the project
appears to use.

The one concrete drift rule worth carrying, from Thoughtworks' SPDD: **for logic
changes, update the spec first and regenerate; for refactoring, fix the code first and
sync back.** It is the only actionable direction-of-repair rule the research surfaced.

**Alternatives considered**:

- *Prescribe the living-spec model universally.* Rejected: contradicts the tool's own
  documented neutrality.
- *Recommend regenerating from scratch on any drift.* Rejected: discards completed
  work, which FR-014 requires flagging and US2 explicitly tests against.

---

## D6: Evidence handling

**Decision**: Grade claims explicitly. Controlled study, practitioner report, and
vendor assertion are labeled differently, and the skill says so when asked about
outcomes.

**Rationale**: FR-009 and FR-010 require it, and the research makes clear why it is not
pedantry. The strongest controlled result found — ETH Zurich / LogicStar.ai's AGENTBENCH
study across four models and two benchmarks — found LLM-generated repository context
files **decreased** task success by 2–3%, human-written ones helped only ~4%, and both
raised inference cost over 20%. Context files helped materially only when other
documentation was absent, functioning as compensation rather than uplift.

Separately, METR measured experienced developers as **19% slower** with AI assistance
while believing they were ~20% faster. Faros telemetry across 1,255 teams shows
throughput up alongside review time +91%, PR size +154%, and bugs +9%.

There is **no controlled study showing SDD improves velocity, defect rate, or rework**
relative to lighter AI-assisted workflows. The credible position, which both the
strongest advocates and the strongest critics converge toward: SDD's value is human
alignment and scope control, not better model output. A skill that oversells this
produces exactly the ceremony problem it exists to prevent — so the honesty is
load-bearing, not a disclaimer.

**Alternatives considered**:

- *Present SDD as settled best practice.* Rejected: unsupported, and self-defeating
  per the above.
- *Omit the negative evidence.* Rejected: FR-009 forbids it, and a user who later finds
  the ETH result would be right to distrust everything else the skill said.

---

## D7: Triggering without over-triggering

**Decision**: A description that names the concrete situations that should activate it,
paired with an explicit non-trigger clause naming the near-miss vocabulary.

**Rationale**: FR-001 and FR-002 pull against each other, and the near-misses are the
hard part: "API specification", "hardware spec", "spec sheet", and unrelated task lists
all share vocabulary with the domain while needing something entirely different. Skill
guidance also notes a real bias toward under-triggering, so the description leans
active for genuine cases while carving out the collisions.

**Validation**: The description is measured against a trigger evaluation set containing
both should-fire and should-not-fire cases, weighted toward near-misses. SC-006 is the
criterion.

**Alternatives considered**:

- *Keyword-broad description.* Rejected: fails FR-002 on every near-miss.
- *Narrow, literal description.* Rejected: fails FR-001, which is the entire premise of
  "proactive".

---

## D8: Evaluation approach

**Decision**: Three behavioral test cases run with and without the skill, plus a
separate trigger evaluation set for the description.

**Rationale**: The two questions are independent and fail differently. A skill can
contain excellent guidance and never fire; it can fire reliably and give bad guidance.
The three behavioral cases map to the three user stories, with the trivial-request case
carrying the most weight because SC-001 is where the opinionated posture is proven.

Baseline runs without the skill are what make the result meaningful — given the ETH
finding that added context can be net-negative, "the output looks good" is not evidence
the skill helped.

**Alternatives considered**:

- *Ship without evaluation.* Rejected: the user explicitly chose the full cycle, and
  SC-001 through SC-003 are stated as ratios that require a measured set.
- *Behavioral evaluation only.* Rejected: leaves SC-006 unmeasured, and triggering is
  half of what "proactive" means.

---

## Open items carried into Phase 1

None. No `NEEDS CLARIFICATION` markers were raised in the spec, and no decision above
is blocked on information the project does not have.

## Source index

**Upstream** — `github/spec-kit` at `main`: `templates/commands/*.md`,
`templates/*-template.md`, `scripts/bash/common.sh`, `docs/concepts/sdd.md`,
`docs/concepts/spec-persistence.md`, `docs/concepts/complex-features.md`,
`docs/reference/extensions.md`, `docs/upgrade.md`, `spec-driven.md`.

**External** — Böckeler, *Understanding Spec-Driven-Development* (martinfowler.com);
Zhang & Xia, *Structured-Prompt-Driven Development* (martinfowler.com); Zaninotto,
*Spec-Driven Development: The Waterfall Strikes Back* (marmelab.com); Osmani, *How to
write a good spec for AI agents*; Van Der Linden, *Spec-Driven Development, Back to the
Future?!*; ETH Zurich / LogicStar.ai, *Evaluating AGENTS.md*; METR productivity
experiment; DORA 2025; Kiro, OpenSpec, Agent OS, GSD, Superpowers, BMAD, Tessl
documentation.

**Local** — `.specify/extensions.yml`, `.specify/extensions/.registry`, and every
installed extension's `extension.yml`, command files, and scripts.
