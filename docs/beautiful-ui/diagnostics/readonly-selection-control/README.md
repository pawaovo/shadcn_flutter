# Preserved readonly selection controls

This directory preserves the diagnostic sources associated with the
[2026-09-04 observation record](../../quality_evidence/2026-09-04-readonly-selection-control.md).
The sources are byte-identical copies of the final ignored working files.
The three archived `*-build.txt` files also retain the original compiler output,
including trailing spaces on their first lines. Those three raw-log lines are
the only new whitespace-check exceptions; source/documentation checks pass.

| File | Role |
| --- | --- |
| [native-html/index.html](native-html/index.html) | Native HTML readonly textarea with event/state observers |
| [readonly_web_probe.dart](readonly_web_probe.dart) | Stock readonly `EditableText` and `BeautifulSelectionActions` in the same Flutter host |
| [readonly_sdk_shortcuts_probe.dart](readonly_sdk_shortcuts_probe.dart) | Stock-only experiment using official SDK selection intents for arrow shortcuts |
| [readonly-web-build.txt](readonly-web-build.txt) | Byte-identical baseline Flutter compilation log, archived as `.txt` to avoid the repository's `*.log` ignore rule |
| [readonly-sdk-shortcuts-build.txt](readonly-sdk-shortcuts-build.txt) | Byte-identical SDK-shortcut compilation log, archived as `.txt` |
| [readonly-sdk-shortcuts-manifest.json](readonly-sdk-shortcuts-manifest.json) | Original metadata, preserved unchanged; its multiline-CI wording is superseded by the observation record |
| [readonly_product_web_probe.dart](readonly_product_web_probe.dart) | Appended actual-product probe: exact CI and explicit-newline documents, with no probe shortcut map |
| [readonly-product-web-build.txt](readonly-product-web-build.txt) | Byte-identical actual-product compilation log, archived as `.txt` |
| [readonly-product-web-manifest.json](readonly-product-web-manifest.json) | Original actual-product build metadata and five source/output/dependency hashes |
| [provenance.json](provenance.json) | Post-observation source/output/dependency SHA-256 inventory and evidence boundaries |

The Flutter pages export observations to `window.__readonlyProbe` and
`window.__readonlySdkShortcutProbe`; the appended product page exports
`window.__readonlyProductProbe`. The HTML page renders its observations in
the DOM. The Flutter event history retains at most 120 entries. No complete
runtime export is archived yet, and the existence of observer code is not
evidence of an observed runtime outcome.

Local build outputs are identified by hashes rather than committed assets.
Their `version.json` files name the host package `beautiful_ai_ui_catalog` at
version `0.1.0` / build `1`; those files do not identify the diagnostic entrypoint
or Flutter SDK. The separate SDK inventory records Flutter 3.47.0. Recorded
local URLs and server-session metadata are historical; this archive does not
manage or verify those servers.

To build a new replay, copy the chosen archived Dart file into a **new** ignored
entrypoint under `packages/beautiful_ai_ui_catalog/build/diagnostics/`, and build
that entrypoint with the recorded SDK and lockfile to a new output directory.
For example, from `packages/beautiful_ai_ui_catalog`:

```sh
cp ../../docs/beautiful-ui/diagnostics/readonly-selection-control/readonly_web_probe.dart \
  build/diagnostics/readonly_control_replay.dart
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter build web --no-pub --release \
  --target=build/diagnostics/readonly_control_replay.dart \
  --output=build/diagnostics/readonly-control-replay
```

This is a proposed replay command, not a recovered original command line. A new
build or browser run produces new evidence and does not replace the archived
observations. No replay was performed as part of this archive task.
