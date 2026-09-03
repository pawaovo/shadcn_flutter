# Catalog changelog

## Unreleased

- Expose all twenty Gallery components through explicit local host state and
  a shared integration journey. Keep Chat response completion under an
  explicit action so Send/Stop demonstrations are deterministic.
- Restrict `ENABLE_WEB_SEMANTICS` to Web. Ordinary native runs use the
  platform accessibility lifecycle; the macOS AX comparison and complete
  native journey have passed.
- Add native macOS/iOS simulator/Windows journey steps and dedicated
  Firefox/Edge jobs to the twelve-job CI configuration. Current remote
  execution remains pending.
- Add a separate opt-in P3 native profile harness with source/artifact hashes,
  independent frame data, RSS samples, renderer/viewport evidence, and an
  explicit final driver/teardown result. Historical macOS baseline
  `20260903T080855Z` completes all seven workloads. Final-source resampling
  after the last palette/muted-ticker fixes is pending; no unagreed performance
  budget is asserted.
- Replace template launcher/Web artwork with registered original project
  artwork and verify font/media/notice coverage in JavaScript, Wasm, and
  macOS release artifacts.
- Record 19 passing Catalog tests, strict analysis, and 49 reviewed
  supplemental component images. Complete real screen-reader, physical-device,
  browser, temporal-motion, and representative performance acceptance remain
  separate stable-release gates.
- Re-export the final 49 visual-review images after the last text-contrast
  and muted-ticker theme corrections. Record ten current macOS golden image
  hashes; eight changed Linux component baselines await CI candidates.
- Confirm the final 526-test library suite, 19-test Catalog suite, both strict
  analyzers, and the latest Wasm release build before the first twelve-job
  remote verification run.
