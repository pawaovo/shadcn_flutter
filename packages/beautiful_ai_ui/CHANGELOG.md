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

### Fixed

- Honor disabled theme animation in the pinned shadcn layer so reduced-motion
  policy remains consistent (commit 80db77a, @pawaovo).
- Mark Search result and clear actions explicitly enabled for desktop
  accessibility bridges (product/main, @pawaovo).

## [0.1.0-dev.1]

### Added

- Establish the package seam, adaptive foundation, Loading State vertical
  slice, and its first deterministic catalog/test harness
  (product/main, @pawaovo).
