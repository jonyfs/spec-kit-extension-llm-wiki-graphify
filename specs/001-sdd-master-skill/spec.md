# Feature Specification: SDD Master Skill

**Feature Branch**: `001-sdd-master-skill`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "Create a skill that encodes deep expertise on
Spec-Driven Development and GitHub Spec Kit, researched from upstream repositories and
external practitioner literature, that triggers proactively when a user needs it
rather than waiting to be named."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Right-Sized Routing (Priority: P1)

Someone describes work they want done. They do not say "Spec Kit" and they do not say
"spec". They just describe the work — which may be a two-line fix or a multi-week
subsystem. They get an approach proportional to what they actually asked for.

**Why this priority**: This is the whole feature. A skill that routes every request
into the full workflow is worse than no skill, because it adds ceremony the user did
not ask for and teaches them to route around it. A skill that never routes anything
into the workflow is inert. The value is entirely in the discrimination, so if only
this story ships, the feature is still worth having.

**Independent Test**: Give the skill a trivial change and a substantial ambiguous
feature in separate sessions. The trivial one is handled directly with no artifacts
generated. The substantial one is routed into the workflow with the steps named in
dependency order. Neither requires the user to mention Spec Kit.

**Acceptance Scenarios**:

1. **Given** a user asks for a copy fix and a broken link, **When** the skill is
   consulted, **Then** the work is done directly and no specification, plan, or task
   artifact is generated.
2. **Given** a user describes a feature with unstated scope, several affected
   subsystems, and a stated need to write something down first, **When** the skill is
   consulted, **Then** it routes to the full workflow and names the steps in
   dependency order.
3. **Given** a request sitting between those extremes, **When** the skill is
   consulted, **Then** it recommends one path, states the specific signal that decided
   it, and notes what would change the recommendation.
4. **Given** a user explicitly asks for a full specification on small work, **When**
   the skill is consulted, **Then** it complies while stating the cost, because an
   explicit instruction outranks the skill's default.

---

### User Story 2 - Recovering a Broken Workflow State (Priority: P2)

Someone is mid-workflow and stuck. Commands are refusing to run, or artifacts
disagree with each other, or something fired automatically and they cannot tell what
it did. They get a diagnosis naming the actual cause and an ordered recovery that
preserves their work.

**Why this priority**: This is where a user is most likely to abandon the methodology
entirely, and where generic advice is least useful — recovery requires knowing which
artifact is authoritative, which step regenerates what, and which installed capability
is interfering. High value, but only reachable by users already in the workflow, so it
ranks below the routing that gets them there.

**Independent Test**: Describe a state where a hand-edit to the specification left the
plan and task list stale, and a step refused to run. The skill names both problems
separately, prescribes a regeneration order, and does not advise starting over.

**Acceptance Scenarios**:

1. **Given** a step refuses to run because a prerequisite artifact is absent, **When**
   the skill is consulted, **Then** it names the missing prerequisite and the step that
   produces it.
2. **Given** an artifact was edited by hand and downstream artifacts are now stale,
   **When** the skill is consulted, **Then** it identifies which artifacts are stale,
   in what order to regenerate them, and which cross-artifact consistency check to run.
3. **Given** an automatically-executing hook has blocked a core step, **When** the
   skill is consulted, **Then** it identifies the responsible extension, explains the
   state that triggered the block, and gives the specific way to clear it.
4. **Given** a recovery would discard completed work, **When** the skill is consulted,
   **Then** it says so before recommending it and offers a preserving alternative
   where one exists.

---

### User Story 3 - Grounded Craft Guidance (Priority: P3)

Someone asks a judgment question — where something belongs, whether their criteria
are testable, whether their specification is the right size. They get an answer
grounded in what practitioners have actually found, including where the evidence is
weak.

**Why this priority**: Genuinely useful and the hardest to get from a search engine,
but it improves work already in progress rather than enabling work that was blocked.
The feature delivers value without it.

**Independent Test**: Ask where a decision belongs across the governance, specification,
and plan layers. The answer gives a discriminating test that generalizes, not a
restatement of the question.

**Acceptance Scenarios**:

1. **Given** a user asks whether something belongs in project governance, the
   specification, or the plan, **When** the skill is consulted, **Then** it gives a
   discriminating test that applies beyond the example at hand.
2. **Given** a user shows acceptance criteria containing unmeasurable adjectives,
   **When** the skill is consulted, **Then** it identifies each unmeasurable term and
   proposes an observable replacement.
