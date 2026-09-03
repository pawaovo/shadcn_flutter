# Catalog changelog

## Unreleased

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
  after palette/muted-ticker/hosted-adapter fixes has not started because the
  local Mac requires manual unlock; no unagreed performance budget is asserted.
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
- Record the outstanding post-TickerMode Safari visual check and final
  profile run as requiring the user to unlock the local Mac manually.
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
