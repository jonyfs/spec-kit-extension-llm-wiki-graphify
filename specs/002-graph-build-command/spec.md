# Feature Specification: Graph Build Command

**Feature Branch**: `feat/002-graph-build-command`

**Created**: 2026-07-22

**Status**: Draft

**Input**: User description: "A command `speckit.llm-wiki-graphify.build` that detects the graphify installation, invokes the construction (or incremental `--update`) of the project graph, and reports the result — failing loudly and naming the dependency when graphify is not present."

## User Scenarios & Testing *(mandatory)*

**Audience**: this ships as a **publicly maintained Spec Kit plugin**, installed by people
the author will never meet, into projects the author will never see. That single fact sets
the bar for everything below. A stranger cannot ask what a message meant, cannot infer that
a graph is partial, and cannot work around a broken dependency check by reading the source.
Every requirement about naming a missing dependency, stating what was not interpreted, and
keeping outcomes distinguishable exists because the reader is a stranger, not because the
author needs the reminder.

The user throughout is a **maintainer of a Spec Kit project** who has installed the
`llm-wiki-graphify` extension and wants a knowledge graph of their own project available
to the Spec Kit workflow. This feature is the foundation the rest of the extension rests
on: querying, path finding, and the wiki all require a graph to exist first.

### User Story 1 - Build a graph for a project that has none (Priority: P1)

A maintainer opens a project where no graph has ever been built. They run the build
command. The command confirms the knowledge-graph tool is available, reports what it is
about to examine and asks them to confirm, then builds the graph and tells them what was
produced — how many entities and relationships, where the output lives, and what they can
do next.

**Why this priority**: Nothing else in the extension functions without a graph. This is
the minimum viable slice: on its own it already delivers the artifact the maintainer came
for, and every other capability is an increment on top of it.

**Independent Test**: In a project where no graph has ever been built, run the build
command and confirm a graph is produced, a summary is reported, and the maintainer was
asked before the build started. Delivers a queryable graph with no other feature present.

**What this build covers**: the deterministic pass extracts **structure** — from code, and
from documents too. A Markdown heading becomes an entity with directly-established
provenance, the same as a function does. What the pass does **not** produce is the
*semantic* layer: concepts spanning documents, and the relationships a model would infer
between a requirement and the code implementing it. Those need a separate model-assisted
pass that belongs to the maintainer's own knowledge-graph tooling, and this command hands
off to it rather than performing it.

The report must state this precisely rather than reassuringly. "Your documents were not
read" would be false — their structure was. "Your documents were fully understood" would
also be false. A maintainer told the first version goes looking for their headings, finds
them, and then trusts the graph for semantic claims it cannot make.

**Acceptance Scenarios**:

1. **Given** a project with no existing graph and the knowledge-graph tool available,
   **When** the maintainer runs the build command and confirms the prompt,
   **Then** a graph is produced, and the report states the number of entities, the number
   of relationships broken down by evidence label, and the output location.
2. **Given** a project with no existing graph,
   **When** the maintainer runs the build command,
   **Then** the command states what will be examined and waits for confirmation before
   any build work begins.
3. **Given** a project with no existing graph,
   **When** the maintainer declines the confirmation,
   **Then** no build runs, no files are written, and the command reports that it stopped
   at the maintainer's request.
4. **Given** a completed build,
   **When** the maintainer inspects version control,
   **Then** no produced artifact is staged, tracked, or proposed for commit.
5. **Given** a completed build,
   **When** the maintainer inspects everything written during the run,
   **Then** every written path is either the directory the extension owns or the output
   directory the external tool owns, and the specification, plan, and task files are
   byte-for-byte unchanged.
6. **Given** a build in which one step fails while others succeed,
   **When** the run finishes,
   **Then** the failure is named in the report and the run is not presented as a success.
7. **Given** the same project on either supported operating system,
   **When** the maintainer runs the command,
   **Then** the outcome and the report are equivalent.
8. **Given** a project containing both code and prose documents,
   **When** a build completes,
   **Then** the graph contains entities extracted from both, and the report states that
   structure was extracted while no semantic relationships were inferred, naming the
   separate pass that produces those.
9. **Given** a completed build whose scope contained prose documents,
   **When** the report is rendered,
   **Then** the model-assisted pass is offered as an explicit next step, and declining it
   leaves the completed build intact and reported as successful.

---

### User Story 2 - Refresh a graph after the project changed (Priority: P2)

