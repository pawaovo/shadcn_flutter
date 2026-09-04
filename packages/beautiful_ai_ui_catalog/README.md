# Beautiful AI UI Catalog

Multi-platform visual, interaction, accessibility, and integration harness for
`beautiful_ai_ui`.

Current release evidence and open gates are summarized in
[September 4 release readiness](../../docs/beautiful-ui/quality_evidence/2026-09-04-release-readiness.md).
Candidate `3612efd0` passed **11/12** main jobs (Edge failed before app startup),
all three native framework input jobs and the full Firefox W3C suite. All four
W3C browsers passed Prompt and clipboard flows; remaining readonly-focus and
cold-start repairs await their new run. P1/P2 budgets passed **8/8** at the
earlier `87299572` runtime snapshot; P3 and full device/AT gates remain open. The `c2bde85` results below are dated historical observations,
not acceptance of later source. All 27 registry entries remain `in_progress` and all six
platforms remain `Partial`.

Run on the Web:

```bash
flutter run -d chrome
```

Build both Web render targets:

```bash
flutter build web --release --dart-define=ENABLE_WEB_SEMANTICS=true
flutter build web --release --wasm --dart-define=ENABLE_WEB_SEMANTICS=true
```

`ENABLE_WEB_SEMANTICS` applies only on Web (`kIsWeb && flag`). Ordinary native
runs use the operating system's accessibility lifecycle. Forcing the Web
semantics handle on macOS previously prevented the expected native AX tree
from being exposed; the current scoped behavior was checked with a no-flag
native A/B run. The [native semantics evidence](../../docs/beautiful-ui/quality_evidence/2026-09-03-native-semantics.md)
keeps this tree inspection separate from a complete VoiceOver workflow.

The catalog exposes all 20 P1, P2, and P3 modules, theme cycling, and motion
policy cycling. P1/P2 use a responsive one/two/three-column grid. The seven P3
sections use the full available width so Records Table and Flowchart can expose
their desktop grid and canvas; narrow windows use cards and ordered steps.
Drafts, filters, disclosure, and inspector values survive layout and theme changes.

P2 examples include complete/live/failed Streaming Text with citations,
copy/feedback/follow-up actions and retry; a three-question Approval Card;
Tool Chips with output and changed-file disclosure; both Task Rows variants;
Chat with context tabs, send, and stop; a status Filter Table; and a controlled
Fine-tune Card with numeric entry, layout, and type selection. The **Run stream
demo** action uses a finite local timer owned by the catalog. Chat replies stay
pending until **Complete demonstration response** or **Stop response** is
selected, allowing either state to be inspected without a time limit.
Submission and retry examples resolve locally. No AI backend is connected,
and the excluded Surfer demonstration video is never requested.

P3 examples are complete local host integrations:

- **Prompt Bar** accepts `/` commands and `@` sources, switches models, attaches
  sample files, inserts a sample dictation transcript, and receives submissions.
  Rounded/pill and compact/tall variants retain the same draft. The sample
  dictation control does not request a microphone.
- **Diff Table** reviews added, changed, removed, and unchanged records, keeps
  inclusion across pages, and applies exactly the chosen change IDs. Reset
  starts a fresh proposal.
- **Records Table** searches and sorts supplier records, selects rows, edits
  accepted property settings, adds properties, and calculates visible rows using
  deterministic local sample rules. Configuration and results are supplied back
  by the catalog host, making acceptance visible in the table.
- **Sidebar Nav** switches workspaces and destinations, searches recent chats,
  creates local sample chats/workspaces, and exposes workspace action previews.
  Its explicit expanded/drawer presentation follows the surrounding layout.
- **Flowchart** edits a stock threshold in ordered steps or the desktop canvas,
  where node movement and viewport controls are available. Changes update the
  host workflow snapshot.
- **Insight Cards** includes comparison, anomaly, and allocation charts with
  exact observations, chart-data disclosure, metric/segment selection, and
  follow-up actions.
- **Selection Actions** starts with a real selected document range, prepares
  local sample rewrites/explanations, and updates the document only when the
  user keeps a proposed edit. Reset restores the original passage.

Run catalog widget tests:

```bash
flutter test
```

Tests cover P1, P2, and P3 interactions, compact layouts, and state preservation
when resizing from a desktop grid/canvas to a phone viewport. The shared device
journey exercises all 20 modules with scoped controls, so
repeated labels such as Copy, Retry, and Send remain unambiguous.