3. **Given** a user asks whether the methodology improves delivery outcomes, **When**
   the skill is consulted, **Then** it distinguishes what controlled evidence supports
   from what is practitioner opinion or vendor marketing, rather than presenting all of
   it as settled.
4. **Given** a user asks about a competing methodology or tool, **When** the skill is
   consulted, **Then** it describes the actual difference in approach without
   dismissing the alternative.

---

### Edge Cases

- **The project has no specification tooling initialized.** The skill must say so and
  offer initialization rather than referencing steps that cannot run.
- **The installed capability set differs from the documented one.** Extensions come
  and go. The skill must reflect what is installed rather than asserting a fixed
  catalog.
- **The user is working in a different agent environment.** Invocation syntax differs
  across environments. Guidance must not assume one syntax is universal.
- **The user asks about a tool version whose behavior differs from what the skill
  documents.** The skill must state which version its claims were verified against
  rather than presenting them as timeless.
- **A recommendation conflicts with project governance.** Governance wins, and the
  skill must say that it is deferring and why.
- **Exploratory work with no stable target.** The user is trying to learn what is
  possible. The skill must recognize that specifying a moving target wastes effort.
- **A legacy codebase where comprehensive specification is infeasible.** The skill
  must scope specification to the area of change instead of the whole system.
- **The user asks a question the research does not cover.** The skill must say the
  answer is not established rather than inventing a confident one.

## Requirements *(mandatory)*

### Functional Requirements

**Triggering**

- **FR-001**: The skill MUST activate on requests concerning specification-driven
  work, workflow state, or methodology judgment, without the user naming the skill or
  the methodology.
- **FR-002**: The skill MUST NOT activate on requests that merely share vocabulary
  with the domain — such as an interface specification, a hardware spec, or a task
  list unrelated to the workflow.
- **FR-003**: The skill MUST remain inert on work below the threshold where its
  guidance would change the outcome.

**Routing**

- **FR-004**: The skill MUST classify an incoming request by the effort its guidance
  warrants, and MUST state which signal decided the classification.
- **FR-005**: The skill MUST recommend exactly one path rather than presenting a menu,
  while stating what would change the recommendation.
- **FR-006**: When routing into a multi-step workflow, the skill MUST name the steps
  in dependency order and state which artifact each produces.
- **FR-007**: The skill MUST defer to an explicit user instruction that contradicts
  its own recommendation, while stating the cost of doing so.

**Grounding**

- **FR-008**: Every claim about step behavior, artifact structure, or tool capability
  MUST be traceable to a verifiable source, and the skill MUST record which tool
  version its claims were verified against.
- **FR-009**: The skill MUST distinguish controlled evidence from practitioner
  experience and from vendor marketing when making claims about outcomes.
- **FR-010**: The skill MUST report that an answer is not established rather than
  producing a confident answer its sources do not support.
- **FR-011**: The skill MUST derive the available capability set from what is actually
  installed in the current project rather than from a hardcoded list.

**Deference**

- **FR-012**: Where project governance addresses a question, the skill MUST follow it
  and MUST state that it is deferring.
- **FR-013**: The skill MUST identify the preconditions a recommended step requires
  and MUST NOT recommend one whose preconditions are unmet without saying so.
- **FR-014**: Before recommending an action that discards work or is otherwise hard to
  reverse, the skill MUST state that consequence.

**Structure**

- **FR-015**: The skill MUST load only the guidance relevant to the request at hand
  rather than its full body of knowledge on every activation.
- **FR-016**: The skill MUST be organized so that a maintainer can update the
  knowledge for one domain without editing the routing logic.

### Key Entities

- **Request Classification** — the judgment of how much process a request warrants,
  the signals that produced it, and what would overturn it.
- **Workflow Position** — where a piece of work currently sits, derived from which
  artifacts exist and what state they are in.
- **Knowledge Domain** — a separately maintainable body of guidance (upstream tooling,
  external methodology, locally installed capabilities) with its own sources and
  verification date.
- **Evidence Grade** — the strength behind a claim: controlled study, practitioner
  report, or vendor assertion.
- **Precondition** — a condition a recommended action requires, and the observable way
  to check it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** *(revised 2026-07-22 — see Assumptions)*: Across a representative set of
  trivial requests where the user explicitly raises the methodology, the skill declines
  the full workflow **and declines to substitute a reduced artifact for it** in at least
  9 of 10 cases. The measured failure is not over-processing; it is hedging into a
  compromise artifact — "just write the three-line version", "a one-paragraph spec" —
  under social pressure from a stated team rule or an insistent asker.

  **Excluded from the count**: an artifact produced under an external obligation the
  user cannot unilaterally waive — a compliance regime, an audit, a contractual
  requirement. Complying there and stating the cost once is the Defer band working, not
  a hedge. Without this carve-out the criterion scores the skill's own prescribed
  behavior as a failure.
