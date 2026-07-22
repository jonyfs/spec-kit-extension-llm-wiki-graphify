# Ecosystem

**Source of truth**: Live project state read at use time, plus external tool comparison research
**Verified against**: specify-cli 0.11.3 for the discovery mechanics
**Verified on**: 2026-07-21

## Read this first: capabilities are discovered, never remembered

The single rule that governs this file: **the capability set is whatever the current
project has installed, and you find that out by reading files at the moment you are
asked.** Nothing about which extensions exist is portable between projects.

This matters because the failure it prevents is silent. If you recommend a command that
is not installed, the user does not get a helpful error from you — they get a confusing
one from their agent, and they lose trust in every other thing you said. Recommending a
capability that does not exist is worse than saying "I don't know what's installed here,
let me look."

**To any maintainer editing this file**: the seven extensions described in the worked
example below are *this repository's* extensions. They are illustration, not inventory.
Do not promote that list into a general one, and do not add "the standard extensions" as
a shortcut for readers. `ship`, `worktrees`, `critique`, `staff-review`, `onboard`,
`agent-context`, and `speckit-superpowers-bridge` are all optional, third-party or
locally-developed, and absent from most projects that use Spec Kit. A reader in a
different repository who comes away believing `/speckit.ship.run` is available to them
has been actively misled by this document.

## How to discover what is installed

Work down this list. Stop at the first surface that answers the question.

**1. Does the project use Spec Kit at all?** Check that `.specify/` exists in the repo
root. If it does not, there is no spec tooling initialized — no commands, no extensions,
no hooks. Say that plainly and offer to initialize, rather than naming steps that cannot
run.

**2. What extensions are installed, and what fires automatically?** Read
`.specify/extensions.yml`. It has three parts that answer different questions:

- `installed:` — the flat list of extension IDs present in this project.
- `settings:` — notably `auto_execute_hooks`, which controls whether non-optional hooks
  run on their own.
- `hooks:` — the *flattened* registry, keyed by hook point (`after_specify`,
  `before_plan`, `after_implement`, and so on). Each entry names the extension, the
  command it invokes, whether it is `enabled`, whether it is `optional`, its `priority`,
  and its prompt text.

The `hooks:` block is the most under-read part of any Spec Kit project, and it is where
"why did that just happen" questions get answered. Read `optional` carefully:
`optional: true` means the user is prompted and can decline; `optional: false` means the
command executes as part of the step with no prompt. Omitting the field defaults it to
optional — so a hook is only automatic if something explicitly said so.

**3. What version of each extension, from where, providing which commands?** Read
`.specify/extensions/.registry`. It is JSON, keyed by extension ID, and carries
`version`, `source` (`local` for `--dev` installs, otherwise a catalog or URL origin),
`manifest_hash`, `enabled`, `priority`, `registered_commands` (broken out per agent), and
`installed_at`. This is the authoritative answer to "what is the exact command name" —
`registered_commands` lists the literal strings that were registered.

**4. The CLI's own view.** `specify extension list` reports installed extensions;
`specify extension list --available` and `--all` bring in catalog entries that are not
installed. `specify extension info <id>` details one. Prefer the files when you only
need to read state — they are faster and cannot fail on a network call — and prefer the
CLI when the user wants to change something.

**5. Translate the command name for the user's harness.** Registered names use dotted
form: `speckit.critique.run`, `speckit.worktrees.create`. Some agent environments expose
these as slash commands with hyphens instead of dots — `speckit.critique.run` becomes
`/speckit-critique-run`. Others keep the dots. When you name a command, either match the
form the user has already been typing, or name it once in registry form and note that
their harness may hyphenate it. Do not silently invent a form you have not seen in this
project.

Also note: `priority` in the registry is a conflict-resolution number where **lower wins**
(default `10`). It only matters when two extensions register the same command name.

## Routing: which *kind* of capability fits the situation

Think in roles, not product names. A role survives the move to a project with a
completely different extension set; a product name does not. The routing question is
always "what kind of capability does this situation call for", and only then "does this
project have one".

| Situation | Role that fits | Role that does NOT fit |
|---|---|---|
| Spec and plan exist, implementation has not started | **Pre-implementation review** — challenges the intent while changing it is still cheap | A post-implementation review; there is no code to review, and it will either error on missing prerequisites or produce nothing |
| Implementation is done and needs checking | **Post-implementation review** — reads the diff against the spec | A pre-implementation review; it critiques the plan, not the result, and re-litigating design after the fact wastes the run |
| Feature is finished and reviewed, ready to go out | **Release** — pre-flight checks, branch sync, changelog, PR | Any review role; those inform release, they do not perform it |
| Several features need to progress at once | **Isolation** — a separate working tree per branch | Branch switching in place, which changes what every other command sees |
| A new developer needs orientation | **Onboarding** — guided tour of the project's own artifacts | Handing them the spec files and hoping |
| The agent's context file has gone stale | **Context refresh** — regenerates the managed block from current artifacts | Editing the context file by hand, which the refresh will overwrite |

