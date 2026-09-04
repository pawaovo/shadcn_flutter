# Live OS IME observer source

This directory preserves the passive observer used for the
[September 4 native-input observation](../../quality_evidence/2026-09-04-live-os-ime-observation.md).
That observation contains ordinary trusted `n` insertion, **not an accepted OS
IME pre-edit session**. No complete original trace was exported.

- [live_os_ime_probe.dart](live_os_ime_probe.dart): exact source; both editors start
  empty and writable under enabled semantics. Listeners only record DOM and
  Flutter state. Prompt's actual onSend callback records genuine submissions.
- [build-manifest.json](build-manifest.json): original pre-observation source/build
  manifest, including main JS/bootstrap and dependency hashes. Its event-name
  list specifies installed listeners, not confirmed runtime event occurrence.
- [live-os-ime-build.txt](live-os-ime-build.txt): raw build log, byte-for-byte with
  original trailing whitespace preserved. This evidence file is a specific
  whitespace-check exception; do not normalize its bytes.
- [provenance.json](provenance.json): archive identities and compact-record link.

The compiled assets stay in ignored
`packages/beautiful_ai_ui_catalog/build/diagnostics/live-os-ime`. At recording,
the root-owned manual page was `http://127.0.0.1:63118/`, server session `69030`.
This is a local release build; the URL is temporary and its lifecycle belongs to
the root task. No server stop was performed during archiving.

To make a separate replay from the repository root, without overwriting the
observed output:

```sh
cd packages/beautiful_ai_ui_catalog
mkdir -p build/diagnostics
cp ../../docs/beautiful-ui/diagnostics/live-os-ime-observer/live_os_ime_probe.dart \
  build/diagnostics/live_os_ime_replay.dart
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter build web --no-pub \
  --target=build/diagnostics/live_os_ime_replay.dart \
  --output=build/diagnostics/live-os-ime-replay
python3 -m http.server 0 --bind 127.0.0.1 \
  --directory build/diagnostics/live-os-ime-replay
```

Use the printed local address and actual native input. Record candidate/pre-edit
and commit events separately from ordinary trusted keyboard insertion; input
source identity alone does not prove the language mode or IME participation.

## Exportable handoff

The separate [exportable_live_os_ime_probe.dart](exportable_live_os_ime_probe.dart)
wrapper leaves the historical observer unchanged and adds **Save observed
trace**. Its actual download was verified in the
[source-5ed handoff record](../../quality_evidence/2026-09-04-5edbcab7-ime-handoff.md).
The download contains the observer's full current report (up to its existing
300-event retention limit); it does not generate input or accept an IME result.

Copy both Dart files into the same ignored build-source directory, then build
the wrapper as the target. The current live entry point is
`http://127.0.0.1:63120/`; use a fresh output directory and file for a new run.
