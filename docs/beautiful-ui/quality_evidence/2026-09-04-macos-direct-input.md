# Bounded macOS direct-input observation at f39faedf

The ordinary release Catalog was built from
`f39faedfcb0e09f57e29fd8edbfab98b808164b9`, with `CATALOG_REAL_FILES=true`.
This observation used the native Computer Use API, not Flutter's test text-input
channel. It does not accept OS IME, full clipboard behavior, or screen-reader
speech.

| Artifact | SHA256 |
| --- | --- |
| Release `Contents/MacOS/beautiful_ai_ui_catalog` executable | `b0c77ae8947ae7f81d46e358378c7118538442d5b766e11b104ca0ff268ee990` |
| `/tmp/beautiful-f39faedf-macos-build.log` | `c62bf0f86a226df478ed12a66a1656ceb6c24d20923e7db9beb6f62dd2be2a34` |

The application PID was 89844 and its exact executable path was verified before
cleanup. These hashes cover the named files, not an independently inventoried
complete application bundle. Screenshots and native AX responses were observed
in the task's tool transcript; no standalone image archive is claimed here.

## Observed input

The initial selected application was not the actual foreground process. AX
Raise did not change that state. Opening the already-running exact Release app
returned success; `lsappinfo front` then identified
`dev.beautifulai.beautifulAiUiCatalog`, PID 89844. The desktop was unlocked.
Earlier unsuccessful input observations must not be treated as product defects
without establishing this foreground condition.

Native Tab moved the visible focus ring among controls. Return changed Motion
from system to reduced; subsequent screenshots and AX text confirmed the new
label. This was not a fresh-launch, exact-first-Tab Theme test: earlier input
attempts had already occurred. The generic AX focused-element line alone did
not identify the Flutter control with the visible focus ring.

Further Tab traversal brought the Search editor into view. Typing `waffle`
through the native API displayed that exact value and reduced the visible
results to `Find waffle cone suppliers`. This bounded keyboard typing/filter
behavior was observed successfully.

## Unaccepted paste attempt

With Search focused, native `super+a` was followed once by the Computer Use
clipboard-preserving paste operation for `cold-chain`. It returned:

```text
Computer Use server error -10005: Timed out waiting for the application to read the clipboard
```

A later AX response reported the focused text field as `cold-chain`, but the
subsequent screenshots still displayed `waffle` and the old filtered result.
The inconsistent observations do not establish a completed application paste
or a root cause. No repeated paste, fake clipboard bridge, input assertion
change, or OS IME acceptance followed. The owned Catalog process was then
terminated after its exact executable identity was checked; unrelated user
applications were left running.