Run the shared device journey with Flutter Test on an available native target
such as Android, Linux, macOS, Windows, or an iOS simulator:

```bash
flutter test integration_test/catalog_journey_test.dart -d <device>
```

Web integration uses `flutter drive`, a matching ChromeDriver, and the
`test_driver/integration_test.dart` adapter because Flutter 3.47 does not run
`integration_test` through `flutter test -d chrome`.

**Historical fifth CI `33748054504`, attempt 1, passed all 12 jobs** for code
**`c2bde85dd5da7c33b0f7881234ae312f3be1826c`**. Quality passed 528 library,
26 Catalog and 571 core tests, strict analysis and Linux golden comparison.
All native/browser journeys passed, including the actual iOS Flutter driver:
exit 0 in 50.234s with one whole Catalog journey plus suite setup/teardown,
followed by successful termination. The original runner's `+3` includes
those suite hooks and does not mean three independent journey tests.

The [historical compact evidence](../../docs/beautiful-ui/quality_evidence/2026-09-03-final-ci-33748054504.json)
records exact artifact hashes and the hosted-consumer result at the same
code SHA. Earlier attempts and the fourth run's targeted Edge retry remain
historical evidence; their failures are distinct from that source's full pass.
The later `3614250` checkpoint finished with main CI 10/12 and input/AT CI 1/9;
its actual failure boundaries and subsequent local repairs are retained in the
current readiness record, rather than replaced by the older pass.

The Catalog now uses independently drawn launcher/Web artwork. The exact
source and generated files are recorded in
[`legal/assets.yaml`](../../legal/assets.yaml). Fresh JavaScript, Wasm, and
macOS release artifact audits verified the registered font/media hashes and
complete notices, including 266 flag images and five original Web images.
The real Flutter `LicenseRegistry` probe verified 13 complete labels.

For native workload measurement, the opt-in
[`tool/run_p3_profile.sh`](tool/run_p3_profile.sh) creates a separate profile
fixture and saves raw artifacts under `build/p3-profile/`. It supports the
seven-workload P3 suite, eight representative P1/P2 workloads, or both, with an
explicit native Start preparation gate and before/after source verification.
The [engineering defaults and assessor](../../docs/beautiful-ui/quality_evidence/performance/engineering_acceptance.md)
now define fixed frame and whole-process RSS gates. These defaults are not
product-approved budgets. The [3614250 baseline](../../docs/beautiful-ui/quality_evidence/performance/2026-09-04-3614250-native-baseline.md)
contains two complete captures with actual budget failures; a subsequent locked
preparation attempt measured no workloads and is not an isolated comparison.

The historical
[c2bde85 source-matched capture](../../docs/beautiful-ui/quality_evidence/performance/2026-09-03-macos-profile-final/README.md)
completed all seven workloads and strict finalization with 4,495 frame samples
and 478 process RSS samples at 1,728×1,080dp, DPR 2, 120 Hz. All 50 runtime/
build inputs match validated code `c2bde85…`; documentation/evidence changes
in the worktree are recorded separately. The platform semantics flag is false
but framework test semantics remains enabled. This historical capture does not
replace current budget failures or establish repeatability, other-platform
performance, or physical-input acceptance.

The [targeted Safari review](../../docs/beautiful-ui/quality_evidence/2026-09-03-safari-flowchart-theme-reduced.md)
accepted three paired screenshot/AX captures of light/dark/light with reduced
motion. Flowchart buttons correctly restore a light background with dark text,
closing the pictured regression. Safari remains Partial; the full browser/
input/AT and timing/performance matrices are not accepted by those captures.
Earlier white/no-window capture issues ceased without code changes and have
no established cause. GUI testing is finished; Safari was restored to an
ordinary window in light theme with reduced motion.

The [historical 49-image review](../../docs/beautiful-ui/quality_evidence/2026-09-03-accessibility-visual-review.md)
and [September 3 readiness record](../../docs/beautiful-ui/quality_evidence/2026-09-03-release-readiness.md)
retain their original scope. The current September 4 record links the later
P1/P2 complementary review, P3 finite matrix, targeted byte-identical addenda,
input failures and measured budget results. All twenty
modules are implemented, all 27 registry entries remain `in_progress`, and
all six platform support states are `Partial`.