A maintainer who already has a graph has since written new code and docs. They run the
build command again and ask for a refresh. Rather than rebuilding everything, the command
re-examines only what changed and reports what moved — how many entities and
relationships were added, changed, or removed since the previous graph.

**Why this priority**: A graph that is expensive to refresh is a graph that goes stale,
and a stale graph is worse than none because it is consulted with misplaced confidence.
This makes the graph maintainable, but it is only reachable once P1 exists.

**Independent Test**: Build a graph, add a file with a new relationship, run the refresh,
and confirm the new entity appears in the graph and in the delta report while unchanged
parts of the graph are not rebuilt.

**Acceptance Scenarios**:

1. **Given** an existing graph and files changed since it was built,
   **When** the maintainer runs the refresh,
   **Then** the changed files are re-examined, the graph reflects them, and the report
   states what was added, changed, and removed.
2. **Given** an existing graph and no files changed since it was built,
   **When** the maintainer runs the refresh,
   **Then** the command reports that the graph is already current and makes no changes.
3. **Given** an existing graph,
   **When** the maintainer requests a full rebuild instead of a refresh,
   **Then** the whole project is re-examined and the previous graph is replaced.
4. **Given** an existing graph that a person has edited by hand,
   **When** the maintainer runs a refresh,
   **Then** the refresh proceeds from the sources and the hand edit is discarded, and the
   report states plainly that the produced artifacts are not a place to record
   corrections.
5. **Given** a build that was interrupted before it finished,
   **When** the maintainer runs the command again,
   **Then** the incomplete state is detected and reported, and a full build is started
   rather than a refresh from the incomplete graph.
6. **Given** a build already running for this project,
   **When** a second build is started,
   **Then** the second declines, names the run already in progress, and writes nothing.

---

### User Story 3 - Understand immediately why a build cannot run (Priority: P3)

A maintainer runs the build command on a machine where the knowledge-graph tool is not
installed, or where the project has nothing the tool can examine. Instead of a partial
result, an empty graph, or a confusing error from a lower layer, they get one clear
statement of what is missing and the exact step that resolves it.

**Why this priority**: An unclear dependency failure is the most likely first experience
for a new user, and the one most likely to end in the extension being uninstalled. It is
P3 only because P1 and P2 must exist for there to be a build to fail.

**Independent Test**: With the knowledge-graph tool absent from the environment, run the
build command and confirm it stops, names the missing dependency, gives the resolving
step, and produces no output directory and no graph.

**Acceptance Scenarios**:

1. **Given** the knowledge-graph tool is not installed,
   **When** the maintainer runs the build command,
   **Then** the command stops, names the missing dependency and the step that installs
   it, and no graph, no output directory, and no partial artifact is created.
2. **Given** the knowledge-graph tool is not installed,
   **When** the maintainer runs the build command,
   **Then** the command does not install anything on the maintainer's behalf.
3. **Given** an installed tool whose version is below the supported floor,
   **When** the maintainer runs the build command,
   **Then** the command stops and reports the version found alongside the version
   required.
4. **Given** a project directory containing nothing the tool can examine,
   **When** the maintainer runs the build command,
   **Then** the command reports "nothing to examine" as a distinct outcome from a
   successful build, and does not report success.
5. **Given** no graph has been built,
   **When** the maintainer uses any other capability of the extension,
   **Then** it states that no graph exists and offers to build one, and the workflow step
   the maintainer was performing is neither blocked nor interrupted by a build.
6. **Given** a workflow step where the build is offered automatically,
   **When** the maintainer declines the offer,
   **Then** the workflow step completes normally and no build runs.

---

### Edge Cases

- **The build is interrupted partway.** A cancelled or crashed build must leave either
  the previous graph intact or no graph at all — never a half-written graph reported as
  complete. A subsequent run must detect the incomplete state and start over rather than
  refreshing from it.
- **The project is very large.** Before starting, the command states the scale of what it
  will examine so the maintainer can decline rather than discover the cost midway.
- **Two builds are started at once.** The second must detect the first and decline rather
  than interleave writes into the same output.
- **The output location already exists but was not produced by a build** (a stray
  directory of the same name). The command must report the collision instead of
  overwriting.
- **The project contains files the maintainer does not want examined** (vendored
  dependencies, secrets, large binaries). The underlying tool offers no exclusion
  mechanism, so v1 controls what is read through the scope root alone. The command MUST
  state that no exclusions were applied rather than imply any were — a report claiming a
  directory was skipped when it was read is worse than having no exclusion feature at all.
