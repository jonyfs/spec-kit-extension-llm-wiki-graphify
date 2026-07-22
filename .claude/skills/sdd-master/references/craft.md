# Craft: Writing Specs That Earn Their Cost

**Source of truth**: External practitioner literature and published studies, named authors prioritized
**Verified against**: Sources current as of the research snapshot
**Verified on**: 2026-07-21

This file answers judgment questions: where a decision belongs, whether criteria are
testable, how big a feature should be, how to write for an agent, and whether any of
this actually works. It does not describe what each workflow step does
(`workflow.md`), how to diagnose and repair a broken or drifted workflow
(`recovery.md`), or what tooling is installed here (`ecosystem.md`).

---

## 1. The three-layer question — where does this belong?

Almost every "where do I put this?" question resolves into three layers with genuinely
different lifetimes.

| Layer | Lifetime | Holds | Does not hold |
|---|---|---|---|
| **Constitution / standards** | Project lifetime; changes rarely and deliberately | Architecture invariants, tech stack, code style, security boundaries, never-do rules | Anything specific to one feature |
| **Specification** | One feature; survives the feature | What and why, user outcomes, acceptance criteria, edge cases, non-goals | Implementation choices — no file names, no library picks, no data structures |
| **Plan** | One feature; disposable once implemented | How: file-level design, technology decisions scoped to this feature, sequencing | Restatement of the goals; those live in the spec |

### The discriminating test

Two questions decide it, and they generalize beyond whatever example prompted the ask.

**Would it be true of the next feature too?** If yes, it belongs in the constitution.
"All commands are namespaced under the extension name" is true of every command this
project will ever ship — constitution. "This feature adds three commands" is true of
exactly one feature — spec.

**Could a competent engineer reasonably choose differently without changing observable
behavior?** If yes, it belongs in the plan, not the spec. Whether the cache is a map or
an LRU is invisible to the user and reversible; that is a plan decision. Whether stale
data may ever be served is visible and is a spec decision. The test is *observability*,
not importance — plan decisions can be hard and consequential and still belong in the
plan.

### The corollary most people miss

If the agent can discover it from the codebase, it often should not be written down at
all. A paragraph explaining the directory layout duplicates something a file listing
already answers, and it will drift while the file listing cannot. Write down what is
*not* recoverable from the code: intent, constraints, rejected alternatives, and rules
about what must never happen. This corollary has direct evidential support — see §5,
where added repository context helped materially only when other documentation was
absent.

### Why believe the layering is real

Three tools designed independently converged on the same three layers: Spec Kit's
constitution, Kiro's steering files, and Agent OS's standards layer. Convergent design
under independent constraints is decent evidence the boundary is a real one rather than
one vendor's taxonomy. It is not proof — all three had partly overlapping influences —
but a shape that three teams reached separately is worth taking seriously.

---

## 2. Testable acceptance criteria

**Adjectives are unusable.** "Should feel responsive", "must be intuitive", "handles
errors gracefully" — none of these can fail. A criterion nobody can fail is not a
criterion; it is a mood. Every unmeasurable adjective must be replaced with an outcome
someone could observe and disagree about.

Concrete rewrites:

| Before | After |
|---|---|
| The dashboard should feel responsive | The dashboard renders its first row within 1 second on a 3G connection; a spinner appears if data has not arrived within 300 ms |
| Errors are handled gracefully | On a failed save, the user's input is preserved, an error banner names which field failed, and no partial write reaches the database |
| The onboarding flow should be intuitive | A first-time user completes the flow without opening documentation; every step is reachable by keyboard alone |
| The API must be secure | Requests without a valid token receive 401; token scope is checked per endpoint; secrets never appear in logs or error bodies |
| Search should be fast and accurate | Median query returns in under 200 ms; an exact title match ranks first in every case in the sample set |

### Two formats, and when each fits

**Given / When / Then** fits user-facing behavior with a setup that matters.

> **Given** a signed-in user with an expired subscription, **When** they open a paid
> report, **Then** they see the upgrade prompt and the report body is not fetched.

