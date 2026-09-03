# Catalog changelog

## Unreleased

Final automated code validation: `c2bde85dd5da7c33b0f7881234ae312f3be1826c`
passed all 12 jobs in CI `33748054504`, attempt 1. The actual iOS driver
completed successfully (exit 0, 50.234s), with one whole journey and suite
setup/teardown; the hosted-consumer gate also passed. Earlier run records below
are history. Source-matched macOS profile run `20260903T114308Z` and the
three-capture targeted Safari Flowchart review are now accepted; broader
physical/AT/matrix and budget gates remain open.

- Expose all twenty Gallery components through explicit local host state and
  a shared integration journey. Keep Chat response completion under an
  explicit action so Send/Stop demonstrations are deterministic.
- Restrict `ENABLE_WEB_SEMANTICS` to Web. Ordinary native runs use the
  platform accessibility lifecycle; the macOS AX comparison and complete
  native journey have passed.
- Add native macOS/iOS simulator/Windows journey steps and dedicated
  Firefox/Edge jobs to the twelve-job CI configuration. The first run
  `33736546039` records nine successful jobs, two failures and one skip;
  its exact outcomes remain historical evidence.
- Add a separate opt-in P3 native profile harness with source/artifact hashes,
  independent frame data, RSS samples, renderer/viewport evidence, and an
  explicit final driver/teardown result. Historical macOS baseline
  `20260903T080855Z` completes all seven workloads. Final-source resampling
  is now complete in independent run `20260903T114308Z`; the earlier lock
  delay and zero-sample preparation failure remain historical, and no
  unagreed performance budget is asserted.
- Replace template launcher/Web artwork with registered original project
  artwork and verify font/media/notice coverage in JavaScript, Wasm, and
  macOS release artifacts.
- Record 19 passing Catalog tests, strict analysis, and 49 reviewed
  supplemental component images. Complete real screen-reader, physical-device,
  browser, temporal-motion, and representative performance acceptance remain
  separate stable-release gates.
- Re-export the final 49 visual-review images after the last text-contrast
  and hosted-adapter corrections. Preserve all image pixels, record ten
  current macOS golden hashes, and accept eight reviewed Linux candidates
  from run `33736546039`; strict comparison passed in run `33741053163`.
- Confirm the final 528-test library suite, 19-test Catalog suite, both strict
  analyzers, and latest portable-source Wasm/macOS release builds. Preserve
  the isolated hosted-consumer theme and 13-label notice-delivery evidence
  separately from workspace and remote results.
- Record the earlier lock-screen delay of Safari/final profile work and its
  resumption after the fresh unlocked-session check at 11:23 UTC.
- Record second CI `33741053163`: 11 successful jobs, one Apple launcher
  self-test cleanup failure, no skips. Strict Linux goldens, cloud hosted
  consumer and zero-warning publish preflight passed; that run skipped the
  simulator build/journey after its preflight failure.
- Record third CI `33742943774`: launcher self-tests/build/install pass and
  unified logs confirm real app/test execution. Driver VM discovery times
  out and strict teardown reports an active SemanticsHandle, with no other
  body assertion failure recorded. Quality and cloud consumer gates pass;
  scoped discovery and semantics-baseline repairs remain open without leak
  exemptions.
- Record fourth attempt 1: actual iOS journey and strict teardown pass after
  native semantics readiness, while delayed PID output prevents the driver
  stage. The revised launcher passes 11 local tests and review; remote
  completion remains pending. The same-SHA targeted Edge retry passes after
  a pre-test renderer timeout, without establishing the original cause.
- Complete final-source native profiling: 7/7 workloads, 4,495 frame samples,
  478 RSS samples and successful teardown/driver/finalizer, with 50 source/
  build inputs matching the validated CI revision. Capture scope and budgets
  remain explicit.
- Accept three independently reviewed Safari light/dark/light captures with
  reduced motion and correct Flowchart condition colors. Preserve the earlier
  unexplained capture anomalies and the remaining full Safari matrix.
