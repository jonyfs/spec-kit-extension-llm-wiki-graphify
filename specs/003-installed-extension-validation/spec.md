# Feature Specification: Installed Extension Validation

**Feature Branch**: `feat/003-installed-extension-validation`

**Created**: 2026-07-22

**Status**: Draft

**Input**: User description: "Create tests that validate whether this extension is working
correctly" — scoped, after discussion, to end-to-end validation of the **installed**
extension: install into a real Spec Kit project, execute the registered command and the
hook, validate configuration handling, remove, and confirm nothing was left behind.

## User Scenarios & Testing *(mandatory)*

**Audience**: the maintainer of this publicly distributed plugin, and the contributor who
changes it next. Neither can see the projects it is installed into. The only thing standing
between a broken release and a stranger's project is whether this validation ran.

**What already exists, and why it is not enough**: the feature-002 suites make 38 bash and
26 PowerShell assertions against `graph-build.sh` and `graph-build.ps1`. They are thorough
about the scripts and blind to everything around them. Nothing currently executes
`commands/build.md`, registers the `after_specify` hook, reads a `config.yml`, or observes
what the `specify` CLI does with the manifest. A package can pass every existing gate and
still fail on first contact with a real project — which is precisely what Constitution
Principle VII was written to prevent, and precisely the gate still marked unmet.

### User Story 1 - Prove the package survives an install cycle (Priority: P1)

A maintainer about to tag a release runs one command. It installs the extension into a
throwaway Spec Kit project, confirms the CLI registered what the manifest promised,
exercises the command, removes the extension, and confirms the project is back to its prior
state. A single verdict at the end: safe to release, or not.

**Why this priority**: This is the gate the constitution already requires and that nothing
currently satisfies. Without it, every release rests on the assumption that a valid manifest
implies a working install — the assumption Principle VII exists to reject.

**Independent Test**: Run the validation against the current package in a clean checkout and
confirm it reports success; then break the manifest deliberately and confirm it reports
failure naming the break.

**Acceptance Scenarios**:

1. **Given** a clean Spec Kit project and the built package,
   **When** the validation runs,
   **Then** the extension installs, appears in the CLI's own listing, and every command the
   manifest declares is registered under the name the manifest declares.
2. **Given** an installed extension,
   **When** the validation removes it,
   **Then** the CLI reports removal, the extension no longer appears in the listing, and no
   file the extension created remains outside the CLI's own backup location.
3. **Given** a package whose manifest names a command file that does not exist,
   **When** the validation runs,
   **Then** it fails, names the missing file, and does not report a successful install.
4. **Given** a validation run that fails at any step,
   **When** the run ends,
   **Then** the throwaway project is cleaned up regardless, and the failure names the step
   that failed rather than the last thing printed.

---

### User Story 2 - Prove the command and hook actually execute (Priority: P2)

The validation does more than install: it invokes the registered command against a fixture
project and checks the observable results — a graph produced, a report carrying the coverage
statement and the evidence breakdown, and the exit code the contract specifies. It also
confirms the `after_specify` hook is registered as declinable and that declining it changes
nothing.

**Why this priority**: An install that was never exercised proves the YAML parses. Principle
VII requires every declared command and hook to run at least once, and that requirement is
the difference between "the package is well-formed" and "the package works".

**Independent Test**: With the extension installed, invoke the command against the code
fixture and confirm a graph appears with the expected counts; separately, confirm the hook
appears in the aggregated hook configuration as `optional: true`.

**Acceptance Scenarios**:

1. **Given** the extension installed in a project containing code,
   **When** the registered command is invoked with confirmation,
   **Then** a graph is produced and the output carries the entity count, the relationship
   count, and the evidence breakdown with labels verbatim.
2. **Given** the extension installed,
   **When** the aggregated hook configuration is read,
   **Then** the `after_specify` entry is present, is `optional: true`, and carries a
   non-empty prompt and description.
3. **Given** the extension installed and the hook offered,
   **When** the offer is declined,
   **Then** no graph is built and the workflow step the hook was attached to is unaffected.
4. **Given** the extension installed and graphify absent from the environment,
   **When** the registered command is invoked,
   **Then** it reports the missing dependency and produces no graph, exactly as the script
   does in isolation.

---

### User Story 3 - Prove configuration is honoured and its absence is safe (Priority: P3)

The validation checks both configuration states that matter: no config file at all, and a
config file that changes behaviour. Absence must be silent and defaulted; presence must
actually take effect.

**Why this priority**: The manifest declares the config `required: false`, which is a
promise that a missing file is not an error. Nothing currently tests that promise, and a
config that is read but ignored is indistinguishable from one that works until someone
depends on it.

**Independent Test**: Install with no config file and confirm the command runs on defaults;
install a config narrowing the scope root and confirm the build examines only that subtree.

**Acceptance Scenarios**:

1. **Given** the extension installed and no `config.yml` present,
   **When** the command runs,
   **Then** it proceeds on documented defaults without warning about the missing file.
2. **Given** a `config.yml` setting the scope root to a subdirectory,
   **When** the command runs,
   **Then** the graph covers only that subdirectory and the reported root matches it.
3. **Given** a `config.yml` setting a version floor above the installed graphify,
   **When** the command runs,
   **Then** it stops with the dependency-too-old outcome, proving the configured value was
   read rather than the default.
