<!--
SYNC IMPACT REPORT (v1.6.0)
Version change: 1.5.0 → 1.6.0
Rationale: MINOR — added one new principle (XIV. Trunk-Based Delivery Through
Pull Requests) and one new section (Continuous Integration Gates). No existing
principle removed or redefined.

Added principles:
- XIV. Trunk-Based Delivery Through Pull Requests

Added sections:
- Continuous Integration Gates

Repository state established this amendment:
- git initialized on `main`; remote https://github.com/jonyfs/spec-kit-extension-llm-wiki-graphify (public)
- .github/workflows/ci.yml with four jobs: lint, validate, placeholders, install-test
- .github/pull_request_template.md carrying the per-principle checklist
- scripts/validate-extension.py, scripts/check-placeholders.sh, scripts/install-test.sh

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (constitution-driven gate; no edit)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ✅ README.md (created; documents the workflow and validation tooling)
- ✅ CHANGELOG.md (created; Keep a Changelog format per Principle VIII)
- ✅ LICENSE (created; MIT)
- ✅ docs/HOOKS.md, docs/PACKAGING.md (unchanged; still accurate)

Resolved from v1.0.0: README.md, CHANGELOG.md, and LICENSE now exist.
Follow-up TODOs: none deferred.

--- PREVIOUS REPORT (v1.5.0) ---
Version change: 1.4.0 → 1.5.0
Rationale: MINOR — added one new principle (XIII. Proactive Use of Installed
Extensions) and one new section (Installed Extension Baseline). No existing
principle removed or redefined.

Added principles:
- XIII. Proactive Use of Installed Extensions

Added sections:
- Installed Extension Baseline

Installed this amendment (all via `specify extension add --from`, source "local"):
- worktrees 1.3.2, ship 1.0.0, critique 1.0.0, staff-review 1.0.0,
  speckit-superpowers-bridge 1.1.0, onboard 2.1.0

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (constitution-driven gate; no edit)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ✅ docs/HOOKS.md, docs/PACKAGING.md (unchanged; still accurate)
- ⚠ README.md / CHANGELOG.md / LICENSE still pending from v1.0.0
- ⚠ Six hooks are registered `optional: false` (auto-executing) by worktrees and
  speckit-superpowers-bridge — accepted as third-party behavior, see Principle
  XIII; Principle IV continues to bind extensions THIS project authors.

Follow-up TODOs: none deferred.

--- PREVIOUS REPORT (v1.4.0) ---
Version change: 1.3.0 → 1.4.0
Rationale: MINOR — added one new principle (XII. Every Distribution Form,
Verified). No existing principle removed or redefined; Principle VII's install
gate is extended by reference, not redefined.

Added principles:
- XII. Every Distribution Form, Verified

Added artifacts:
- docs/PACKAGING.md (the maintained distribution matrix required by Principle XII)

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (constitution-driven gate; no edit)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ✅ docs/PACKAGING.md (created; verified against specify-cli 0.11.3)
- ✅ docs/HOOKS.md (unchanged; still accurate)
- ⚠ README.md / CHANGELOG.md / LICENSE still pending from v1.0.0

Follow-up TODOs: none deferred.

--- PREVIOUS REPORT (v1.3.0) ---
Version change: 1.2.0 → 1.3.0
Rationale: MINOR — added one new principle (XI. Hook Literacy Across Harnesses)
and materially expanded the hook guidance already present in Principle IV by
reference. No existing principle removed or redefined.

Added principles:
- XI. Hook Literacy Across Harnesses

Added artifacts:
- docs/HOOKS.md (the maintained hook matrix required by Principle XI)

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (constitution-driven gate; no edit)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ✅ docs/HOOKS.md (created; documents both hook layers)
- ⚠ README.md / CHANGELOG.md / LICENSE still pending from v1.0.0

Follow-up TODOs: none deferred.

--- PREVIOUS REPORT (v1.2.0) ---
Version change: 1.1.0 → 1.2.0
Rationale: MINOR — added one new principle (X. Compressed Communication,
Uncompressed Artifacts) and one new governance-adjacent section (Vendored
Third-Party Assets). No existing principle removed or redefined.

Added principles:
- X. Compressed Communication, Uncompressed Artifacts

