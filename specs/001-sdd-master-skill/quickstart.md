# Quickstart: Validating the SDD Master Skill

**Phase**: 1 — Design & Contracts
**Spec**: [spec.md](./spec.md) · **Contracts**: [routing-contract.md](./contracts/routing-contract.md)

How to prove the skill works, end to end. Written so someone who did not build it can
run the validation and reach the same verdict.

The skill is prose, so "does it work" means "does it change behavior in the right
direction". That requires comparing against a baseline — the whole point, given that
added context has been measured as net-negative in some settings (see
[research.md](./research.md) D6).

---

## Prerequisites

| Requirement | Check |
|---|---|
| Repository checked out on the feature branch | `git branch --show-current` → `001-sdd-master-skill` |
| Skill package present | `ls .claude/skills/sdd-master/SKILL.md` |
| Both reference and eval sets present | `ls .claude/skills/sdd-master/references/ .claude/skills/sdd-master/evals/` |
| Python available for the packaging check | `python3 --version` |

---

## 1. Structural check

Verifies the package satisfies [skill-frontmatter.md](./contracts/skill-frontmatter.md)
before spending tokens on behavior.

```bash
cd .claude/skills/sdd-master

# Frontmatter present, name matches the directory
head -5 SKILL.md

# Body stays cheap to load
wc -l SKILL.md

# Every reference carries provenance
grep -L 'Verified against' references/*.md
```

**Expected**: frontmatter shows `name: sdd-master`; `SKILL.md` is under 500 lines; the
`grep -L` prints nothing, meaning no reference is missing its provenance header.

```bash
# No template placeholders survived (constitution Principle III)
grep -rn 'CUSTOMIZE:\|REPLACE THIS\|your-org' . || echo "clean"
```

**Expected**: `clean`.

---

## 2. Behavioral evaluation

The core validation. Three cases, each run twice — once with the skill available, once
without — by independent agents that did not write it.

```bash
cat .claude/skills/sdd-master/evals/evals.json
```

| Case | Asserts | Criterion |
|---|---|---|
| `route-large-feature-to-full-flow` | Routes to the full workflow, steps in dependency order | SC-002, contract C4 |
| `resist-ceremony-on-trivial-change` | Produces no artifacts, adds no process | SC-001, contract C3 |
| `diagnose-broken-mid-flow-state` | Names both causes, prescribes preserving recovery | SC-003, contract C7 |

Run each case in a fresh session, both configurations, saving outputs to
`.claude/skills/sdd-master-workspace/iteration-N/<case>/{with_skill,without_skill}/`.

**Expected outcomes**

- `resist-ceremony-on-trivial-change` — **with skill**: the copy fix and the link fix
  are made, nothing else. **Without skill**: also acceptable. This case is a
  *regression guard*, not a win condition. If the skill makes this case worse by
  introducing ceremony, the skill is net-harmful regardless of how the other two score.
- `route-large-feature-to-full-flow` — **with skill**: names the workflow steps in
  dependency order and says which artifact each produces. **Without skill**: expect
  generic architecture advice or an immediate dive into code.
- `diagnose-broken-mid-flow-state` — **with skill**: separates the prerequisite failure
  from the drift, gives a regeneration order, names the consistency check. **Without
  skill**: expect "start over" or a partial diagnosis.

**Verdict**: the skill passes when it wins clearly on cases 1 and 3 and does no harm on
case 2. Winning cases 1 and 3 while adding ceremony to case 2 is a failure — that
tradeoff reintroduces the exact problem the feature exists to solve.

---

## 3. Trigger evaluation

Separate from behavior. A skill can hold excellent guidance and never fire.

```bash
cat .claude/skills/sdd-master/evals/trigger-evals.json
```

Twenty realistic queries — roughly half should activate the skill, half should not,
weighted toward near-misses that share vocabulary with the domain:

- **Should trigger**: substantial feature work described without naming the
  methodology; confusion about workflow state; questions about where a decision belongs.
- **Should not trigger**: writing an interface specification for a service; reading a
  hardware spec sheet; an unrelated task list; a one-line fix with a named file.

**Expected**: high activation on should-trigger, low on should-not-trigger. SC-006 is
the criterion. The description is tuned against this set — the wording is an
experimental result, not an authoring preference.

---

## 4. Contract spot-check

Read one transcript from step 2 against
[routing-contract.md](./contracts/routing-contract.md). The clauses cheapest to verify
by eye:

- **C1** — exactly one recommendation, not a menu.
- **C2** — the deciding signal is named, and what would change it.
- **C3** — the trivial case produced no artifacts.
- **C12** — the actionable part is in the first response.

A response that satisfies every clause but reads as a checklist recital has passed the
letter and failed the intent. Note that qualitatively; it is a signal to rewrite for
voice, not to add rules.

---

## 5. Constitution gate

Before opening the pull request:

```bash
cd "$(git rev-parse --show-toplevel)"
bash scripts/check-placeholders.sh
git status --short
```

**Expected**: placeholder guard clean; nothing staged outside
`.claude/skills/sdd-master/` and `specs/001-sdd-master-skill/` (Principle VI).

CI runs lint, manifest validation, the placeholder guard, and the install-test cycle.
All four must be green before review (Principle XIV).

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Skill never activates | Description too narrow, or the query is one Claude handles without help | Check the trigger eval score before rewriting the body — this is a description problem |
| Skill activates on unrelated requests | Non-trigger clause too weak | Add the specific near-miss to the negative set and re-tune |
| Trivial case gains ceremony | Band thresholds too aggressive | Raise the bar for `full`; verify a raising signal is genuinely required |
| Guidance is right but buried | Body is doing reference work | Move facts into a reference; keep judgment in the body |
| Responses read as recital | Rules crowding out reasoning | Explain why a rule exists rather than adding another rule |
