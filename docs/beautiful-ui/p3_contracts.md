# P3 component contracts

Status: approved implementation contracts; implementation and release evidence
are tracked separately in [`parity_manifest.yaml`](./parity_manifest.yaml).
Date: 2026-09-03 (Asia/Shanghai).

These contracts resolve the product and platform questions behind the seven
`spike_then_public_composite` entries. They retain the pinned source's useful
interactions while defining a Flutter-native API, adaptive presentations, and
bounded workloads. Approval of a contract does not mark a component complete.

The source is `slev12397/beautiful-ui` at
`dd1ba4f323c29ef6c383b2dbf1d7100f2c26ccac`. Each source path below is embedded
in the corresponding `public/r/<registry-name>.json` file at that commit.
Package and dependency boundaries remain those in
[`architecture.md`](./architecture.md).

## Shared decisions

- The host supplies immutable business snapshots, stable IDs, accepted values,
  and callbacks. The package owns presentation state such as draft input,
  disclosure, focus, viewport position, and pending feedback.
- Async actions capture their owning identity and relevant input snapshot.
  A changed identity or invalidated snapshot prevents an obsolete completion
  from committing local state. Failures use `BeautifulUiScope.onFailure` and
  `BeautifulUiFailure`; pending actions de-duplicate repeated activation.
- Initial values seed local state at the documented identity boundary. They
  do not compete with controlled host values.
- Touch, pointer, keyboard, native selection, and Semantics must reach the
  same real operations. A visual drag or chart is supplemented by explicit
  controls and text where those are needed for equivalent access.
- Adaptive mode derives from available constraints. The defaults remain
  compact below 600dp, medium from 600 through 1023dp, and expanded from
  1024dp. A narrow navigation lane can request a presentation explicitly.
- Parent-owned state survives resize. Local selection, drafts, disclosure,
  search, and focus remain above responsive branches where possible.
- Demo data, timed AI simulations, browser-specific dependencies, network
  clients, file services, microphones, and authorization workflows do not
  enter the package. Hosts and the Catalog supply external behavior.
- Commercial Central Icons and source branding are excluded. New Flutter
  painters and the existing approved icon inventory provide visual controls;
  npm-only `glimm`, `liveline`, and `iconoir-react` are not dependencies.
- Workloads below are bounded validation targets, not measured frame-rate
  guarantees. Release/profile frame and memory evidence remains a separate
  gate. Any elapsed-time measurements are diagnostic; deterministic tests
  check correctness and bounded realization without flaky millisecond limits.

## Prompt Bar

Source: `components/primitives/PromptBar.tsx`.

**Ownership.** The host owns composer identity, available source/command/model
snapshots, the selected model, and send, attach, dictate, stop-dictation, and source
connection callbacks. The widget owns draft text, selected attachment
descriptors, suggestion navigation, and pending presentation. Attachment
selection and dictation return host-provided results; the library does not
request platform permissions or open device services itself. Async outcomes
are guarded by composer identity and the relevant draft snapshot.

**Retained experience.** Rounded and pill presentations can grow into a tall
multiline composer. `@` source suggestions, `/` command suggestions, a model
picker, removable attachments, dictation start/stop, and send remain actual controls.
Suggestions are realized lazily. Enter/Shift+Enter and software newline follow
the established composer contract, with active IME composition protected.

**Adaptive presentation.** Compact layouts wrap controls, keep composition and
the primary action visible, and respect safe-area/keyboard space. Secondary
options remain reachable through the component's menu/disclosure surface.
Resize preserves the draft and attachment selection.

**Bound and evidence.** Exercise 1,000 suggestion items and a 10,000-character
draft. Verify lazy realization, filtering and keyboard selection, long-text
layout, IME behavior, stale attachment/dictation/send outcomes, and state
preservation across constraints.

**Source changes.** The `glimm` rainbow shader, autoplay, fabricated files,
dictation text, and scripted send sequence are omitted. They demonstrate a
scenario rather than define a reusable external-action boundary; the
composer's state and controls remain.

## Diff Table

Source: `components/primitives/DiffTable.tsx`.

**Ownership.** The host supplies stable columns and row IDs with immutable
before/after value maps. Added, removed, modified, and unchanged meanings are
inferred from those snapshots. The widget owns proposed inclusion choices and
page state. `onApply` submits the selected change set to the host and exposes
pending/failure feedback without modifying host records.

**Retained experience.** Each changed row can be included or excluded before
application. Counts and the application action reflect that selection.
Unchanged records stay readable. Old/new and added/removed meanings are
explicit text and Semantics as well as visual treatments.

