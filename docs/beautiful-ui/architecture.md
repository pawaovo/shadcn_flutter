# `beautiful_ai_ui` architecture

Status: P0-P2 implementation contract; release verification remains incomplete
Baseline date: 2026-09-02 (Asia/Shanghai)
Updated: 2026-09-03 (Asia/Shanghai)

## Purpose

`beautiful_ai_ui` is an independent Flutter package that reimplements the visual language, interaction intent, and AI-product composition patterns represented by Beautiful UI. It targets Android, iOS, Web, macOS, Windows, and Linux while using `shadcn_flutter` as its in-process UI foundation.

This is an unofficial implementation. It is not maintained, sponsored, endorsed, or certified by Beautiful UI, Turbo, or the maintainers of `shadcn_flutter`.

## Canonical terms

- **Source item**: one entry in the pinned Beautiful UI registry. The project tracks 27 source items: one foundation, six shared building blocks, and twenty gallery components.
- **Foundation**: semantic color, typography, spacing, radius, elevation, focus, and motion policy. It is not a screen or business feature.
- **Building block**: a shared implementation detail used by composite components. It is not automatically part of the stable public API.
- **Composite component**: one of the twenty AI-product interfaces exposed by the Beautiful UI gallery.
- **Parity**: equivalent visual hierarchy, states, core interaction outcomes, and accessibility intent. It does not mean a line-for-line TSX port or DOM-level pixel identity.
- **Adaptive mode**: a presentation selected from the actual constraints available to a widget: compact, medium, or expanded. It is not inferred solely from the device name.
- **Catalog**: the non-published demonstration and test application. Scripted scenarios live here, not in the library.

The authoritative scope and implementation state live in [`parity_manifest.yaml`](./parity_manifest.yaml). Research material is historical input, not a live status tracker.

## Package boundary

The planned workspace shape is:

```text
packages/
├── shadcn_flutter/                 # Upstream core; kept close to upstream
├── shadcn_flutter_material/        # Upstream companion package
├── shadcn_flutter_cupertino/       # Upstream companion package
├── shadcn_flutter_genui/           # Upstream companion package
├── beautiful_ai_ui/                # Publishable package
│   ├── lib/beautiful_ai_ui.dart    # Stable public barrel
│   └── lib/src/
│       ├── foundation/
│       ├── models/
│       ├── components/
│       ├── adaptive/
│       ├── interaction/
│       ├── accessibility/
│       └── implementation/
│           ├── controls/
│           ├── streaming/
│           └── shadcn/
└── beautiful_ai_ui_catalog/        # Non-published catalog and harness
```

Only `beautiful_ai_ui.dart` is a supported import surface. Files under `lib/src/` are implementation details.

The seam is recorded in [`decisions/0001-package-seam.md`](./decisions/0001-package-seam.md).

## Dependency direction

```text
Host application
  -> immutable data, state, and callbacks
beautiful_ai_ui public interface
  -> foundation, adaptive policy, interaction, semantics
beautiful_ai_ui internal shadcn implementation
  -> shadcn_flutter public API
Flutter framework
```

The following dependency rules are mandatory:

1. `beautiful_ai_ui` may import `package:shadcn_flutter/shadcn_flutter.dart` internally.
2. It must not import `package:shadcn_flutter/src/...`.
3. Public constructors, fields, callbacks, controllers, builders, and return types must not mention a `shadcn_flutter` type.
4. `beautiful_ai_ui` must not re-export `shadcn_flutter`.
5. Material and Cupertino companion packages are integrated by the host or catalog only when needed; they are not mandatory dependencies of the publishable package.
6. A defect in `shadcn_flutter` should first be isolated behind `implementation/shadcn/`. A core change is a separate, tested upstream-oriented change, never an incidental component implementation detail.

## Public interface principles

The primary interface is a set of strongly typed, default-first Flutter widgets. Each composite component owns the responsive layout, transient presentation state, semantics, focus behavior, and motion needed to deliver its contract.

Public APIs follow these rules:

