# Loading State vertical-slice evidence

Date: 2026-09-02 (Asia/Shanghai)
Branch: `product/main`
Toolchain: Flutter `3.47.0`, Dart `3.13.0`

This evidence describes the first local pass. It does not by itself satisfy the
G1 multi-platform gate.

## Interface and implementation

- Added the independent `beautiful_ai_ui` workspace package.
- Added package-owned semantic colors, radii, spacing, typography, shadows,
  motion policy, responsive breakpoints, and `BeautifulUiScope`.
- Kept all `shadcn_flutter` declarations behind the internal theme adapter.
- Implemented strongly typed Drive, Dots, Orbit, and Surfer variants.
- Made elapsed time caller-controlled; the package owns no demo timer.
- Excluded the upstream Surfer video and URL. The default is an original,
  code-rendered, zero-network fallback; callers may inject licensed media.
- Continuous pixel and shimmer animations stop when Flutter reports disabled
  animations or the package motion policy is reduced/none.
- Added an isolated upstream-core fix so `ShadcnLayer` also honors its existing
  `enableThemeAnimation` setting; focused core tests cover both paths.
- The loading status uses Flutter's status role; elapsed time is exposed through
  a separate non-live node so decisecond updates do not cause announcements.
- Caller-provided Surfer media remains mounted across motion-policy changes and
  is wrapped in `TickerMode`; the code-rendered fallback freezes completely.

## Local automated evidence

| Check | Result |
|---|---|
| `beautiful_ai_ui` strict analyze | Passed with 0 issues |
| Foundation, widget, motion, Semantics, contrast, and golden tests | Passed: 22 tests |
| Catalog strict analyze | Passed with 0 issues |
| Catalog widget, control, target-size, and compact-layout smoke | Passed: 3 tests |
| Full `shadcn_flutter` core regression | Passed: 571 tests, 0 failures |
| Catalog Web JavaScript release build | Passed |
| Catalog WebAssembly release build | Passed |
| macOS-host golden re-check without `--update-goldens` | Passed |

The test matrix includes breakpoint edges, 320px compact width, 200% text,
long content, four variants, elapsed-time boundaries, caller-owned media,
license-safe fallback, reduced motion, a live status node, light/dark
high-contrast guidance, and deterministic light/dark goldens with explicit test
fonts.

## Real-browser evidence

The release Web build was served from localhost and inspected in the Codex
in-app Chromium browser at:

- 390×844 compact;
- 768×1024 medium;
- 1440×900 expanded.

The Catalog changed from one to two columns without overflow. Theme cycling
changed system/dark to light, and motion cycling changed system to reduced;
the reduced mode froze the repeating pixel animation while elapsed text kept
updating. The browser console had no application error. The only warning was
that the simple localhost server did not provide COOP/COEP headers, so Skwasm
used its documented single-threaded fallback.

## Open evidence

- Linux canonical golden comparison must pass in CI; the initial PNGs were
  generated on the pinned macOS host and inspected manually.
- Android debug APK plus iOS, macOS, Windows, and Linux native builds are
  delegated to the new CI matrix because this machine lacks the required
  native toolchains.
- Real TalkBack, VoiceOver, Narrator, and Orca checks remain later release
  evidence.
- Inter and JetBrains Mono remain a tracked Foundation parity item; this slice
  uses the already bundled, licensed Geist/Geist Mono fallback behind semantic
  typography tokens.