Added sections:
- Vendored Third-Party Assets

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (constitution-driven gate; no edit)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ✅ .claude/skills/caveman/ (vendored from juliusbrussee/caveman @ 0d95a81,
  MIT, with PROVENANCE.md — compliant with the new section)
- ⚠ README.md / CHANGELOG.md / LICENSE still pending from v1.0.0

Follow-up TODOs: none deferred.

--- PREVIOUS REPORT (v1.1.0) ---
Version change: 1.0.0 → 1.1.0
Rationale: MINOR — added one new principle (IX. English Artifacts, Native
Conversation). No existing principle removed or redefined.

Added principles:
- IX. English Artifacts, Native Conversation

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (constitution-driven gate; no edit)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ⚠ README.md / CHANGELOG.md / LICENSE still pending from v1.0.0

Follow-up TODOs: none deferred.

--- PREVIOUS REPORT (v1.0.0) ---
Version change: (unversioned template) → 1.0.0
Rationale: First ratification. All placeholder tokens replaced with concrete,
testable governance for a Spec Kit extension template project.

Modified principles:
- [PRINCIPLE_1_NAME] → I. Manifest Is the Contract
- [PRINCIPLE_2_NAME] → II. Namespaced Commands (NON-NEGOTIABLE)
- [PRINCIPLE_3_NAME] → III. Template Placeholders Must Be Obvious
- [PRINCIPLE_4_NAME] → IV. Hooks Are Opt-In by Default
- [PRINCIPLE_5_NAME] → V. Cross-Platform Script Parity
- (added) VI. Additive, Non-Destructive Project Changes
- (added) VII. Install-Test Before Publish
- (added) VIII. Semantic Versioning & Changelog

Added sections:
- Upstream Compatibility Constraints (replaces [SECTION_2_NAME])
- Development Workflow & Quality Gates (replaces [SECTION_3_NAME])

Removed sections: none

Templates requiring updates:
- ✅ .specify/templates/plan-template.md (Constitution Check gate is
  constitution-driven and generic; no edit required)