- Accept immutable domain snapshots and explicit callbacks.
- Require stable, unique IDs for reorderable, selectable, streamed, or asynchronously updated items.
- Keep business state in the host: network requests, LLM calls, token transport, persistence, approval submission, search, authorization, analytics, and databases are outside this package.
- Keep transient display state inside the widget when it has no business meaning: hover, pressed, focus highlight, local disclosure animation, and short-lived copy feedback.
- Use one documented controlled/uncontrolled convention for state that may be host-owned. Do not expose competing `value`, `initialValue`, `controller`, and callback mechanisms for the same state.
- Add controllers only for genuinely high-frequency or imperative surfaces. The first candidates are streamed text chunks and a flowchart viewport; ordinary cards, rows, filters, and approvals use data plus callbacks.
- Add a customization slot only after a second concrete use case exists. Slots are semantic and must not expose the internal shadcn widget tree.
- Errors that affect a component's visible state are supplied as data. A
  narrow host callback is also the seam for real external actions such as
  recommendation acceptance or clipboard replacement. Exceptions from those
  actions are normalized as `BeautifulUiFailure` and reported through
  `BeautifulUiScope.onFailure`; without a handler they use
  `FlutterError.reportError`.

The P1 modules demonstrate this ownership contract:

- Loading State, Thinking, and Search receive caller-owned business snapshots;
- Context Cards owns only local body disclosure and delegates source actions;
- Recommendation Card de-duplicates pending acceptance and commits success
  only after the host callback completes;
- Code Block owns copy feedback and uses Flutter Clipboard by default, while a
  callback can replace that external action for policy or testing;
- collapsed Thinking, Context, and Recommendation descendants leave both the
  focus and Semantics trees.

The P2 modules extend the same boundary with explicit state lifetimes:

| Module | Host-owned data and actions | Package-owned presentation |
|---|---|---|
| Streaming Text | Exact text parts, stable source IDs, lifecycle, feedback, source/follow-up callbacks, retry | Source disclosure, selection, de-duplicated clipboard/retry feedback |
| Approval Card | Question/option snapshots, initial answers, asynchronous submission, visible errors | Answer drafts, question navigation, dismissal, pending and submitted presentation |
| Tool Chips | Tool state, output, and changed-file snapshots | Run, tool, file-preview, and show-more disclosure |
| Task Rows | Status, progress, details, and optional asynchronous retry | Per-task disclosure, focus, and pending retry feedback |
| Chat | Message snapshots, response identity, selected context tab, send/stop actions, visible errors | Draft input, selection, focus, pending actions, transcript position, follow-latest behavior |
| Filter Table | Immutable business rows and localized display data | Status filter initialized once; change callback is observational |
| Fine-tune Card | Accepted settings and a callback for complete proposed settings | Uncommitted numeric drafts, validation, focus, type disclosure, comparison with the initial settings |

`stream-text` is implemented only inside `implementation/streaming/`. The
composite consumes exact snapshots immediately and uses Flutter selection
infrastructure; it adds no synthetic typewriter delay, network client, or
public primitive wrapper. Streaming source markers refer to stable source IDs.
Full-size source controls are available in an inline disclosure after the
generation settles. Source images and demo URLs are not redistributed.

Asynchronous presentation is bounded by identity. Approval model changes,
task snapshot changes, new streamed-answer IDs, and new chat conversation or
response IDs invalidate obsolete completions. A successful task retry never
changes host-owned execution status. Chat send success clears only the exact
unedited draft that was submitted, so preparing the next draft while a send
is pending is safe. Recoverable errors use `approval`, `taskRetry`, `chat`, or
`streaming` operations through the existing root failure seam; streamed answer
copy continues to use `clipboard`.

`implementation/controls/text_selection.dart` centralizes Flutter touch
selection handles and gestures, localized 48dp clipboard menus, and guarded
copy/cut/paste. Keyboard and native Semantics actions use the same routine.
Pending clipboard work is invalidated by editor ownership as well as text and
selection changes, so an identical-text replacement conversation or question
cannot receive an obsolete paste. Cut changes the draft only after the
clipboard write succeeds; a failure preserves input and uses the root failure
seam.

