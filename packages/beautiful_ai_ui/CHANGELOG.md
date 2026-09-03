# Changelog

All notable changes to this package will be documented in this file.

## [Unreleased]

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
  this successful baseline distinct from the final-source resample pending
  after the last palette and muted-ticker fixes
  (product/main, @pawaovo).
- Add exact inherited font/icon and transitive-media inventories, complete
  package notices, reproducible asset checks, and a real Flutter
  `LicenseRegistry` probe; verify JavaScript, Wasm, and macOS release artifacts
  (product/main, @pawaovo).
- Add supplemental static accessibility review covering 49 images across all
  twenty modules and expanded native/browser CI configuration; remote results
  remain separate from job configuration (product/main, @pawaovo).

### Fixed

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
  canvas; the integrated library suite now passes 526 tests
  (product/main, @pawaovo).

## [0.1.0-dev.1]

### Added

- Establish the package seam, adaptive foundation, Loading State vertical
  slice, and its first deterministic catalog/test harness
  (product/main, @pawaovo).
