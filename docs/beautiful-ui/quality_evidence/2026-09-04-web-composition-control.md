# Web composition control — 2026-09-04

**Stock `EditableText` and `BeautifulPromptBar` behaved alike in the enabled
semantics host. Neither tested injection path established the expected persistent
composing range.** The [observation record](2026-09-04-web-composition-control.json)
was transcribed from visible DOM snapshots in Codex's in-app browser. Text stayed
`中文`, selection stayed `[2,2]`, and Flutter primary focus stayed true.

| Input path | Stock control | Prompt |
| --- | --- | --- |
| One public Dart editing-value injection | `[0,2]` immediately and next frame; `[-1,-1]` at 102/503 ms | `[0,2]` immediately and next frame; `[-1,-1]` at 101/501 ms |
| Synthetic DOM composition lifecycle | `[-1,-1]` throughout 1/15/100/500 ms and after end | `[-1,-1]` throughout 1/18/101/501 ms and after end |

The DOM sequence dispatched compositionstart, compositionupdate, input,
compositionend, then input. Every event's actual `isTrusted` was false. An empty
range after end matched the ending condition, but the required active range was
never established. The earlier disabled-stock page was not used as a control.

The installed Flutter 3.47.0 SDK explains this test-channel boundary. Its DOM
editing-state writer applies text and selection, without creating a browser IME
session. The normal composition tracker needs composition events; the enabled
semantics editing strategy overrides event registration and omits the default
composition handlers. These paths and their source hashes are recorded in the
[provenance inventory](../diagnostics/web-composition-control/provenance.json).
This supports a limitation of these synthetic channels under this SDK/host,
not a Prompt-specific IME diagnosis. **No OS IME success or failure is established.**

The framework gate remains unchanged: no composition assertion was replaced,
relaxed, or skipped. The independent W3C suite still prohibits JavaScript text
injection. Actual OS IME behavior requires separate real input-method validation.

The [preserved final probe](../diagnostics/web-composition-control/composition_web_probe.dart)
has SHA-256 `9f5dce10e558a8b84ca5027867bee7f0b6ef44b367a17ca324da0bc016c532f9`,
matching the observation record. It contains both stock/product controls and both
input paths. The provenance file records the final build command/log, current
dependency context, and all 341 local build artifacts (49,665,787 bytes). This is
a post-run inventory, not a contemporaneous build-source freeze. The earlier
Dart-only bundle was overwritten without a separate retained hash. The final
loader uses an engine-versioned CanvasKit CDN; actual network/cache responses
were not archived. Build metadata names the host package, not the Catalog app:
the executable entry point is this diagnostic probe.

To create a **new** replay without overwriting the observed bundle, run from the
repository root with the recorded Flutter SDK and lockfile:

```sh
cd packages/beautiful_ai_ui_catalog
mkdir -p build/diagnostics
cp ../../docs/beautiful-ui/diagnostics/web-composition-control/composition_web_probe.dart \
  build/diagnostics/composition_control_replay.dart
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter build web --no-pub \
  --target=build/diagnostics/composition_control_replay.dart \
  --output=build/diagnostics/composition-control-replay
python3 -m http.server 52710 --bind 127.0.0.1 \
  --directory build/diagnostics/composition-control-replay
```

Open the local page, verify stock is enabled, and run each control/path once.
Read the visible samples through completion; a new build/run produces new
evidence. The current dependency patch in the diagnostic directory is descriptive
provenance, not an instruction to modify the checkout.