**One ordering constraint is real and worth stating**: post-implementation review must
precede release. This is not stylistic preference. A release capability's pre-flight
step reads the most recent review report and halts if the verdict says changes are
required. Running release first means the pre-flight has nothing to read, and the gate
that was supposed to catch problems silently passes. Review, resolve, then release.

### Worked example — *this repository only*

The mapping below is what the roles above resolve to **in this specific project**, read
from `.specify/extensions.yml` and `.specify/extensions/.registry` on the verification
date. In another project every cell of this table may be empty or different.

| Role | This project's capability | Version |
|---|---|---|
| Pre-implementation review | `speckit.critique.run` — dual product/engineering lens over spec + plan | critique 1.0.0 |
| Post-implementation review | `speckit.staff-review.run` — read-only staff-level review of the diff | staff-review 1.0.0 |
| Release | `speckit.ship.run` — pre-flight, sync, changelog, CI check, PR | ship 1.0.0 |
| Isolation | `speckit.worktrees.create` / `.list` / `.clean` | worktrees 1.3.2 |
| Onboarding | `speckit.onboard.start`, `.explain`, `.trail`, `.quiz`, `.badge`, `.mentor`, `.team` | onboard 2.1.0 |
| Context refresh | `speckit.agent-context.update` | agent-context 1.0.0 |
| Handoff to an external implementer | `speckit.speckit-superpowers-bridge.handoff` / `.guard` / `.execute` | bridge 1.1.0 |

Two behaviors here are worth knowing because they surprise people. This project sets
`auto_execute_hooks: true`, and several hooks are `optional: false` — the worktree
creation after `specify`, and every bridge guard on `before_clarify`, `before_plan`,
`before_tasks`, `before_implement`, and `after_tasks`. Those run without asking. A guard
that denies a core command is the single most confusing failure mode in this
configuration; `references/recovery.md` covers diagnosing it.

## Preconditions by role, and what happens when they are unmet

Check preconditions before recommending, not after the command fails. Each of these was
read from the command definitions in this project's extensions; the *shape* generalizes,
the exact script names do not.

**Pre-implementation review** needs a spec and a plan for the current feature. Its
prerequisite check runs without requiring `tasks.md`, so it is usable in the window
between planning and task generation — which is exactly the window where it is most
valuable. Unmet: it has nothing to critique.

**Post-implementation review** requires `tasks.md` to exist — its prerequisite check runs
with an explicit require-tasks flag, which hard-errors when the file is absent. That is
why it refuses to run before implementation has been broken down. It is also strictly
read-only: it writes a report and recommends fixes, it does not apply them. If a
constitution exists, it treats any violation of it as a blocking finding.

**Release** carries the most preconditions, and each fails differently:

- `tasks.md` must exist (same require-tasks check as review). Missing: hard error.
- The working tree should be clean; it runs `git status` and prompts you to commit or
  stash before continuing.
- A git remote must be resolvable — it detects one (defaulting to `origin`) and fetches.
  Without a remote, sync and push have no destination.
- A review report, if the feature has a reviews directory, is read and honored: a
  "changes required" verdict stops the run.
- CI status and PR creation go through the GitHub CLI, so `gh` must be present and
  authenticated for those steps.

Its destructive operations — rebase or merge during sync, any push including force push,
branch deletion, PR creation — each require explicit confirmation with the default answer
set to *no*. Say this when recommending it; a user who expects a read-only check will be
alarmed by the prompts.

**Isolation** requires an actual git repository (verified via `git rev-parse
--show-toplevel`) and working `git worktree` support. It refuses to create a second
worktree for a branch that already has one, reporting the existing path instead — that is
a safety feature, not an error. For a new branch it creates from the configured base ref;
for an existing branch it attaches. Nested layouts need the worktree directory in
`.gitignore`, which it handles.

**Context refresh** needs a configured context file path. If the config is empty or the
file cannot be located, it reports nothing to do and exits successfully — a no-op, not a
failure. It manages only the region between its start and end markers, so hand edits
inside that region are lost on the next run and edits outside it are safe.

**Onboarding** reads whatever project artifacts it can find and degrades gracefully when
they are missing, noting the gap and continuing. It bounds how many features it reads to
avoid exhausting context.