- ✅ .specify/templates/spec-template.md (no constitution-specific slots)
- ✅ .specify/templates/tasks-template.md (no constitution-specific slots)
- ✅ .specify/templates/checklist-template.md (no constitution-specific slots)
- ✅ .specify/extensions/agent-context/* (already compliant with I, II, IV, V)
- ⚠ README.md (does not exist yet; must be created per Principle VII)
- ⚠ CHANGELOG.md (does not exist yet; must be created per Principle VIII)
- ⚠ LICENSE (does not exist yet; required for publishing per Principle VII)

Follow-up TODOs: none deferred.
-->

# Spec Kit Extension Template Constitution

This project is a **template for creating GitHub Spec Kit extensions**. Its output
is an extension package — a manifest, commands, optional scripts and config — that
installs into any Spec Kit project via `specify extension add`. Upstream reference:
`github/spec-kit`, directory `extensions/` (`EXTENSION-API-REFERENCE.md`,
`EXTENSION-DEVELOPMENT-GUIDE.md`, `EXTENSION-PUBLISHING-GUIDE.md`).

## Core Principles

### I. Manifest Is the Contract

Every extension produced from this template MUST ship a valid `extension.yml` with
`schema_version: "1.0"` and complete `extension` metadata (`id`, `name`, `version`,
`description`, `author`, `repository`, `license`). `extension.id` MUST match
`^[a-z0-9-]+$`. `requires.speckit_version` MUST be a version specifier with no
spaces (for example `>=0.2.0` or `>=0.2.0,<2.0.0`) — never a bare version, never
`latest`. Every file referenced by `provides.commands[].file`,
`provides.config[].template`, and any script path MUST exist in the package.

Rationale: The manifest is what the CLI validates, hashes into `.registry`, and uses
to register commands. A manifest that lies about its files fails at install time on
the user's machine, not ours.

### II. Namespaced Commands (NON-NEGOTIABLE)

Every command name and alias MUST match `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$` and the
middle segment MUST equal `extension.id`. Commands MUST NOT shadow a core Spec Kit
command (`speckit.specify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`,
`speckit.analyze`, `speckit.clarify`, `speckit.checklist`, `speckit.constitution`)
nor a command already registered by another extension.

Rationale: Command registration is a flat namespace across every installed
extension. Collisions silently overwrite a user's working workflow.

### III. Template Placeholders Must Be Obvious

Every value an author is expected to change MUST be marked in place with a
`# CUSTOMIZE:` comment (or `# REVIEW:` where the default is usually acceptable), and
MUST use an unmistakable placeholder value (`my-extension`, `Your Name`,
`https://github.com/your-org/...`). No template file may ship a plausible-looking
real value that an author could leave in by accident. A generated extension MUST NOT
be publishable until every `CUSTOMIZE` marker is resolved.

Rationale: The single biggest failure mode of a template is shipping the template's
own identity to a registry. Placeholders that look wrong get fixed.

### IV. Hooks Are Opt-In by Default

Hooks declared under `hooks:` MUST default to `optional: true` and MUST supply a
`prompt` and a `description`. `optional: false` (auto-execute) is permitted ONLY for
read-only hooks or hooks whose writes are confined to files the extension itself
owns, and the justification MUST be recorded in the extension README. Where an event
carries multiple hooks, each entry MUST declare an explicit integer `priority` (≥ 1,
lower runs first) rather than relying on the default of 10. Hook `condition`
expressions MUST NOT be evaluated by command prose — condition handling belongs to
the HookExecutor.

Rationale: A hook fires inside someone else's project on someone else's branch.
Silent, mandatory side effects are how extensions get uninstalled.

### V. Cross-Platform Script Parity

If an extension provides scripts, it MUST provide behaviorally equivalent `bash`
(`scripts/bash/*.sh`) and `powershell` (`scripts/powershell/*.ps1`) implementations,
and command frontmatter MUST reference both via `scripts.sh` and `scripts.ps`. Adding
a `scripts/python/` variant is permitted but never a substitute for the other two.
Shipping one platform only is a release blocker.

Rationale: Spec Kit resolves the script variant from the host platform. A missing
variant makes the extension simply not work for half of its users.

### VI. Additive, Non-Destructive Project Changes

An extension MUST confine its writes to `.specify/extensions/{extension-id}/`, to
files it created, and to explicitly delimited managed regions (marker-fenced blocks)
inside shared files such as agent context files. It MUST NOT rewrite or reorder
content outside its markers, MUST NOT delete user content, and MUST NOT commit,
push, or otherwise alter git history unless that is the extension's stated purpose
and the user invoked it directly.

Rationale: Extensions run against real repositories with uncommitted work. Anything
outside a managed region belongs to the user.

### VII. Install-Test Before Publish

No extension may be tagged for release until it has been installed into a real Spec
Kit project via `specify extension add --dev <path>`, appeared correctly under
`specify extension list`, had **every** declared command and hook executed at least
once, and been cleanly removed. The package MUST additionally contain a `README.md`
with install and usage instructions, and a `LICENSE` file.

Rationale: Manifest validation proves the YAML parses. Only an install-run-remove
cycle proves the extension works.

### VIII. Semantic Versioning & Changelog

`extension.version` MUST follow `X.Y.Z` with no prefix and no pre-release suffix.
MAJOR for a removed or renamed command/alias, a removed hook event, or a raised
`requires.speckit_version` floor; MINOR for a new command, hook, or config key;
PATCH for prose, fixes, and non-behavioral changes. Every version bump MUST land a
matching `CHANGELOG.md` entry in the same change, and the GitHub release tag MUST be
`v{version}`.

Rationale: `.specify/extensions/.registry` pins installed versions and hashes.
Users upgrade based on what the version number promises.

### IX. English Artifacts, Native Conversation

Everything written to disk MUST be in English: `extension.yml`, command Markdown,
scripts and their comments, config templates, `README.md`, `CHANGELOG.md`,
`LICENSE`, specs, plans, tasks, this constitution, commit messages, pull request
titles and bodies, and code identifiers. Interactive conversation MUST use the
language the requester used in their message; switching the conversation language
never changes the language of a file.

Rationale: The audience for a published Spec Kit extension is the upstream catalog
and its global users, so artifacts must be readable by everyone. The audience for a
conversation is one person, so it should be in their language.

### X. Compressed Communication, Uncompressed Artifacts

Interactive conversation in this project uses the compressed style defined by the
vendored `caveman` skill (`.claude/skills/caveman/SKILL.md`), default intensity
`full`. Compression applies to prose addressed to a human and to nothing else.
Artifacts MUST be written in full, conventional prose: command Markdown, `README.md`,
`CHANGELOG.md`, config templates, script comments, specs, plans, tasks, commit
messages, and pull request bodies. Compression MUST also be dropped mid-conversation
for security warnings, irreversible-action confirmations, and any sequence where
omitted articles or conjunctions could reverse the meaning of an ordered step.

Rationale: Terse prose saves tokens for the one person reading the conversation.
A published extension is read by strangers, parsed by tooling, and reviewed years
later — it gets no such benefit and pays a real comprehension cost. Principle IX
governs which language artifacts use; this principle governs their register.

### XI. Hook Literacy Across Harnesses

Two distinct hook layers exist and MUST never be conflated: **Spec Kit lifecycle
hooks**, declared in `extension.yml` and aggregated into `.specify/extensions.yml`,
which invoke slash commands as agent prompts; and **harness hooks**, declared in a
harness's own configuration (for example `.claude/settings.json`,
`.codex/hooks.json`), which execute real shell processes and can block tool calls.

This project MUST maintain `docs/HOOKS.md` as an evidence-backed matrix of both
layers, recording for every documented harness: the config file path, the event
names, the payload contract, the exit-code and blocking semantics, and the matcher
syntax. An entry MAY be added only after being read from that harness's current
documentation or verified against a real config; recalled-from-memory contracts are
forbidden, and an unverified harness MUST be listed explicitly as unverified rather
than omitted or guessed.

An extension MUST NOT install, modify, or remove a harness hook without the user
explicitly requesting that specific change; suggesting a snippet the user installs
themselves is the supported path. Any harness hook this project authors or
recommends MUST declare an explicit timeout, quote all interpolated paths, use
project-local tooling rather than remote one-off package execution, exit zero when
not applicable, and confine its writes to paths the extension owns. Blocking hooks
MUST additionally document their exact failure mode in the extension README.

Rationale: Layer 1 is a suggestion the agent may act on; Layer 2 is code running on
someone's machine with their credentials, able to veto their tools. Treating the two
as interchangeable produces either hooks that never fire or hooks that break a user's
session in a way they cannot trace back to the extension.

### XII. Every Distribution Form, Verified

The `specify` CLI can install an extension in four distinct forms: a local directory
(`extension add --dev <path>`), a custom URL (`extension add <id> --from <url>`), a
catalog entry resolving to a downloadable ZIP, and bundling inside the CLI package
itself. This project MUST maintain `docs/PACKAGING.md` documenting all of them,
recording for each: the exact command and its options, the required package layout,
the resulting `.registry` `source` value, and the resulting on-disk project state.

The matrix MUST be evidence-backed and MUST name the `specify` version it was
verified against. Every entry MUST come from the CLI's own `--help` output, its
source, or an executed command — never from recall. Every CLI upgrade obliges a
re-verification pass, and any form that could not be re-verified MUST be marked as
unverified rather than silently carried forward.

An extension MUST be installable in every form it claims to support, and a release
MUST be proven in the **published** artifact, not only the working tree: the built
ZIP MUST be installed into a clean project via its release URL before the catalog
entry is submitted or updated. Any distribution form the extension does not support
MUST be stated as unsupported in its README.

Rationale: `--dev` succeeding proves the working tree is valid. It does not prove the
ZIP has the manifest at the right depth, that the release asset URL resolves, or that
the catalog entry's `download_url` points anywhere real — and those are the only
paths a stranger will ever use.

### XIII. Proactive Use of Installed Extensions

The extensions listed under "Installed Extension Baseline" are part of this
project's working method, not optional decoration. When a task matches a listed
trigger, the corresponding command MUST be offered or invoked without waiting for
the user to name it — an installed capability that goes unused is indistinguishable
from an uninstalled one.

Proactive invocation is bounded by three rules. First, read-only commands
(`critique`, `staff-review`, `onboard.*`) MAY be invoked directly; commands that
write outside their own directory, create branches, push, or open pull requests
(`ship.run`, `worktrees.create`, `worktrees.clean`) MUST be proposed and confirmed
before running. Second, an extension MUST NOT be invoked when its precondition is
absent — `worktrees.*` requires a git repository, `ship.run` requires a remote and a
clean tree — and the missing precondition MUST be stated rather than worked around.
Third, an extension's failure MUST NOT be silently absorbed: report what failed and
continue, never present a skipped step as completed.

Adding or removing an entry from the baseline is a constitution amendment. Third-
party extensions in the baseline are governed by their own authors, so their hooks
MAY be registered `optional: false`; Principle IV binds extensions **this project
authors**, and the divergence MUST be recorded in the baseline table rather than
silently tolerated.

Rationale: Installing seven extensions and then never routing work to them is worse
than not installing them — it adds surface area, hook noise, and supply-chain
exposure with no return.

### XIV. Trunk-Based Delivery Through Pull Requests

This project lives at `https://github.com/jonyfs/spec-kit-extension-llm-wiki-graphify`.
`main` is the trunk and is never committed to directly. Every change — feature,
fix, or documentation — lands through a pull request that targets `main` from a
short-lived branch, and every pull request MUST have all CI gates green before
merge. A branch whose CI is red is not ready for review.

When an implementation completes successfully, opening the pull request is part of
finishing the work, not a separate optional step. The installed `ship` extension
(`speckit.ship.run`, offered by the `after_implement` hook) is the supported path:
it runs pre-flight readiness checks, syncs the branch, generates the changelog
entry, verifies CI, and creates the PR. Its confirmations default to **no** by
design — a push and a PR creation are each authorized separately, and that
default MUST NOT be worked around.

A pull request MUST state what changed and why, link the Spec Kit artifacts it
implements when the work was spec-driven, and carry the constitution checklist from
`.github/pull_request_template.md` with every applicable row honestly checked. A
checkbox ticked without the corresponding check having been run is a false
statement about the change, and is worse than an unchecked box.

Rationale: The gates only mean something if they run before the code is trunk, and
a PR is the only artifact where a human, the CI, and the review extensions all look
at the same diff at the same time.

## Continuous Integration Gates

CI is defined in `.github/workflows/ci.yml` and runs on every push to `main`, every
pull request targeting `main`, and on manual dispatch. Four jobs, each mechanizing a
principle that is otherwise only aspirational:

| Job | Enforces | Implementation |
|---|---|---|
| Lint Markdown and YAML | Readability of hand-authored files | `yamllint`, `markdownlint-cli2` |
| Validate extension manifests | Principles I, II, IV, V, VIII | `scripts/validate-extension.py` |
| Guard template placeholders | Principle III | `scripts/check-placeholders.sh` |
| Install-test cycle | Principle VII | `scripts/install-test.sh` |

Two scoping rules keep the gates honest. Vendored third-party extensions under
`.specify/extensions/` are excluded from every job: they belong to their upstream
authors, and this repository does not get to fail its own build over someone else's
manifest. Machine-generated state under `.specify/` is likewise excluded from
linting, because a file the `specify` CLI rewrites on every install cannot be held
to this project's formatting.

A gate MUST NOT be weakened to make a red build green. Either the change is wrong,
or the gate's scope is wrong — and if it is the gate, the scope change is itself a
reviewable pull request explaining why, not a quiet edit bundled into unrelated work.

## Installed Extension Baseline

Verified with `specify extension list` against specify-cli 0.11.3. All six
third-party entries were installed via `specify extension add --from <release-zip>`
and are recorded in `.specify/extensions/.registry` with `"source": "local"`.

| Extension | Version | Use it when | Effect |
|---|---|---|---|
| `agent-context` (bundled) | 1.0.0 | After spec or plan changes, to refresh the agent context file | read-write, own markers |
| `critique` | 1.0.0 | A spec and plan exist and implementation has not started | read-only |
| `staff-review` | 1.0.0 | Implementation changes exist and need review against the spec | read-only |
| `onboard` | 2.1.0 | Someone needs a feature, dependency map, or SDD concept explained | read-only |
| `worktrees` | 1.3.2 | Parallel feature work needs isolation; **requires a git repository** | read-write, creates worktrees |
| `ship` | 1.0.0 | A feature is implemented and reviewed and is ready to release | read-write, branches/CI/PR |
| `speckit-superpowers-bridge` | 1.1.0 | Handing a `tasks.md` from Spec Kit design to Superpowers implementation | read-write, handoff state |

### Auto-executing hooks in this baseline

Six hooks are registered `optional: false` and run without prompting:

| Extension | Command | Event |
|---|---|---|
| `worktrees` | `speckit.worktrees.create` | `after_specify` |
| `speckit-superpowers-bridge` | `...bridge.guard` | four command events |
| `speckit-superpowers-bridge` | `...bridge.handoff` | one command event |

`worktrees.create` firing on `after_specify` in a directory that is not a git
repository will fail. Either initialize git before running `/speckit.specify`, or
disable the extension (`specify extension disable worktrees`). Do not silence the
failure.

## Vendored Third-Party Assets

Third-party skills, agents, commands, or scripts copied into this repository MUST be
vendored unmodified and accompanied by a `PROVENANCE.md` recording the upstream URL,
the exact source path, the pinned commit SHA, the vendoring date, and the license.
The upstream `LICENSE` file MUST be copied alongside the asset. Local edits to a
vendored file are forbidden; a needed change is either upstreamed or the asset is
forked under a distinct name with the fork documented. Updating a vendored asset
means re-copying from upstream and updating the recorded commit SHA in the same
change.

Rationale: Vendored files silently drift from upstream and lose their license trail.
A pinned SHA makes an update a diffable, auditable operation instead of guesswork.

## Upstream Compatibility Constraints

- The authoritative schema is upstream `extensions/EXTENSION-API-REFERENCE.md`
  (`schema_version: "1.0"`). This project tracks it; it does not extend it. Fields
  not defined upstream MUST NOT be invented in `extension.yml`.
- Supported hook events are the upstream lifecycle set only:
  `before_specify`/`after_specify`, `before_plan`/`after_plan`,
  `before_tasks`/`after_tasks`, `before_implement`/`after_implement`,
  `before_analyze`/`after_analyze`, and `before_constitution`/`after_constitution`.
  An unrecognized event name is a validation failure, not a no-op.
- Command files are Markdown with YAML frontmatter (`description`, optional `tools`,
  optional `scripts.sh`/`scripts.ps`) and receive user input via `$ARGUMENTS`.
- Extension configuration is read from
  `.specify/extensions/{extension-id}/{config-name}` and MUST tolerate a missing
  file when `required: false`.
- When upstream changes the schema, this template's own version MUST be bumped per
  Principle VIII and the drift documented in `CHANGELOG.md`.

## Development Workflow & Quality Gates

1. **Research first.** Before adding or changing template structure, read the
   current upstream `extensions/` guides. Copying a stale pattern is a defect.
2. **Spec-driven.** Non-trivial changes go through `/speckit.specify` →
   `/speckit.plan` → `/speckit.tasks` → `/speckit.implement`. The Constitution Check
   gate in `plan-template.md` is evaluated against the principles above.
3. **Validation gate.** Every change MUST leave `extension.yml` parseable, every
   referenced path resolvable, every command name matching Principle II, and every
   script pair complete per Principle V.
4. **Install gate.** Principle VII's install-run-remove cycle MUST pass before any
   release commit.
5. **Documentation gate.** A new command requires a README usage entry; a new config
   key requires a documented default in `config-template.yml`; a new hook requires
   its rationale in the README.
6. **Secrets.** No credentials, tokens, or personal URLs in any template, config,
   command, or script — placeholders only.

Commits follow `<type>: <description>` (`feat`, `fix`, `refactor`, `docs`, `test`,
`chore`, `perf`, `ci`).

## Governance

This constitution supersedes all other conventions in this repository. Where a
general guideline and a principle here conflict, the principle wins.

**Amendments** MUST be proposed as a pull request that states the principle added,
modified, or removed, the rationale, and the migration impact on extensions already
generated from this template. Amendments take effect on merge.

**Versioning** of this document follows semantic versioning: MAJOR for removing or
redefining a principle in a backward-incompatible way, MINOR for adding a principle
or materially expanding guidance, PATCH for clarifications and wording.

**Compliance review** is required on every pull request. Reviewers MUST verify each
principle explicitly; a PR that violates a principle without an approved amendment
MUST be blocked. Principle II violations and Principle VII gate failures are
non-negotiable blockers. Complexity beyond upstream schema MUST be justified in the
plan's Complexity Tracking section or removed.

Runtime development guidance lives in `CLAUDE.md` and the active feature's
`plan.md`; neither may contradict this constitution.

**Version**: 1.6.0 | **Ratified**: 2026-07-21 | **Last Amended**: 2026-07-21
