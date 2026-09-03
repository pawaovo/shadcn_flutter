# Prompt focus visual regression addendum — 2026-09-04

**All seven Prompt PNGs are byte-identical to their accepted September 3 images.**
The three selected headless cases passed in 31.54 seconds, with zero changed
images and zero rendering errors. Each fresh PNG and retained original was
independently hashed against the accepted review entry and the fresh exporter
manifest. The prior direct visual observations carry forward by image identity;
no newly viewed images are claimed. The earlier evidence and PNGs are unchanged.

This replay checks the appearance after assigning the editor `groupId: _tapGroup`
to match its surrounding Prompt tap region. Product code and the exporter were
not changed during the replay.

| Selected profile | Exported Prompt states | Matching PNGs |
| --- | --- | --- |
| Expanded, light, high contrast, English, 100%, normal motion | Prepared, Send keyboard focus, Send held mouse, source options | 4/4 |
| Expanded, dark, normal contrast, English, 100%, reduced motion | Prepared | 1/1 |
| Compact, dark, high contrast, Arabic RTL, 200%, reduced motion | Prepared, source options | 2/2 |

All three runs used the existing opt-in P3 exporter with `--only-module prompt-bar`
and an exact `--only-profile`. Their source inventories were identical, remained
stable during capture, and all pinned font/license hashes matched the accepted
baseline. Other previously changed sources in the inventory are recorded in the
JSON; this addendum evaluates only Prompt.

The light focus and held-pointer images exercise **Send**, not the model menu.
The exporter explicitly removes Send focus before its held-mouse capture. The
model-button/Escape focus contract is covered separately by the already completed
headless Catalog regression: Linux, macOS and Windows all passed Down+Tab,
Down+Enter, non-submission, model dismissal, and retained draft/editor focus.
These PNGs alone do not prove that behavioral fix or any real platform input.

The [JSON addendum](2026-09-04-prompt-focus-visual-addendum.json) records all seven
PNG hashes, three exporter commands/manifests, source identity, font hashes and
behavior-test identity. Generated artifacts remain in the ignored directory
`packages/beautiful_ai_ui/build/p3_visual_acceptance/2026-09-04-prompt-focus`.

Reproduce from `packages/beautiful_ai_ui`, using the existing verified review fonts:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export FLUTTER_BIN=/Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter
python3 tool/release_review/export_p3_acceptance.py --only-module prompt-bar \
  --only-profile expanded-light-hc-1x-english-normal \
  --output build/p3_visual_acceptance/2026-09-04-prompt-focus/expanded-light
python3 tool/release_review/export_p3_acceptance.py --only-module prompt-bar \
  --only-profile expanded-dark-normal-1x-english-reduced \
  --output build/p3_visual_acceptance/2026-09-04-prompt-focus/expanded-dark
python3 tool/release_review/export_p3_acceptance.py --only-module prompt-bar \
  --only-profile compact-dark-hc-2x-arabic-reduced \
  --output build/p3_visual_acceptance/2026-09-04-prompt-focus/compact-arabic
```

Acceptance is limited to these specified-font headless fixtures. Native font
fallback, OS input/IME, W3C browser input, assistive technology, physical devices,
and native frame-time or memory budgets require their separate evidence.