## How extensions reach a project

Four distribution forms exist — a local directory via `--dev`, a ZIP from a custom URL,
a catalog entry, and extensions bundled inside the CLI itself. All four converge on the
same install path, so the on-disk result is identical; only delivery differs. The
mechanics, layout requirements, and release checklist live in `docs/PACKAGING.md`; do not
reconstruct them from memory.

Two user-facing facts belong here rather than in a packaging doc, because they change
what you should *advise*:

**Installing a third-party extension is a trust decision.** The downloaded package is not
verified against a publisher signature or a catalog checksum. HTTPS is the only transport
guarantee — it proves you reached the host you asked for, and nothing about what that
host served you. The `manifest_hash` recorded at install time detects later local
tampering; it does not authenticate the download. Adding a catalog with
`--install-allowed` grants that catalog's operator code-execution reach into the project.
Say this when someone is about to install something they did not write.

**Hooks with `optional: false` execute without asking.** An extension can therefore change
what a core Spec Kit step does, simply by being installed. That is the intended design,
but it means "I installed an extension" and "I changed the behavior of `/speckit.plan`"
can be the same event.

## Competing and adjacent tools

These are real alternatives with real users. Describe the difference in approach honestly;
do not dismiss them, and do not oversell Spec Kit against them. None of these has
controlled evidence of better outcomes — see the evidence discussion in `SKILL.md`.

**Kiro (AWS)** uses EARS requirements notation, a constrained-English pattern with
aerospace and safety-critical lineage, which makes requirements unusually machine-checkable.
Steering files carry persistent project context. It is the lightest of the major tools,
and its documented weakness is the shared one: it overshoots on small fixes.

**Tessl** is the only tool genuinely pursuing spec-as-source — the spec, not the code, is
the artifact of record, with bidirectional sync and a spec registry. It is the most
radical reframing available and correspondingly the least validated in practice.

**BMAD-METHOD** simulates an organization chart: multiple agent roles (analyst, PM,
architect, developer, QA) hand work between each other. It produces the most output of any
approach here, which is either thoroughness or verbosity depending on the size of the work.

**OpenSpec** is deliberately lightweight — folder-based, tool-agnostic, no CLI lock-in. Its
distinctive strength is delta modeling: describing a *change* to an existing system rather
than a system from scratch, which is what brownfield work actually looks like. It appears
on the Thoughtworks Technology Radar.

**Agent OS** organizes context in three layers — standards (how we build), product (what we
are building), spec (this piece of work). The layering is its whole idea and it maps
cleanly onto the constitution/spec split other tools use implicitly.

**GSD** reframes the problem entirely. Its premise is that agent failure is **context rot**,
not insufficient specification — so it uses per-phase orchestrators and gives each unit of
work fresh context. The crisp distinction from the research is worth quoting directly:
*Superpowers constrains HOW AI writes code; GSD constrains the CONDITIONS UNDER WHICH AI
writes code.*

**Superpowers** enforces mandatory test-driven development and ships a large library of
composable skills. It is a discipline layer over implementation rather than a specification
system, which is why bridging it to a spec tool (as this project does) is coherent rather
than redundant.

**Taskmaster** builds a dependency-aware task graph from a PRD. It overlaps the task-
generation step specifically and not the rest of the workflow.

**The lightweight end** — `AGENTS.md` (now stewarded by the Linux Foundation's Agentic AI
Foundation), `CLAUDE.md`, and Cursor rules — are standing context files. They cover the
**constitution layer only**: durable project-wide constraints. There is no per-feature
spec, no plan, and no task graph. That is a design choice, not an omission, and for many
projects it is the whole of what is needed.

## When another tool is the better answer

Say so. Recommending the tool in front of you when a different one fits is the same failure
as recommending a command that is not installed.

**Use OpenSpec's model for brownfield delta work.** When the task is "change this behavior
in a system that already exists", a spec that describes the delta is more useful and far
cheaper than one that re-specifies the whole subsystem to establish context.

**Use a plain `AGENTS.md` when the project needs standing constraints and nothing else.**
If what the team actually wants is "always use this test framework, never touch the
generated directory, here is our error-handling convention", that is a constitution-layer
need. Per-feature specs, plans, and task graphs add ceremony with no corresponding benefit,
and the honest answer is one well-written context file.

## Where the other facts live

This file covers what exists and how to find it. It deliberately does not cover:

- What each core workflow step consumes and produces → `references/workflow.md`
- How to write a spec well — sizing, layering, testable criteria → `references/craft.md`
- Diagnosing a blocked command, drifted artifacts, or hook interference →
  `references/recovery.md`
