# Local release artifacts at 5edbcab7

The Catalog macOS Release build completed successfully at
`5edbcab7edc5c058cf9354c6109df917846fb4e8`. The application is **50.4 MB**;
its main executable contains both **x86_64 and arm64**. The bundle reports
`dev.beautifulai.beautifulAiUiCatalog`, version `0.1.0`, build `1`, and a
minimum macOS version of `12.0`. Deep strict code-signature verification passed.
This is a local build. After desktop interaction became available, the new
bundle opened with the expected Catalog title and one native click changed
`Theme: system` to `Theme: light`. Its owned process then stopped before the
separate profile capture. This scoped smoke test does not establish full GUI
acceptance, notarization or a new performance result.

The checked delivery ZIP is available at:

`packages/beautiful_ai_ui_catalog/build/deliverables/beautiful-ai-ui-catalog-macos-5edbcab7.zip`

It contains the application bundle, preserving its framework symlinks. All
**333 file and symlink entries** were read from the ZIP and compared with their
original bytes and SHA-256. The ZIP is **21,245,687 bytes**, SHA-256:

```text
bf290f03944a428b76a8ea0a80b12944512fa834eb40c3b159113bf863f0fff9
```

The adjacent `beautiful-ai-ui-catalog-macos-5edbcab7.json` preserves the full
bundle inventory and the selected 67-file source manifest, which matched before
and after the build. The [compact committed record](2026-09-04-5edbcab7-local-artifacts.json)
binds the ZIP, full local manifest and build log to the source commit. The
selected source manifest is not a complete SDK or external dependency inventory.

Build from `packages/beautiful_ai_ui_catalog` with the existing locked workspace:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /opt/homebrew/bin/mise exec -- flutter build macos --release --no-pub
```

The current local Web preview remains at `http://127.0.0.1:8096/`. Its served
`main.dart.js` was read over HTTP and matched the source-153 release output,
SHA-256 `d459756e5a146b4dfdd19f57351cc8a3b76159f14ba57e52099d5ea0786eb5e1`.
There is no runtime diff from `153412b3` to `5edbcab7` in the public library,
Catalog Dart/assets, macOS project, Catalog pubspec or lockfile; the intervening
changes concern CI setup, diagnostic tests and evidence documentation.

The independent Linux reader evidence remains available in
`packages/beautiful_ai_ui_catalog/build/deliverables/linux-79fbcdd1-orca-evidence.zip`.
Its 56 raw files retain their original hashes and scope in the
[three-task acceptance record](../diagnostics/linux-sdk-runtime-build/evidence/catalog-79fbcdd1-orca.md).
The ZIP is **1,675,366 bytes**, SHA-256
`00e271023c951c371df85d23395e36e7af20e98a3b6d9ebbf4cef5f98d28ea1c`.
Neither local artifact upgrades the platform support or registry status.
