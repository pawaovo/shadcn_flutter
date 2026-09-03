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

### Fixed

- Honor disabled theme animation in the pinned shadcn layer so reduced-motion
  policy remains consistent (commit 80db77a, @pawaovo).
- Mark Search result and clear actions explicitly enabled for desktop
  accessibility bridges (product/main, @pawaovo).
- Preserve editable drafts when a clipboard cut fails, and draw P2 interface
  symbols as vectors to avoid missing glyphs in pinned fonts
  (product/main, @pawaovo).

## [0.1.0-dev.1]

### Added

- Establish the package seam, adaptive foundation, Loading State vertical
  slice, and its first deterministic catalog/test harness
  (product/main, @pawaovo).