**EARS** (`WHEN <condition> THE SYSTEM SHALL <behavior>`) fits system rules, constraints,
and anything closer to a requirement than a scenario. It is terser and its uniform shape
makes a missing condition or a missing behavior visible at a glance.

> WHEN a webhook signature fails verification THE SYSTEM SHALL reject the request with
> 400 and record the sender identifier.

Use Given/When/Then when the reader needs to picture a situation; use EARS when the
reader needs to check a rule. Mixing both in one spec is fine and common — matching the
format to the statement beats consistency for its own sake.

### Embed sample test cases

Putting one or two concrete input/expected-output pairs directly in the spec measurably
reduces correction rounds, because a table of examples pins down boundary behavior that
prose leaves open. Two rows of a table settle what "empty input" and "maximum length"
mean far faster than a paragraph attempting to say it.

### Completeness yet conciseness

The target phrase from the literature is *"completeness yet conciseness, covering the
critical path without enumerating all cases."* This is the explicit antidote to
imaginary-corner-case bloat: cover the path the feature exists to serve, plus the edge
cases you actually expect, and stop. Enumerating every hypothetical failure inflates the
spec, buries the critical path, and consumes context that the implementation needs. If
you cannot name a plausible situation that produces the case, it does not belong yet.

---

## 3. Sizing a feature

**Say plainly that this is unsolved.** No source offers a reliable rule for where one
spec should end and the next begin, and practitioners report this as an active pain
point rather than a settled matter. What follows are the best available heuristics, not
a method.

**Micro-specs.** Aim at one feature or one component — user-story-sized, not
epic-sized. A spec covering "the billing system" will be simultaneously too vague to
implement and too long to review. A spec covering "prorate a mid-cycle plan change" can
be both specific and finishable.

**Match spec depth to task complexity.** Over-specifying a trivial problem does not
merely waste effort; it degrades the result. Excess prose consumes context that the
implementation needs, and it introduces more surface for the agent to over-interpret. A
detailed specification of a copy change confuses more than it guides.

**Size to context capacity.** A practical mechanical rule: size a unit of work so its
entire execution — spec, plan, relevant code, and the edit loop — stays well under the
context window. If a unit routinely exhausts context mid-run, it was too big regardless
of how it looked on paper.

**The reported pain, stated honestly.** Practitioners report being unable to tell
"where one spec ended and the next began", and one solo developer reported specs
consuming roughly **50% of total project time** before abandoning pure SDD altogether
(practitioner report, n=1 — real experience, not a measured population). Both data
points argue for smaller units and for the discrimination this skill's router exists to
apply, rather than for a better sizing formula that nobody has.

---

## 4. Writing a spec an agent can actually use

**Show, do not describe.** The single most repeated line across the literature: *one
real code snippet showing your style beats three paragraphs describing it.* An example
is unambiguous, checkable, and short. A description of the same thing is none of those.
This holds for style, for API shape, for error format, for commit messages — anywhere
you are tempted to explain a convention, paste an instance of it instead.

**Three-tier boundaries, not a flat prohibition list.** A long list of "don't" items
reads as undifferentiated noise and gets partially ignored. Split it:

- **Always do** — the defaults, applied without asking.
- **Ask first** — actions that are sometimes right: schema migrations, dependency
  additions, deleting files, touching CI configuration.
- **Never do** — the hard stops. *"Never commit secrets"* is reported as the single
  most helpful constraint practitioners have written down.

The middle tier is what makes this work. Without it, everything ambiguous gets shoved
into "never", and the genuinely absolute rules lose their force.

**Non-goals and open questions are worth disproportionate space.** They bound
over-engineering, which is the top agent failure mode: given an unbounded objective, an
agent adds. "This feature does not handle multi-region" and "unresolved: whether
retries are idempotent" each prevent a class of unwanted work, and both are two lines
long. Few sections have a better ratio.

**Favor what and why over how.** The *why* is the part the agent cannot reconstruct
from the code, and it is what lets it make a sensible call when it hits something the
spec did not anticipate — which it will.

