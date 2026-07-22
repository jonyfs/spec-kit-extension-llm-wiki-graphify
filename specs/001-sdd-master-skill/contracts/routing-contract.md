# Contract: Routing Behavior

**Phase**: 1 — Design & Contracts
**Consumer**: A user, via the agent, in any conversation

This is the skill's observable interface. It has no callable API — the contract is what
a response must contain to be conformant. Each clause is stated so a grader can check
it against a transcript without knowing how the skill is written.

---

## C1: Exactly one recommendation

**Given** any request the skill activates on
**Then** the response names exactly one recommended path.

Conformant: "Go straight to planning — the spec has no open questions."
Non-conformant: "You could clarify first, or plan, or just start implementing."

Rationale: FR-005. A menu offloads the judgment the skill exists to supply.

---

## C2: The deciding signal is stated

**Given** the skill has classified a request
**Then** the response names the specific signal that set the band, and what would
change it.

Conformant: "Full workflow — this touches authorization, and you said your lead wants
it written down first. If it were a display-only change I would say otherwise."
Non-conformant: "This seems complex, so let's use the full workflow."

Rationale: FR-004. An unstated reason cannot be argued with, so the user cannot correct
a wrong classification.

---

## C3: Trivial requests produce no artifacts

**Given** a request with no raising signals and at least one lowering signal
**Then** the response produces no specification, plan, or task artifact, and adds no
process step.

The skill MAY note in one sentence why the workflow is not warranted. It MUST NOT walk
the user through it anyway.

Rationale: FR-003, SC-001. This is the clause the whole feature turns on — the
documented failure mode is generating ~1,300 lines to change a date.

---

## C4: Full routing names steps in dependency order

**Given** the skill routes to the full workflow
**Then** the response names the steps in an order that respects their prerequisites,
and states which artifact each produces.

Rationale: FR-006, SC-002. Naming steps out of order guarantees the user hits a hard
prerequisite error, which is exactly the state US2 exists to recover from.

---

## C5: Preconditions are checked before recommending

**Given** the skill recommends a step with an unmet precondition
**Then** the response names the unmet precondition and what satisfies it, instead of
issuing a recommendation that will fail.

Conformant: "Isolated worktrees need a git repository, and this directory is not one
yet. Initialize first, or work in place."
Non-conformant: "Create a worktree for the feature." (in a non-git directory)

Rationale: FR-013.

---

## C6: Destructive consequences precede the recommendation

**Given** a recommended action would discard work or is otherwise hard to reverse
**Then** the response states that consequence before the recommendation, and offers a
preserving alternative where one exists.

Rationale: FR-014, US2 acceptance scenario 4.

---

## C7: Diagnosis precedes prescription

**Given** a request describing a broken or confusing workflow state
**Then** the response identifies the cause — which artifact is authoritative, which are
stale, which capability is interfering — before prescribing a repair, and the repair
preserves completed work where possible.

Rationale: US2, SC-003. "Start over" is almost never the correct answer and is always
the least informative one.

---

## C8: Outcome claims carry their evidence grade

**Given** a response asserts that the methodology improves an outcome
**Then** it distinguishes controlled evidence from practitioner report from vendor
claim.

**Given** the sources do not establish an answer
**Then** the response says so rather than producing a confident one.

Rationale: FR-009, FR-010. The strongest controlled evidence available points against
the naive "more written context is better" intuition; a skill that hides that is
selling rather than advising.

---

## C9: Capabilities are read, not assumed

**Given** a response references available workflow capabilities
**Then** those are derived from what is installed in the current project.

The skill MUST NOT assert that a capability exists because it exists in the project
where the skill was authored.

Rationale: FR-011, and the spec's edge case about differing installed sets.

---

## C10: Governance wins

**Given** the skill's recommendation conflicts with the project's stated governance
**Then** the response follows governance and states that it is deferring, and why.

Rationale: FR-012.

---

## C11: Explicit instruction outranks the default

**Given** the user explicitly asks for a path the signals do not warrant
**Then** the response complies and states the cost, rather than refusing or silently
substituting its own preference.

Rationale: FR-007, US1 acceptance scenario 4.

---

## C12: Actionable in one exchange

**Given** any activation
**Then** the actionable part of the guidance is present in the first response, without
requiring a follow-up question to extract it.

Clarifying questions are permitted when the request is genuinely ambiguous, but the
response must still carry a recommendation conditioned on the likely answers.

Rationale: SC-008.

---

## Non-goals

Explicitly outside this contract, to bound what a grader should look for:

- **Executing the workflow.** The skill advises; the workflow steps do the work.
- **Editing artifacts.** The skill does not rewrite a user's specification unless asked.
- **Replacing governance.** Where a project constitution speaks, it governs (C10).
- **Neutral tool comparison.** Spec Kit is the primary methodology per the spec's
  assumptions; alternatives are described accurately but not given equal depth.
