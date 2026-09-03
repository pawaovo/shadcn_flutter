# Final-source macOS profile attempt — 2026-09-03

**Status: failed during native-window preparation; final-source profile
resampling remains incomplete.** This was the single authorized attempt for
run `20260903T113737Z`. No automatic retry was made.

The official, unchanged profile script successfully built and launched the
profile application from revision
`c2bde85dd5da7c33b0f7881234ae312f3be1826c`. Its VM service connected, but the
actual native window stayed at **800×600dp** for the full **120-second** setup
window. It never reached the required **1120×720dp** minimum and never emitted
`P3_PROFILE_VIEWPORT_READY`.

Consequently, **zero workload bodies, zero engine frame samples and zero RSS
samples were recorded**. There are no performance values to accept from this
attempt. The SDK driver printed `All tests passed` after the suite setup failed
and returned `0`; the existing finalizer independently checked the required
seven completed scenarios, rejected the empty list, and wrote final
`status: failed`. The final script exit status is **1**. This demonstrates why
driver success alone is insufficient for this protocol.

## Source and working-tree verification

The working tree was **not clean**: documentation and evidence changes were
present and are recorded in `summary.json` as the original
`source_worktree_status`. That state is not relabeled as clean.

Every file in `source_hashes.json` was compared byte-for-byte against the CI
revision above: library/Catalog Dart sources, integration targets and drivers,
the official profile script, dependency/toolchain pins, and the macOS native
window configuration and Debug/Profile entitlement all matched the commit.
The manifest digest is
`4c4cf5d6606596f8f7ce45f07d4e37a0309aad1d60f42ea7d50d0af850390dac`.
Use the actual digest in `source_hashes.json` as authoritative.

No app, harness, component, test or window-management code was changed for this
attempt. No local GUI action was performed by the performance agent. Window
preparation was delegated to the root task; this record establishes only the
measured 800×600dp timeout, not a speculative cause of the UI-control problem.

## Files

- `summary.json`: failed stage, actual viewport, exact source/working state,
  zero sample counts and both exit results.
- `source_hashes.json`: actual and committed SHA-256 values for the checked
  source scope, with per-file equality results.
- `artifact_manifest.json`: checksums for the raw report, log, command and
  exit files, plus the built runner/AOT binaries.

The original files remain under
`packages/beautiful_ai_ui_catalog/build/p3-profile/20260903T113737Z/`.
There is no renderer verification or frame/RSS measurement for this attempt;
`--enable-impeller` records a request only.

The earlier successful run `20260903T080855Z` and its
[historical evidence](../2026-09-03-macos-profile/README.md) are preserved
unchanged. They remain a baseline for an earlier source snapshot and do not
replace a successful capture of the final source. The parent
[`index.json`](../index.json) keeps the final-source requirement explicitly
pending.

## Subsequent clarification and retry

The root task confirmed that the 800×600 native waiting window was visible
and exposed an AX zoom action, but that preparation action was not executed
within the 120-second limit while another investigation was in progress. This
failure is not evidence of a locked machine or an inoperable window. A separately
authorized attempt `20260903T114308Z` subsequently succeeded; see the independent
[final-source record](../2026-09-03-macos-profile-final/README.md). Original raw
files from this failed attempt remain unchanged.
