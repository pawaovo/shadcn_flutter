# Supplemental visual review export

This target renders small public-component scenarios for human review. It is
independent of the approved light/dark golden tests and does not update them.
The input is ordinary host-supplied data; there are no network clients, device
services, simulated AI timers, or Catalog UI dependencies.

From `packages/beautiful_ai_ui`, run:

```sh
python3 tool/release_review/export.py
```

The Pub workspace must already be resolved (`flutter pub get` from the repository
root). The script verifies that both local packages resolve to the source trees
whose files it hashes and executes the renderer with `--no-pub`.

If Flutter is not on `PATH`, supply its executable:

```sh
FLUTTER_BIN=/absolute/path/to/flutter python3 tool/release_review/export.py
```

The default destination is `build/release_review/`. `--output /path/to/folder`
selects another destination. During iteration, `--only approval-card,sidebar-nav`
limits the export; a partial run does not establish all-module coverage.

The script runs the explicit widget-rendering target, loads the same bundled
Geist Sans/Mono fonts as the existing goldens, and creates:

- One bounded PNG per module/state/profile: at most 4,096 logical pixels high,
  at DPR 1. The surrounding surface has 16dp padding on each side; widgets
  therefore receive a maximum width of 358dp or 1,248dp. Components with their
  own maximum width, such as Sidebar Nav, may use a smaller natural width.
- `captures.json`, the renderer's facts and any captured layout errors.
- `manifest.json`, containing image SHA-256 values, exact source/font hashes,
  actual PNG dimensions, Flutter/host details, resolved local package paths,
  and whether the sources stayed unchanged during capture. The hash inventory
  includes the shadcn Flutter implementation and workspace package resolution.
- `index.html`, a local index with links to full-size images.

The two profiles are:

| Profile | Viewport | Text | Direction | Contrast | Motion input |
|---|---|---|---|---|---|
| Compact light | 390dp | 200% | RTL | Platform high contrast | Platform `disableAnimations: true`, system policy |
| Expanded dark | 1,280dp | 100% | LTR | Platform high contrast | Package `reduced` policy |

The 20 module scenarios cover four Loading variants, two Thinking variants,
Code and Diff, both Task Rows variants, all three Insight chart kinds, and a
representative populated state for every other module. Public actions expand
Streaming sources, a Tool output, compact Flowchart conditions, and the
Insight comparison data. Additional captures show Approval submission,
Records full detail, and the compact Sidebar before opening. Selection Actions
uses a real seeded selection and a host-returned edit preview. These choices
are intentionally bounded rather than an exhaustive state matrix.

Export success proves that these fixtures rendered within the stated bounds.
Every generated image starts as `visual_review: unreviewed`. To record manual
acceptance, inspect the full-size images with an image viewer and record the
image paths, SHA-256 values, observations, and remaining dimensions separately
under `docs/beautiful-ui/quality_evidence/`. Do not infer visual acceptance from
a test result. If source files change while capture runs, the script fails and
the evidence must be exported again. Starting a new run invalidates the old
manifest and HTML index before image files are overwritten. Preparation actions
must hit their actual controls and satisfy explicit resulting-state assertions;
an unchanged page is not silently labeled as a later Insight page.

Static screenshots establish visible layout, text, controls, marks, chart
geometry, and selected states for the pictured snapshots. They do not prove
temporal reduced-motion behavior, hover/focus/pressed transitions, native
selection handles, screen-reader output, device performance, or real-device
accessibility. The RTL snapshots deliberately use English fixture text to
check layout direction; Arabic/Hebrew localization and glyph coverage require
separate evidence. Compact dark, expanded light, medium-width layouts, and all
combinations of the dimensions are outside these two profiles.