**Adaptive presentation.** Compact uses one change card per record; expanded
shows aligned before/after fields. Pagination bounds mounted records in both
modes. Inclusion state and reachable focus survive page and constraint changes.

**Bound and evidence.** Validate 500 records with three fields each. Default
page size is 20 and maximum page size is 100. Test inference, page bounds,
inclusion across pages, empty selections, pending application, stale snapshot
replacement, compact/expanded layouts, and bounded realized rows.

**Source changes.** The source's timed reveal and fixed removal/addition demo
become immediate caller-supplied diffs. Modified rows and field-level before/
after values make the same review decision usable for real host records.

## Records Table

Source: `components/primitives/RecordsTable.tsx` and
`app/beautifui/records-table.css`.

**Ownership.** Typed columns, property configuration, cells, rows, accepted
values, and run state belong to the host. Property configuration retains
type, tool, grounding, inputs, and prompt, with save, add, and run callbacks.
Search, sort, row selection, local property drafts, column pin/hide/width
preferences, detail disclosure, and viewport state belong to the widget.
Accepted configuration and run results only change when the host supplies
their next snapshot.

**Retained experience.** The component supports record selection, search and
sorting, column configuration, width adjustment, property addition, and
running an AI property. Cell state displays host-provided loading/results/
failures. It is a record and property workspace rather than a general
spreadsheet formula engine.

**Adaptive presentation.** Compact uses cards with record detail; expanded
uses a horizontally scrollable grid. Column controls remain accessible
without pointer-only resize handles. Cached sort/filter results feed lazy
viewport row realization. Hidden content leaves visible and Semantics trees.

**Bound and evidence.** Validate 1,000 rows and at most 20 columns. Exercise
sort/filter correctness, row selection across filtering, configuration drafts,
controlled save/add/run callbacks, narrow-screen details, column controls,
stable identity during resize, and lazy realization near the viewport.

**Source changes.** The fixed CRM schema and competitor-generation timers are
replaced by typed host snapshots. Database/network access, generated business
values, formulas, bulk cell editing, and arbitrary graph-like property
execution are outside this contract. The property/run controls remain useful
without silently simulating their result.

## Sidebar Nav

Source: `components/primitives/SidebarNav.tsx` and
`app/beautifui/sidebar-nav.css`.

**Ownership.** The host supplies workspace, primary destination, recent-item,
footer, and workspace-action snapshots plus selected IDs and activation
callbacks. The widget owns workspace/search disclosure, recent query,
navigation expansion, and focus. It does not own routing or create chats.

**Retained experience.** Workspace selection, new chat, primary destinations,
searchable recents, footer actions, and workspace actions remain available.
Selected identity derives from host values. Recent rows are realized lazily.

**Adaptive presentation.** Automatic presentation uses a compact drawer below
600dp, a rail from 600 through 1023dp, and an expanded sidebar from 1024dp.
An explicit override supports a narrow lane in a larger host layout. Default
expanded width is 288dp, capped by available width; rail width is 64dp and
bounded height defaults to 600dp. Search query and focus are preserved across
presentation changes.

**Bound and evidence.** Validate 1,000 recent items with lazy realization.
Test workspace and destination callbacks, selected Semantics, query filtering,
drawer/rail/expanded transitions, keyboard dismissal/focus restoration, and
empty/long/RTL labels.

**Source changes.** The browser portal and fixed source workspace/chat data
are replaced by native Flutter presentation and host snapshots. Commercial
Central Icons and source logos are excluded; source visual hierarchy and
navigation outcomes are retained with approved or newly drawn symbols.

## Flowchart

Source: `components/primitives/Flowchart.tsx`.

**Ownership.** A `workflowId` identifies a host-controlled complete graph
snapshot: typed DAG nodes, edges, positions, and condition fields/options.
Edits propose a complete replacement snapshot to the host. The widget owns
viewport and interaction presentation; host acceptance determines persisted
positions and conditions.

**Retained experience.** Nodes and measured connector anchors form a workflow
canvas. Condition options remain real controls. Expanded presentation offers
pan, 1–2× zoom, dragging, and keyboard movement. Explicit movement and
condition controls provide alternatives to dragging.

**Adaptive presentation.** Compact renders editable ordered steps with node,
condition, and connection meaning retained in text. It preserves workflow
editing while replacing the spatial canvas interaction where screen width
cannot support it. Expanded connector geometry follows measured node bounds.