- **Sensitive content.** The command must never transmit or write project content outside
  the project directory beyond what the underlying tool's own configured behavior does,
  and must state up front that unstructured content is interpreted by a model.
- **A relationship the tool could not establish confidently.** It must reach the report
  carrying its uncertainty, never rounded up to a fact.

## Requirements *(mandatory)*

### Functional Requirements

**Dependency handling**

- **FR-001**: The command MUST verify the external knowledge-graph tool is present and
  meets the supported version floor before any build work begins.
- **FR-002**: When the tool is absent or below the floor, the command MUST stop and report
  the missing dependency, the version found where applicable, the version required, and
  the exact step that resolves it.
- **FR-003**: The command MUST NOT install, upgrade, or otherwise modify the external tool
  on the maintainer's behalf.
- **FR-004**: The command MUST NOT produce a graph, an output directory, or any partial
  artifact when the dependency check fails.

**Building**

- **FR-005**: The command MUST state the scope it is about to examine — the root path, the
  file count, and any applied exclusions — and MUST obtain explicit confirmation before
  starting a build.
- **FR-006**: The command MUST NOT start a build without the maintainer having asked for
  one in this invocation; no lifecycle event, and no other command, may trigger a build on
  its own.
- **FR-007**: The command MUST support both a full build and an incremental refresh that
  re-examines only what changed since the previous build.
- **FR-008**: On a refresh with no changes detected, the command MUST report the graph as
  current and make no changes.
- **FR-009**: The command MUST delegate all graph construction to the external tool and
  MUST NOT implement its own extraction, clustering, or rendering.

**Reporting**

- **FR-010**: On success the command MUST report the entity count, the relationship count
  broken down by evidence label, the output location, and the elapsed time.
- **FR-011**: On a refresh the command MUST additionally report what was added, changed,
  and removed relative to the previous graph.
- **FR-012**: The command MUST preserve the external tool's evidence labels — directly
  established, model-inferred with a confidence, and flagged-as-uncertain — unchanged in
  every report, and MUST NOT collapse them into undifferentiated prose.
- **FR-013**: A run that finds nothing to examine MUST be reported as a distinct outcome
  from a successful build and MUST NOT be reported as success.
- **FR-013a**: Every report for a completed build MUST state, precisely, what the run
  produced and what it did not: that structure was extracted from both code and documents,
  that no semantic relationships were inferred between documents or between documents and
  code, and that the model-assisted pass is what produces those. It MUST also state that no
  exclusions were applied. A statement that is merely reassuring, or that implies documents
  were skipped entirely, does not satisfy this requirement.
- **FR-013b**: When a completed build's scope contained documents the deterministic pass
  did not interpret, the command MUST offer the model-assisted handoff as an explicit next
  step, naming the command that performs it. The offer is declinable and MUST NOT run
  automatically.
- **FR-014**: Every failure MUST be reported, never absorbed; a step that was skipped MUST
  NOT be presented as completed.

**Artifacts and boundaries**

- **FR-015**: The command MUST confine its own writes to the directory the extension owns
  and to the output directory the external tool owns.
- **FR-016**: The command MUST NOT read, write, or modify the feature specification, plan,
  or task files.
- **FR-017**: The command MUST NOT stage, commit, or push anything, and MUST ensure the
  produced artifacts are excluded from version control.
- **FR-018**: The command MUST NOT edit produced artifacts after the tool writes them; a
  correction is made at the source and the graph rebuilt.
- **FR-019**: An interrupted build MUST leave either the previous graph intact or no graph
  at all, and a subsequent run MUST detect the incomplete state rather than refresh from
  it.
- **FR-020**: A second concurrent build MUST detect the first and decline rather than
  write into the same output.

**Availability to the rest of the workflow**

- **FR-021**: The command MUST be available on both supported operating-system script
  environments with equivalent behavior.
- **FR-022**: Where the command is offered automatically at a workflow step, that offer
  MUST be opt-in, MUST carry a prompt and a description, and MUST be declinable without
  affecting the step it was offered at.
- **FR-023**: When no graph exists, any other extension capability MUST state that fact
  and offer to build one, and MUST NOT block the workflow or build unasked.

### Key Entities

- **Project graph**: The knowledge structure produced from the project's files.
  Regenerable at any time from its sources; owned by the external tool; never
  hand-corrected and never committed.
- **Entity**: A single thing the graph knows about — a function, a document, a concept.
- **Relationship**: A connection between two entities, always carrying the evidence label
  that says how it was established.
