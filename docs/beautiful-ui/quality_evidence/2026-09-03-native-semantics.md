# macOS native accessibility exposure evidence

Date: 2026-09-03 (Asia/Shanghai)
Toolchain: Flutter `3.47.0`, Dart `3.13.0`, local macOS release runner
Status: native AX exposure restored; complete VoiceOver workflow acceptance remains open

## Observed comparison and correction

The Catalog release launched with
`--dart-define=ENABLE_WEB_SEMANTICS=true` exposed only the native window and
container through Computer Use's `sky.get_app_state`. The interface remained
visually usable, and the shared native integration journey had passed. Turning
VoiceOver on and cold-starting that forced-semantics release did not restore
Flutter children in the AX snapshot.

The comparison build omitted the Web-only forcing flag. From
`packages/beautiful_ai_ui_catalog`, the executed build command was:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer mise exec -- flutter build macos --release --no-pub
```

After VoiceOver was actually enabled and the ordinary release was cold-started,
the same AX reader immediately returned a populated Flutter subtree. The saved
dump includes the Catalog title, Theme and Motion buttons, and initial P1/P2
content. Its indices run from `0` through `174`; these include native window
and menu controls, so they are not a count of verified component controls.

The local raw artifacts are:

- [Native AX text snapshot](../../../packages/beautiful_ai_ui_catalog/build/release_verification/native/ordinary-release-voiceover-on.ax.txt)
- [Corresponding screenshot](../../../packages/beautiful_ai_ui_catalog/build/release_verification/native/ordinary-release-voiceover-on.png)

These are generated local build artifacts and can be removed by cleaning the
Catalog build directory. The before-state is recorded in the execution history;
this evidence directory contains the after-state pair.

The Catalog entry point now limits its explicit semantics handle to
`kIsWeb && const bool.fromEnvironment('ENABLE_WEB_SEMANTICS')`, preventing that
flag from forcing framework semantics in a native build. No component or
private native-engine API was changed. Follow-up scoped static analysis and
all 19 Catalog tests passed. VoiceOver was restored to its original off state,
and the windows opened for this check were closed.

## Source explanation

The standard Swift runner creates a `FlutterViewController` and does not
override accessibility behavior. The installed SDK source distinguishes the
framework semantics handle from the macOS accessibility bridge:

- `SemanticsBinding.ensureSemantics()` keeps framework generation enabled.
  Platform enablement acquires another handle; it does not necessarily change
  the framework's enabled value when a forced handle already exists.
  [Pinned framework implementation](https://github.com/flutter/flutter/blob/4cf24164269a5ebf0c16a028a00727d0e77bbb05/packages/flutter/lib/src/semantics/binding.dart#L144)
- macOS enables its bridge through `FlutterEngine.semanticsEnabled`, driven by
  `AXEnhancedUserInterface` notifications. Disabling it clears the native
  children and releases the bridge; updates received while disabled are
  discarded. The source explicitly discusses application loss of focus in
  this path. [Pinned engine implementation](https://github.com/flutter/flutter/blob/4cf24164269a5ebf0c16a028a00727d0e77bbb05/engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterViewController.mm#L458)
- Framework updates contain dirty nodes. Keeping the framework tree alive
  while a native bridge is absent or recreated can therefore leave the new
  bridge without the complete root update. This is the source-based explanation
  for the observed forcing-flag sensitivity; notification timing and the exact
  dropped update were not instrumented in this comparison.

The successful ordinary-release snapshot, together with the populated native
AX node observed in the separate profile harness, establishes that this tool
can read Flutter's native accessibility output on this machine. The earlier
empty snapshot is not evidence of a general tool inability to inspect Flutter.

## Acceptance boundary

This comparison confirms restoration of native AX exposure and the need to
keep the Web forcing fixture out of ordinary native runs. The shared journey's
Flutter Semantics operations and this system AX snapshot remain separate
evidence: the journey obtains its own test semantics handle and does not itself
validate the macOS accessibility bridge.

Neither result completes VoiceOver spoken-output, focus-order, live-region,
selection, or full task-sequence acceptance across all 20 components. Those
checks, and the other advertised platforms' screen-reader workflows, remain
release gates in the [support matrix](../support_matrix.md).