**Bound and evidence.** Validate at most 24 nodes, 48 edges, eight condition
fields per node, and 32 options per field. Positions are bounded to 4,096
logical units and canvas extent to 8,192. Reject duplicate or missing IDs,
missing edge endpoints, and cycles. Test full-snapshot edits, condition
selection, drag/keyboard movement, connector geometry, pan/zoom bounds,
compact ordered steps, and host replacement during interaction.

**Source changes.** The fixed trigger/condition example becomes an explicit
DAG. Arbitrary graph scale, cyclic graphs, freehand edge creation, workflow
execution, and unbounded canvas positions are outside this contract. These
bounds keep interaction and accessibility behavior reviewable.

## Insight Cards

Source: `components/primitives/InsightCards.tsx`.

**Ownership.** The host owns typed comparison, anomaly, and allocation chart
data, selected carousel page, metric, and allocation segment. Selection
callbacks propose changes. The widget owns inspected point and full-data
disclosure. Chart values and their labels are supplied as real snapshots.

**Retained experience.** Carousel navigation, comparison series, anomaly
metrics, allocation segments, and point inspection remain interactive.
Private vector painters use dashed/marker distinctions as well as color.
Every chart has a readable summary and a full textual data-table alternative.

**Adaptive presentation.** Compact stacks prose and chart; expanded can place
them side by side. Point/metric/segment inspection has keyboard and touch
controls. Nonvisible carousel content does not stay in traversal.

**Bound and evidence.** Validate at most 32 pages, four series, 512 points,
eight metrics, and 12 segments in the relevant chart. Test page ownership,
metric/segment callbacks, point inspection, complete textual data access,
empty/single-point/constant-value data, non-color distinctions, RTL, and
bounded point rendering.

**Source changes.** `liveline`, autoplay, fabricated time-series motion,
mount-time timestamps, and browser canvas behavior are replaced by deterministic
Flutter vector rendering of supplied values. No business inference or data
generation occurs inside the chart.

## Selection Actions

Source: `components/primitives/SelectionActions.tsx`.

**Ownership.** The host owns plain document text and `documentId`. Selection
uses a precise UTF-16 range and typed action, request, and edit snapshots.
`FutureOr<String> onRequest` supplies replacement or explanation text;
`FutureOr<void> onApply` lets the host accept an edit. Accepted edit data
includes `request.baseText`, `request.selection`, `request.selectedText`, and
`replacement` so the host can verify the document version before application.
The edit's `updatedText` helper computes the accepted replacement against that
exact base. `initialSelection` is only an optional seed.

The widget owns the current selected range, custom instruction, more-actions
disclosure, pending/result/retry state, and keep/discard presentation.
Document identity and meaningful text/range changes invalidate obsolete async
UI results. Clipboard operations use the existing guarded selection boundary.

**Retained experience.** Real native Flutter read-only text selection opens
quick actions anchored to that selection. Users can choose a predefined
operation or custom instruction, inspect returned text, retry, keep, or
discard. A responsive in-flow preview panel keeps the same actions reachable
with touch and keyboard. Applying an edit delegates to the host.

**Adaptive presentation.** Native gestures, selection handles, and clipboard
behavior are retained for the platform. The anchored toolbar is supplemented
by the in-flow panel when the available viewport or input method makes an
anchored surface insufficient. A bounded editor viewport contains long text.

**Bound and evidence.** Validate a 20,000-character plain-text document. Test
actual native selection, UTF-16 boundaries, clipboard guarding, action request
contents, retry/keep/discard, host application, and stale request/application
outcomes after identity/text/range changes. Test keyboard and touch access
through both toolbar and panel. Profile/release selection frame claims remain
open until measured on required platforms.

**Source changes.** The fixed example selection, canned rewrite, automatic
thinking/streaming timers, and `iconoir-react` controls are replaced by real
selection and host callbacks. Rich-text editing, document persistence,
synthetic streaming, and an AI backend are outside this plain-text contract.

## Evidence and completion

Implementation must be accompanied by public API documentation, Catalog
scenarios, widget/Semantics coverage, representative light/dark goldens, source
provenance, and the platform checks in
[`support_matrix.md`](./support_matrix.md). High contrast, text scaling,
localization/RTL, reduced motion, and resize preservation apply to every
component, not only those with a custom painter.

Real assistive-technology and physical-device checks, accepted canonical
goldens, required remote builds/journeys, and profile/release performance
evidence remain independent release gates. A passing workload widget test
proves a deterministic behavior or realization bound; it does not establish
frame time, memory usage, or screen-reader behavior on a device.