- **SC-002**: Across a representative set of substantial ambiguous requests, the skill
  routes into the full workflow with steps named in correct dependency order in at
  least 9 of 10 cases.
- **SC-003**: Presented with a broken workflow state, the skill names the actual cause
  and prescribes a recovery that preserves completed work in at least 8 of 10 cases.
- **SC-004**: A user who has never used the methodology can act on the skill's
  guidance without consulting external documentation first.
- **SC-005**: Every factual claim the skill makes about tool behavior can be traced by
  a reader to a stated source.
- **SC-006**: The skill activates on requests that need it and stays silent on
  near-miss requests that merely share vocabulary, measured over a set containing both.
- **SC-007**: A maintainer can update one knowledge domain without changing how the
  skill routes requests.
- **SC-008**: Guidance for a given request arrives in a single exchange, without the
  user having to ask a follow-up to get the actionable part.

## Assumptions

- **Spec Kit is the primary methodology.** Competing tools are described for
  comparison and for when the user is choosing between them, not given equal depth.
- **The user's project may or may not have the tooling installed.** The skill handles
  both, and does not assume the capabilities installed here are present elsewhere.
- **Research is a point-in-time snapshot.** Upstream tooling and community extensions
  change. The skill records verification dates so staleness is visible rather than
  silent; re-verification is a maintenance task, not a defect.
- **Proactive means available, not intrusive.** Activating is not the same as
  interrupting. On work below the threshold, the correct behavior is silence.
- **English for all content.** Per project governance, everything written to disk is
  English regardless of the conversation language.
- **Evidence on methodology outcomes is genuinely mixed.** The strongest available
  controlled study on repository context files found them net-negative for
  well-documented repositories. The skill's honesty about this is a feature, not
  hedging — a skill that oversells the methodology produces the ceremony problem it
  exists to prevent.
- **The thresholds in Success Criteria are targets, not observed values.** They define
  what "working" means for the evaluation set; they are not claims about current
  behavior.

- **The original SC-001 measured a failure mode that does not occur in conversation, and
  was rewritten after evaluation disproved it.** The premise was that models over-apply
  ceremony to small work. Three independent rounds failed to reproduce it: two with-and-
  without comparisons, then a clean baseline written by an agent told nothing about the
  premise or the skill. Across every trivial prompt — including ones where the user
  stated a team rule requiring the workflow, and one where the user asked only which
  command to start with — **no baseline recommended the full workflow.** Several
  independently reconstructed the skill's own reasoning without having read it.

  The cited case study behind the premise — Spec Kit generating roughly 1,300 lines to
  display a date — is real, but it is evidence about what the *commands* generate once
  invoked, not about a model's judgment when asked a question. SC-001 was aimed at the
  wrong target.

  What the unaided baseline does get wrong is narrower and real: under social pressure it
  hedges into a reduced artifact rather than declining outright. That is the skill's
  Direct-band second temptation, and it is what the revised SC-001 measures.

  This is recorded rather than quietly corrected because the skill's own guidance tells
  users to distinguish evidence from assertion. A spec that kept an unfounded criterion
  after its own evaluation refuted it would be failing the standard the artifact it
  describes is built to enforce.

- **The revised SC-001 was then validated, and the validation found the mechanism.**
  Six prompts varying the *source* of social pressure: baseline hedged 3 of 6, the skill
  1 of 6. The effect reproduced rather than repeating a lucky single instance.

  What predicts the hedge is not pressure intensity but whether the pressure carries a
  consequence the model cannot argue away. Negotiable pressure — a team norm, a
  reviewer's comment, a peer who did it for their feature — produced clean declines
  unaided. Enforced or already-materialized pressure — a lead who blocks pull requests,
  an audit in two weeks, a spec the user has already half-written — produced the hedge
  every time. The sunk-artifact case is the sharpest: no authority figure at all, and
  the baseline still endorsed the existing file and offered to extend it.

  The evidence is honest about its limits. One author wrote both arms, n=6 per arm, and
  3-of-6 versus 1-of-6 is not statistically distinguishable. It justifies keeping the
  criterion; it does not certify the 9-of-10 rate. Closing that requires a baseline
  written by a different author blind to the hypothesis — the control that made the
  original refutation credible.
