# Changelog

All notable changes to this package will be documented in this file.

## [Unreleased]

Local acceptance on 2026-09-04 passes 629 library tests and strict analysis.
The supplemental visual review covers 78 P1/P2 images and 127 P3 images;
1,008 P3 layout/interaction combinations passed. Real device, screen-reader,
current cloud input and performance-budget acceptance are recorded separately.

Earlier complete automated baseline: [CI 33748054504](https://github.com/pawaovo/shadcn_flutter/actions/runs/33748054504)
passed 12/12 jobs for code `c2bde85dd5da7c33b0f7881234ae312f3be1826c`,
including the actual iOS driver and hosted-consumer gate. Library/Catalog/core
tests passed 528/26/571. Final-source macOS profiling and the targeted Safari
Flowchart review are complete. Physical/AT/full-matrix and performance-budget
acceptance remain separate; this is validation, not a package publication.

### Added

- Add a package-owned theme, responsive, motion, accessibility, and shadcn
  implementation seam (product/main, @pawaovo).
- Add the four-variant Loading State, multi-platform Catalog, deterministic
  tests, and light/dark goldens (product/main, @pawaovo).
- Add Thinking, Context Cards, Recommendation Card, Search, and Code Block as
  strongly typed, adaptive P1 modules with pointer, keyboard, Semantics,
  reduced-motion, RTL, and 200% text coverage (product/main, @pawaovo).
- Add normalized recoverable failure reporting at `BeautifulUiScope`, plus
  real Chrome, Android emulator, and Linux/Xvfb Catalog journeys
  (product/main, @pawaovo).
- Add Streaming Text with exact Unicode snapshots, stable source citations,
  selectable content, copy feedback, retry, and completion actions; keep the
  stream renderer internal (product/main, @pawaovo).
- Add the question-based Approval Card, Tool Chips, and capsules/list Task
  Rows with stable identity, accessible disclosure, and host-owned execution
  and submission (product/main, @pawaovo).
- Add Chat with host-owned messages and send/stop actions, IME-safe multiline
  drafts, response/conversation isolation, and preserved reading position
  (product/main, @pawaovo).
- Add adaptive Filter Table status filtering and a controlled Fine-tune Card
  with bounded numeric entry, touch/keyboard/pointer/assistive adjustment,
  layout selection, and inline type choices (product/main, @pawaovo).
- Add P2 Catalog scenarios, dedicated widget/Semantics tests, shared journey
  coverage, and normalized `approval`, `taskRetry`, `chat`, and `streaming`
  failure operations (product/main, @pawaovo).
- Add Flutter text-selection handles and localized clipboard menus with
  shared touch, keyboard, and Semantics action handling; invalidate delayed
  clipboard edits when a conversation or approval question is replaced
  (product/main, @pawaovo).
- Add rounded/pill Prompt Bar with lazy source/command suggestions, controlled
  models, local attachments, and guarded host send/file/connection/dictation
  actions (product/main, @pawaovo).
- Add paginated Diff Table with exact before/after records and asynchronous
  application of included changes; add lazy Records Table with typed property
  configuration, search/sort/selection, column controls, and host save/add/run
  actions (product/main, @pawaovo).
- Add adaptive Sidebar Nav with workspace selection, lazy searchable recents,
  drawer/rail/expanded presentations, and host-owned navigation
  (product/main, @pawaovo).
- Add a bounded DAG Flowchart with measured connectors, controlled conditions
  and node edits, canvas pan/zoom/drag/keyboard movement, and compact editable
  ordered steps (product/main, @pawaovo).
- Add controlled Insight Cards with comparison/anomaly/allocation charts,
  keyboard/touch point inspection, vector distinctions beyond color, and
  full textual data disclosure (product/main, @pawaovo).
- Add Selection Actions with real native UTF-16 selection, guarded anchored
  toolbar, custom requests, replacement/explanation preview, and explicit
  host application through typed edit snapshots (product/main, @pawaovo).
- Add P3 component contracts, Catalog scenarios, workload fixtures, source
  provenance, and `prompt`, `diff`, `records`, and `selection` failure
  operations; keep release acceptance separate from implementation coverage
  (product/main, @pawaovo).
- Add a finalized macOS profile harness and evidence for all seven P3
  workloads, including independent engine frame samples, process RSS,
  measured viewport/renderer, and explicit budget/platform limitations. Keep
  the historical baseline distinct from the completed final-source capture
  after the palette, muted-ticker and hosted-adapter fixes
  (product/main, @pawaovo).
- Add exact inherited font/icon and transitive-media inventories, complete
  package notices, reproducible asset checks, and a real Flutter
  `LicenseRegistry` probe; verify JavaScript, Wasm, and macOS release artifacts
  (product/main, @pawaovo).
- Add supplemental static accessibility review covering 49 images across all
  twenty modules and expanded native/browser CI configuration; remote results
  remain separate from job configuration (product/main, @pawaovo).

- Complete final-source macOS profile run `20260903T114308Z`: seven workloads,
  4,495 frames/478 RSS samples, matched runtime/build inputs and successful
  teardown/driver/finalizer. Preserve the failed preparation attempt and older
  baseline, with budgets and other-platform acceptance still open
  (product/main, @pawaovo).
- Accept the targeted Safari light/dark/light reduced-motion Flowchart color
  regression from three independent image/AX checks; retain full-browser,
  input/AT and temporal/performance limitations (product/main, @pawaovo).

### Fixed

- Preserve desktop Prompt focus when model, source and attachment controls are
  used by keeping its editor and adjacent controls in the same tap region.
- Add held-pointer feedback and cancellation/disable cleanup to shared actions,
  Sidebar controls, Flowchart node headers and Records selection controls.
- Keep approval page numbers, change counts and filter ratios correctly ordered
  in RTL; keep native Arabic text-selection highlights within the selected text.
- Bound hidden/long Thinking animations; cache Prompt/Search text measurement;
  lazily render large Search and Insight datasets while preserving keyboard,
  selection and complete data access.
- Preserve Records row layout on unchanged result order and reuse unrelated
  column headers without losing host updates, resizing, theme or RTL behavior.

- Honor disabled theme animation in the pinned shadcn layer so reduced-motion
  policy remains consistent (commit 80db77a, @pawaovo).
- Mark Search result and clear actions explicitly enabled for desktop
  accessibility bridges (product/main, @pawaovo).
- Preserve editable drafts when a clipboard cut fails, and draw P2 interface
  symbols as vectors to avoid missing glyphs in pinned fonts
  (product/main, @pawaovo).
- Choose contrasting foregrounds for filled shared actions and provide a
  distinct selected fill/border across consuming components
  (product/main, @pawaovo).
- Draw Approval selected/submitted checks with native paths and allow the
  compact Sidebar trigger to grow at large text scales
  (product/main, @pawaovo).
- Expose native slider flags, enabled state, values, and adjustment actions
  for Fine-tune numeric controls and Insight point inspection
  (product/main, @pawaovo).
- Strengthen normal placeholder/metadata text with `inkSubtle` values
  `#66696f`/`#9c9fa5`; use light `accentInk` `#0067cb` to reach 4.925:1 on
  `accentTint`. Four palette regressions preserve the tested 4.5:1 text
  threshold without changing the graphic accent color (product/main, @pawaovo).
- Make shared action color updates immediate when ancestor tickers are muted,
  fixing stale dark backgrounds with new light-theme text inside a
  reduced-motion Flowchart. Three paint regressions include a real 1,200dp
  canvas; the integrated library suite now passes 528 tests
  (product/main, @pawaovo).
- Carry the complete verified dependency asset notices inside the separately
  publishable `beautiful_ai_ui/NOTICES`, preserving its original BSD and
  Beautiful UI MIT license blocks. Audit both package notice carriers so
  hosted consumers do not depend on this fork's sibling `NOTICES` file
  (product/main, @pawaovo).
- Preserve atomic inherited themes with the unmodified hosted
  `shadcn_flutter 0.0.54` through the package-private adapter. An isolated consumer verifies
  12 immediate/timed theme, state, draft, selection and focus observations,
  with all 13 complete generated notice texts delivered independently
  (product/main, @pawaovo).
- Accept eight reviewed Linux component golden candidates from run
  `33736546039`; the hosted-adapter change preserves all reviewed image
  pixels. Keep the first twelve-job CI result, iOS launch remediation, and
  final-source profile/Safari acceptance boundaries explicit
  (product/main, @pawaovo).
- Verify bounded PID discovery, real iOS driver completion, strict journey
  setup/teardown and termination in final CI. Retain one journey versus
  suite-hook event counts and the earlier failed attempts accurately
  (product/main, @pawaovo).

## [0.1.0-dev.1]

### Added

- Establish the package seam, adaptive foundation, Loading State vertical
  slice, and its first deterministic catalog/test harness
  (product/main, @pawaovo).
