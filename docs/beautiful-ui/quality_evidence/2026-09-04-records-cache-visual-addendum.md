# Records Table cache optimization: targeted visual addendum

Date: 2026-09-04. Environment: macOS 15.7.9 arm64, Flutter 3.47.0, DPR 1.

**All three selected Records Table cases passed. Their seven exported PNGs
are byte-identical to the corresponding September 3 accepted images.** The
prior visual observations therefore remain applicable to these seven states.
No changed PNG required another direct `view_image` inspection. The original
[1,008-case / 127-image review](./2026-09-03-p3-visual-localization-temporal-review.md)
and its files were preserved.

The [machine-readable addendum](./2026-09-04-records-cache-visual-addendum.json)
records the exact new and baseline PNG paths and hashes, accepted observations,
three renderer manifest hashes, commands, source changes and limitations.
Each new file was hashed against its new manifest, the actual old PNG, and the
old accepted review entry. The old renderer manifest also still matches its
recorded SHA-256 `1c8fcbc5904aeba6efdbf971fb6dc6dc4a72eb0a113be7ce3dddab966f4e3fd7`.

| Target profile | Completed cases | Byte-identical PNG states |
|---|---:|---|
| `expanded-light-hc-1x-english-normal` | 1 | prepared, keyboard-focus, pointer-held, record-detail |
| `expanded-dark-normal-1x-english-reduced` | 1 | prepared |
| `compact-dark-hc-2x-arabic-reduced` | 1 | prepared, record-detail |

The existing opt-in exporter ran in its explicit single-module/single-profile
iteration mode. Each run exited 0, had no validation issues, and verified that
source/configuration/font hashes remained unchanged during capture. All three
runs share the same source inventory. The five fixed font, license and
provenance file hashes are unchanged from September 3; no fonts were downloaded
or added to distributed assets.

## Source change and behavioral checks

The Records implementation changes its lazy-list key only when actual row
membership/order changes, caches the visible-row index map, and reuses each
unchanged property header. A query still explicitly returns the row viewport
to the beginning. The implementation retains variable row heights, all rows
and properties, selection, configuration callbacks, and RTL behavior.

Records source SHA-256 changed from
`45433eaa4224837a6ba797bd9ba84c06ef0157174ab45bf785d33bf75c3ac2fb` to
`603cf1558bab2e34a08e85423e1e19d66bc0582e74adc20b66b3d9a0c330dafb`.
The full inventory also records a separate `search.dart` change since the old
capture. Search is not instantiated by these Records cases, and this addendum
does not assess or accept that change. Every other recorded source/configuration
hash matches the September 3 inventory.

Two focused tests in
[`p3_records_rebuild_cache_test.dart`](../../../packages/beautiful_ai_ui/test/release_review/p3_records_rebuild_cache_test.dart)
passed after a failing baseline reproduction. They retain the 1,000-row,
20-property workload, both numeric sorts and correct lazy first/last rows;
check that unchanged ordering preserves row/paragraph objects; and verify
filtering, selection and table identity reset. They also replace immutable
entries inside the same host List, check refreshed configuration callbacks,
and confirm cached descendants respond to dark theme and RTL changes,
including RTL ArrowRight reducing column width. Another targeted run of the
existing Records widget/semantics tests and the full P3 editors/tables temporal
file passed all 54 tests. Targeted analysis and diff checks passed.

These tests cover cache invalidation after inherited inputs change. The static
profile renderer starts a fresh fixture for each profile, so byte-identical
pictures alone do not establish that behavior.

## Reproduce the selected captures

Run from `packages/beautiful_ai_ui`, with the already prepared fixed review
fonts. The exporter validates their recorded hashes before use.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export FLUTTER_BIN=/Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter
python3 tool/release_review/export_p3_acceptance.py \
  --only-module records-table \
  --only-profile expanded-light-hc-1x-english-normal \
  --output build/p3_visual_acceptance/2026-09-04-records-cache/expanded-light
python3 tool/release_review/export_p3_acceptance.py \
  --only-module records-table \
  --only-profile expanded-dark-normal-1x-english-reduced \
  --output build/p3_visual_acceptance/2026-09-04-records-cache/expanded-dark
python3 tool/release_review/export_p3_acceptance.py \
  --only-module records-table \
  --only-profile compact-dark-hc-2x-arabic-reduced \
  --output build/p3_visual_acceptance/2026-09-04-records-cache/compact-arabic
```

## Scope limits

This is a three-case Records regression, not a fresh complete 1,008-case run
or a new inspection of all 127 images. It establishes the listed pictured
states using the fixed test fonts. It does not establish automatic platform
font fallback, native frame timing or memory budgets, other devices/platforms,
real assistive-technology acceptance, or final release acceptance. The original
native performance workload must assess the optimization independently.