- **Evidence label**: The basis of a relationship — directly established from a source,
  inferred by a model with a stated confidence, or flagged as uncertain and awaiting human
  review. Travels with the relationship everywhere it is reported.
- **Build scope**: The root path and the exclusions that define what a build examines.
- **Build report**: The human-facing summary of a run — counts, evidence breakdown, delta
  where applicable, output location, elapsed time.

## Success Criteria *(mandatory)*

Each criterion below is stated so that it can be observed failing against a real baseline,
not only observed passing.

### Measurable Outcomes

- **SC-001**: With the knowledge-graph tool removed from the environment, 100% of build
  attempts stop with a message naming the missing dependency and its resolving step, and
  0% produce an output directory or a partial graph. *(Falsifiable: the same run with a
  naive implementation produces a lower-layer stack trace or an empty output directory.)*
- **SC-002**: A maintainer who has never run the command can go from a project with no
  graph to a completed graph, having read only the command's own output, in under 5
  minutes of their own attention — excluding time the build itself spends working.
- **SC-003**: On a project where fewer than 5% of files changed, a refresh completes in
  under 25% of the time the original full build took. *(Falsifiable: a refresh that
  silently performs a full rebuild fails this and is otherwise indistinguishable from a
  correct one.)*
- **SC-004**: 100% of relationships reported to the maintainer carry their evidence label,
  and 0% of model-inferred or uncertain relationships appear in any report without one.
- **SC-005**: Across all nine outcomes — built, already current, nothing to examine,
  declined, dependency missing, dependency below the supported version, another build
  already running, an interrupted previous build, and a tool failure — 100% are reported
  as distinct from one another, with no two producing the same message.
- **SC-009**: A person who has never seen this project can, from the command's output
  alone, correctly state what is in the graph and what is not — specifically, that their
  documents' structure is present and that no inferred relationships are. *(Falsifiable: ask
  someone unfamiliar with the feature to read a build report and answer the question; a
  report that omits the coverage statement produces a wrong answer, and the wrong answer is
  always "yes, it is in there".)*
- **SC-008**: 100% of completed builds state what was not interpreted. *(Falsifiable: a
  report that lists entity and relationship counts without the coverage statement fails
  this, and is otherwise indistinguishable from a complete graph.)*
- **SC-006**: After any number of builds and refreshes, 0 produced artifacts appear in
  version control status.
- **SC-007**: No build starts without an explicit request in that same invocation, across
  every workflow step where the command is offered — measured by running the full
  workflow start to finish and observing zero unrequested builds.

## Assumptions

- **The maintainer installs the knowledge-graph tool themselves.** The extension declares
  and verifies the dependency; it never provisions it. This follows from the governing
  principle that the tool is an external dependency, not something this extension owns.
- **Scope defaults to the project root.** A maintainer who wants a narrower scope
  configures it; asking on every run would be noise.
- **Only a local project is in scope for this feature.** The underlying tool can also
  ingest remote repositories and merge several sources into one graph; those forms are
  deferred until the local case is proven.
- **v1 ships the structural pass, deliberately.** It is local, free, fast, and requires no
  model; the semantic pass is none of those. Shipping the cheap layer first is the choice
  being made here, and the cost is that the graph carries only directly-established
  relationships until the maintainer runs the separate pass.

  This decision is sharper for a public plugin than for a private tool. An installer
  arrives expecting the graph the upstream tool advertises and gets its deterministic
  layer. That is acceptable because the report says exactly which layer, every time, and
  the command offers the handoff (FR-013b) — and unacceptable silently. Producing the
  semantic layer is a separate feature, not a deferred obligation of this one.
- **Exclusions are not available in v1.** The underlying tool exposes no exclusion option,
  so scope is controlled by the root alone.
- **The output location is the one the external tool uses by default.** The extension does
  not relocate it, because the tool's own subsequent invocations expect to find it there.
- **Interpreting unstructured content costs money and time.** The confirmation step exists
  because the maintainer is authorizing a real cost, not just a file operation.
- **Reports are read by a person, not parsed by a machine.** No machine-readable output
  format is required by this feature.
- **The graph never becomes an authority over the code.** Where the two disagree, the code
  is right and the graph is rebuilt. Downstream features inherit this and are not
  re-specified here.

## Out of Scope

- Querying the graph, finding paths between entities, and explaining an entity — each is
  its own feature, and each depends on this one.
- Generating or serving the browsable wiki.
- Remote repository ingestion and multi-source graph merging.
- Any persistent graph storage the extension itself owns.
- Embeddings and vector search.
- Any automatic, unrequested graph construction.