---

## 5. Evidence grading — and the honest state of the evidence

Every outcome claim carries a grade. Factual claims about tool behavior do not need one;
claims about whether something *works* always do.

| Grade | Meaning | How to present it |
|---|---|---|
| `controlled` | Controlled study or measured telemetry | State the finding **and its scope** — what was measured, on whom |
| `practitioner` | A named author reporting real project experience | Attribute it by name; say n=1 where it is |
| `vendor` | Tool marketing, or a claim with no stated method | Name it as marketing, or leave it out |

Absent any grade, the correct answer is **"this is not established"** — not a confident
guess dressed as consensus.

### What the controlled evidence actually says

This is the part that must not be softened.

- **ETH Zurich / LogicStar.ai, AGENTBENCH** (4 models, 2 benchmarks, 138 real GitHub
  issues): LLM-generated repository context files **decreased** task success by 2–3%.
  Human-written ones helped only about **4%**. Both raised inference cost by over
  **20%**. Context files helped materially **only when other documentation was absent** —
  functioning as *compensation for missing docs, not as uplift*.
- **METR**: experienced developers were measured **19% slower** with AI assistance while
  believing they were about **20% faster**. Self-reported productivity gains from this
  class of tooling are not reliable evidence.
- **Faros telemetry, 1,255 teams**: throughput up, but review time **+91%**, PR size
  **+154%**, bugs **+9%**. More output is not the same as more delivered value.

**There is no controlled study showing that spec-driven development improves velocity,
defect rate, or rework relative to lighter AI-assisted workflows.** None. Anyone
claiming otherwise is offering a practitioner report or a vendor claim.

### The defensible position

Both the strongest advocates and the strongest critics converge here: **SDD's value is
human alignment and scope control** — making intent reviewable before code exists, and
bounding agent over-reach during implementation. That is a real and worthwhile benefit
for work where being wrong is expensive. It is *not* a claim that a model generates
better code because a document exists.

### Why this honesty is load-bearing

A skill that oversells SDD produces exactly the ceremony problem it exists to prevent.
If the guidance implies that more written artifacts reliably yield better output, the
rational response is to write more artifacts for everything — which is the documented
failure mode, and which the controlled evidence argues against directly. The honest
framing is what makes proportionate routing coherent rather than arbitrary. The
disclaimer *is* the method.

---

## 6. Spec rot and drift

Böckeler's taxonomy distinguishes three postures:

- **Spec-first** — the spec drives generation, then is discarded once the code ships. The
  spec was scaffolding.
- **Spec-anchored** — the spec is kept alive alongside the code as the durable statement
  of intent. This is where most teams *say* they are and where they commonly fail, because
  keeping it current is ongoing unpaid work with no forcing function.
- **Spec-as-source** — the spec is the artifact of record and code is derived from it.
  Rare, and demanding of tooling.

Most teams are spec-first in practice. The honest move is to admit that rather than
maintaining the fiction of a living spec that nobody has updated in six weeks — a
truthful spec-first posture is more useful than a nominal spec-anchored one, because
readers then know not to trust a stale document.

**Direction-of-repair and drift repair procedures are not here.** See `recovery.md`.

---

## 7. When SDD is the wrong tool

Reach for something lighter, or nothing, when:

- **Exploratory spikes.** The target is still moving; specifying it wastes the effort by
  construction.
- **Firefighting hotfixes.** Time-to-fix dominates, and the spec would be written after
  the fact anyway.
- **Throwaway prototypes.** The artifact outlives nothing.
- **Domains with unclear boundaries.** If you cannot yet say where the feature ends, the
  spec will encode a wrong boundary and make it durable.
- **Aesthetic judgment work.** Visual design, copy tone, interaction feel — the
  acceptance criterion is "someone with taste looked at it", and writing that down does
  not help.
- **Large brownfield codebases.** Comprehensive specification is infeasible and attempting
  it stalls indefinitely. Spec only the area of change, and treat the surrounding system
  as given.