Approval single-choice answers may auto-advance or submit when `autoAdvance`
is enabled. Multiple-choice and custom answers require an explicit Continue
or Send action. `initialAnswers`, Chat's `initialDraft`, and Filter Table's
`initialStatus` seed state only at the documented identity boundary; they do
not act as competing controlled values. Fine-tune settings instead follow a
fully controlled convention: the host accepts an edit by supplying its new
settings snapshot.

## Foundation and theming

The foundation translates source intent into Flutter-native tokens rather than embedding CSS values in each component. It owns:

- semantic light and dark color roles;
- typography roles for UI text and code;
- spacing, radius, border, and elevation scales;
- focus indication and interactive-state overlays;
- motion durations, curves, and reduced-motion substitutions;
- layout-mode policy and content-driven overrides;
- high-contrast adaptations.

Tokens are implementation-neutral at the public boundary. Internal adapters map them to `shadcn_flutter` themes and component properties.

The adapter fixes shadcn's internal scaling at `1.0` so a 10dp card radius or
48dp interaction target has the same logical size on every platform; it does
not reuse shadcn's platform-name-based 1.25 mobile multiplier. Touch target
sizes are owned explicitly by each Beautiful AI UI module and verified by
Flutter accessibility guidelines. This separates adaptive presentation and
input ergonomics from brand-token scaling.

## Adaptive presentation

The initial project defaults are:

| Mode | Nominal width | Intent |
|---|---:|---|
| Compact | `< 600dp` | Single-column composition, full-width primary actions, drawer/sheet alternatives, touch-first targets |
| Medium | `600–1023dp` | Selective two-column layouts, rails, reduced table columns, overlay chosen by available space |
| Expanded | `>= 1024dp` | Sidebars, multi-column composition, anchored overlays, full data/editor affordances |

These values are defaults, not device detection. Reusable components choose from parent constraints, and a component may switch earlier when its content cannot satisfy the contract.

Changing layout mode must preserve host state, draft input, selection, streaming progress, disclosure state, focus where possible, and scroll position. Responsive branches must therefore sit below the owner of those states and use stable identity.

Complex compact adaptations are deliberate product presentations:

- Records Table becomes a list/card summary with row detail instead of a scaled wide table.
- Sidebar Nav becomes a drawer or bottom navigation pattern.
- Flowchart may become a read-only view or stepper until touch editing has an approved contract.
- Selection Actions use a system-appropriate selection toolbar or sheet on touch devices.
- Hover-only controls always receive tap/long-press and keyboard equivalents.

## Accessibility and input

Accessibility is part of component behavior, not catalog metadata. Every public component must provide, as applicable:

- meaningful roles, labels, values, selected/expanded/disabled states, and status/live-region behavior;
- logical reading, traversal, and focus order;
- keyboard activation and dismissal, including Tab, Shift+Tab, Enter, Space, Escape, and directional navigation where conventional;
- touch, pointer, trackpad, wheel, and visible-scrollbar behavior appropriate to the platform;
- non-color state cues;
- Android 48dp and iOS 44pt target-size compliance for primary interactive controls;
- usable layouts at 200% text scaling, with long Chinese, English, and Arabic content and RTL direction;
- reduced or removed non-essential motion when animations are disabled.

Custom painters, charts, drag handles, streamed status, and selection overlays require explicit semantics; they do not inherit accessibility from the source DOM implementation.

Streaming Text and Filter Table use changing native `liveRegion` labels for
lifecycle/copy feedback and matching counts. These nodes do not also set
`SemanticsRole.status`: Flutter 3.47 rejects combining that role with the live
region flag, and native announcement behavior needs the live-region flag.
Streamed answer and chat message bodies are outside live regions so incoming
text does not request repeated full-answer announcements. Actual screen-reader
behavior remains a release evidence gate beyond Semantics-tree tests.

## Catalog and harness