4. **Given** a `config.yml` that is malformed,
   **When** the command runs,
   **Then** it reports the file as unreadable and stops, rather than silently falling back
   to defaults and behaving in a way the maintainer did not configure.

---

### Edge Cases

- **The `specify` CLI is not installed.** The validation reports that as a distinct, unmet
  prerequisite — never as a passing run, and never as a failure of the package.
- **graphify is not installed.** The dependency-failure scenarios still run; the
  build-success scenarios are reported as **skipped**, never as passed. A suite that
  silently reduces its own coverage on a thin machine is how a green result stops meaning
  anything.
- **The CLI changes its output format.** The validation reads structured output where one
  exists, and where it must parse human-readable text, it fails loudly on an unrecognised
  format rather than concluding the extension is absent.
- **A previous run left the throwaway project behind.** Cleanup happens on every exit path,
  including interruption, and a stale project from an earlier crash is removed rather than
  reused.
- **The validation is run twice concurrently.** Each run uses its own throwaway project, so
  two runs cannot interfere.
- **The extension is already installed in the developer's own project.** The validation
  never touches it; it operates only inside its own throwaway project.

## Requirements *(mandatory)*

### Functional Requirements

**Install cycle**

- **FR-001**: The validation MUST create a throwaway Spec Kit project, install the package
  into it, and remove it, without ever writing to the developer's own project.
- **FR-002**: The validation MUST confirm that every command declared in the manifest is
  registered by the CLI under exactly the declared name.
- **FR-003**: The validation MUST confirm that removal leaves no extension-created file
  behind outside the CLI's own backup location.
- **FR-004**: The validation MUST clean up the throwaway project on every exit path,
  including failure and interruption.

**Execution**

- **FR-005**: The validation MUST invoke every declared command at least once and check its
  observable result, not merely that it was invoked.
- **FR-006**: The validation MUST confirm every declared hook is registered with the
  optionality, prompt, and description the manifest declares.
- **FR-007**: The validation MUST confirm that declining an offered hook results in no build
  and no change to the step it was attached to.

**Configuration**

- **FR-008**: The validation MUST cover a missing config file, a config file that changes
  behaviour, and a malformed config file, and MUST assert a different observable result for
  each.
- **FR-009**: A configured value MUST be proven to take effect by an observable difference,
  never by the absence of an error.

**Honesty of the result**

- **FR-010**: A scenario that cannot run because a prerequisite is absent MUST be reported
  as skipped, and MUST NOT count toward a passing result.
- **FR-011**: The validation MUST report which scenarios ran, which were skipped and why,
  and which failed — never a bare pass or fail.
- **FR-012**: Every assertion MUST be demonstrated failing against a deliberately broken
  package before it is trusted, and the broken-package fixtures MUST be part of this
  feature.
- **FR-013**: The validation MUST fail if the package would install but the extension does
  not function — a distinction the existing manifest validator cannot make.

**Integration**

- **FR-014**: The validation MUST run in CI on every pull request, on both a Linux and a
  Windows runner.
- **FR-015**: The validation MUST be runnable locally with a single command and no
  arguments.

### Key Entities

- **Throwaway project**: A temporary Spec Kit project created for one validation run and
  destroyed with it. Never the developer's own project.
- **Package under test**: The `extension/` directory, or a built archive of it.
- **Broken-package fixture**: A deliberately invalid copy used to prove an assertion can
  fail. Without these, a passing validation proves only that nothing threw.
- **Scenario result**: One of passed, failed, or skipped-with-reason. Three states, because
  collapsing skipped into passed is how coverage silently disappears.

## Success Criteria *(mandatory)*

- **SC-001**: 100% of manifest-declared commands and hooks are executed at least once during
  a validation run. *(Falsifiable: add a second command to the manifest without extending
  the validation, and the run must fail rather than quietly cover one of two.)*
- **SC-002**: Every assertion has been observed failing against a broken-package fixture.
  *(Falsifiable: an assertion that passes against both the correct and the broken package is
  not an assertion.)*
- **SC-003**: A maintainer can go from a clean checkout to a release verdict with one command
  and no arguments, in under 5 minutes of wall-clock time.
- **SC-004**: 0 validation runs write to any path outside the throwaway project.
  *(Falsifiable: run with the developer's project under version control and confirm the
  working tree is unchanged afterwards.)*
- **SC-005**: When graphify is absent, the run reports the affected scenarios as skipped and
  the overall result as incomplete — never as passed.
- **SC-006**: Constitution Principle VII can be marked satisfied on the strength of this
  validation alone, without appeal to any manual step.

## Assumptions

- **The `specify` CLI is available in CI and on the maintainer's machine.** It is already a
  dependency of the existing install-test gate.
- **The validation targets the local-directory install form.** The archive and catalog forms
  belong to Principle XII and are proven at release time against the published artifact, not
  here.
- **The throwaway project is created by the CLI itself** rather than hand-assembled, so the
  validation tests against a project shaped the way real ones are.
- **This feature adds no capability to the extension.** It is entirely verification, and it
  changes no file under `extension/`.

## Out of Scope

- Testing graphify itself. Its behaviour is verified where this project depends on it, and
  nowhere else.
- The archive and catalog distribution forms, which are release-time activities.
- Performance measurement — feature 002's SC-003 covers that ground.
- Replacing the feature-002 script suites. This validates the layer above them; both are
  needed, and neither subsumes the other.