The catalog is both a visual reference and an executable contract. It shows normal, hover, focus, pressed, disabled, loading, empty, error, long-content, RTL, high-contrast, and reduced-motion states across compact, medium, and expanded constraints.

Scripted prompts, fake records, timers, and simulated streaming belong only in the catalog. The publishable package contains no scripted agent, demo business data, LLM client, SSE/WebSocket client, database, microphone service, or approval backend.

The same critical Catalog journey runs through WebDriver Chrome, Android
emulator, and Linux desktop under Xvfb. It launches the real application,
cycles theme and motion policy, opens recommendation alternatives, filters
Search, copies Code Block content through the injected catalog callback, and
fails on framework exceptions. Widget tests remain the broader behavioral
matrix; device journeys prove the packaged runners can execute the core path.

P2 scenarios live in `beautiful_ai_ui_catalog/lib/p2_examples.dart` and cover
streaming/complete/failed answers, the approval question workflow, tool/file
disclosures, both task-row variants, message send/stop, status filtering, and
controlled numeric/type changes. The shared journey now exercises these host
callbacks too. The existence of that journey is separate from accepted
execution evidence, tracked in
[`quality_evidence/2026-09-03-p2-modules.md`](./quality_evidence/2026-09-03-p2-modules.md).

## Verification contract

An item can move to `complete` in the parity manifest only when all applicable evidence exists:

1. Public API uses data/state/callbacks and respects the dependency boundary.
2. Compact, medium, and expanded presentations have no overflow, including boundary widths 599, 600, 1023, and 1024dp.
3. Resize, rotation, split-screen, and keyboard inset changes do not silently reset meaningful state.
4. Touch, pointer, and keyboard complete the core task.
5. Light/dark, high contrast, 200% text, long localized content, RTL, and reduced motion are verified.
6. Semantics expose the correct role, name, value, state, and announcements.
7. Unit, widget/interaction, semantics, and representative golden tests pass; high-volume components also have performance evidence.
8. The catalog covers the documented variants and failure states.
9. Public API documentation, minimal usage, source provenance, assets, and license records are current.
10. Six-platform evidence satisfies [`support_matrix.md`](./support_matrix.md) for the intended release gate.

Golden images are generated only in a pinned SDK, font, locale, viewport, device-pixel-ratio, and OS image. CI does not update goldens automatically.

## Upstream and release policy

The source pins and sync procedure are in [`upstream_baseline.md`](./upstream_baseline.md). Upstream upgrades use dedicated branches and reviews, with API, test, build, and golden evidence. A regular feature change does not also upgrade Flutter, `shadcn_flutter`, or all golden baselines.

The package may release after P1 or P2; completion of all twenty composite components is not required to publish a useful, accurately scoped version. Release notes must derive support and parity claims from verified manifest entries, never from roadmap entries.

## Legal and brand boundary

Source adaptation is tracked in [`legal/component_provenance.yaml`](../../legal/component_provenance.yaml), asset decisions in [`legal/assets.yaml`](../../legal/assets.yaml), and required license notices in [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).

Central Icons, the externally hosted Surfer video, Beautiful UI/Turbo logos, and other unapproved source assets are excluded from all distributable artifacts. `beautiful_ai_ui` uses independent branding and may refer to Beautiful UI only for factual attribution and compatibility context.

Newly authored `beautiful_ai_ui` Dart code uses BSD 3-Clause to remain consistent with the fork. The package-level [`LICENSE`](../../packages/beautiful_ai_ui/LICENSE) also preserves the Beautiful UI MIT notice required for adapted portions. Release verification must confirm that Flutter's generated license registry contains these terms and every other redistributed third-party notice.

## Explicit non-goals

- Translating TSX, Tailwind, or DOM structure line by line.
- Shipping an AI model, agent runtime, networking protocol, storage layer, or business workflow.
- Exposing every source building block as a public Flutter widget.
- Guaranteeing pixel identity across Flutter renderers and the source website.
- Importing commercial icons, remote demonstration media, or source branding.
- Forking internal `shadcn_flutter` APIs into the stable public contract.
