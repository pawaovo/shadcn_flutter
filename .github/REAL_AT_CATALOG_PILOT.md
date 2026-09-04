# Prepared Linux Orca pilot for three Flutter Catalog tasks

Status: **prepared, not executed against Flutter**. This is an independent
experimental manual workflow, separate from the product release gates. It deliberately
does not claim that three examples accept every component, other platforms,
or human screen-reader usability.

The existing real-Orca capability job in Actions run `33815199188` succeeded
on Ubuntu 24.04 with Orca 46.1, Speech Dispatcher 0.12.0-rc2 and eSpeak NG 1.51.
Its actual PCM contains 53,815 frames at 16 kHz, RMS 3977.041739085139. That
recording and its utterances belong to a **GTK fixture**. The record explicitly
leaves `application_acceptance` and `human_review` unaccepted. They cannot be
relabelled as Flutter results.

## Entry point and evidence boundary

[`scripts/probe_catalog_orca_linux.py`](./scripts/probe_catalog_orca_linux.py)
provides a build-only mode and a separate live mode. Both live modes refuse
non-Linux or non-GitHub-Actions execution; there is no local override. A safe
preview launches no GUI, AT, audio, build, or inspection process:

```sh
python3 -B .github/scripts/probe_catalog_orca_linux.py --describe
```

The build mode compiles the ordinary `lib/main.dart` release entry with
`--no-pub`, retaining its real widgets and demo behavior. It records repository
Catalog/Beautiful UI/shadcn source and asset hashes, native runner inputs,
dependency manifests/resolution, helper scripts, the compiler command and log,
Flutter version, Git HEAD, and hashes for every resulting bundle file. Sources
must match before and after compilation; live mode verifies those source and
binary inventories before launch and after the tasks. Package-cache dependency
contents are not individually inventoried; locked versions/resolution and the
compiled bundle remain explicit evidence.

Live mode reuses the existing `Probe` service setup and owned-process cleanup
helpers. It first runs the real GTK capability preflight with a private X11/
D-Bus session, PulseAudio null sink, Speech Dispatcher and the real eSpeak NG
backend. It then stops its owned GTK fixture and launches the compiled Catalog
in that **same running Orca/backend session**. Preflight artifacts retain their
separate fixture scope.

The Catalog native tree is read through GI AT-SPI and restricted to the actual
Catalog process ID. AT-SPI is an observation source only. The script contains
no `grabFocus`, accessibility `doAction`, `setText`, or selection mutation call.
Tab/Space/Return and query characters come through real X11 keyboard events.
Targets are reached by bounded Tab traversal and observed focus, not coordinates
or a hard-coded number of tabs.

At every reader checkpoint, the script first observes at least 0.5 seconds of
actual silent PCM and 0.6 seconds without a new speech-output line; a fixed sleep
is insufficient. It then sends desktop-layout `KP_Enter`, requires
the real Orca log to name the **Basic Where Am I handler**, and requires a
corresponding expected `SPEECH OUTPUT` phrase strictly after that handler.
A separate PCM/WAV clip captures
the isolated real audio output; the checkpoint requires sufficient non-silent
post-key samples, subsequent measured silence, and a sink-input inventory
containing only `speech-dispatcher-espeak-ng`. The report records the command's
PCM byte offset and both quiet boundaries; spoken words still require a listener.
The raw PCM retains the quiet baseline, while the WAV starts at the command's
recorded byte offset and matches the reported post-key frame statistics.
No text is submitted to any synthesis API. It also checks application state
again after the reader command, so an unconsumed `KP_Enter` that accidentally
activates the Flutter control cannot count as a successful read.

Orca documents desktop `KP Enter` for Basic Where Am I; the handler string is
additionally confirmed by the successful installed Orca 46.1 fixture log.
[Orca reading commands](https://help.gnome.org/orca/commands_reading.html),
[Where Am I behavior](https://help.gnome.org/orca/howto_whereami.html).
The process filter uses AT-SPI's actual accessible process ID.
[AT-SPI process-ID API](https://gnome.pages.gitlab.gnome.org/gtk/atspi2/method.Accessible.get_process_id.html).

## Exactly three representative tasks

The execution order follows the page's likely forward traversal: Theme,
Thinking disclosure, then Search. The page can have several columns, so every
Tab position is verified rather than inferred from the order in this table.

| Task | Actual keyboard operation | Required application result | Reader checkpoints |
|---|---|---|---|
| Theme | Reach `Theme: system`; Space | Focused control becomes `Theme: light` | Read the new theme label with real Orca |
| Thinking disclosure | Reach `Hide steps thinking details`; Space; later Space again | Expanded state becomes false and exactly one instance of the trace disappears; expanding restores both | Read the collapsed and restored controls |
| Search | Reach `Search flavors`; Ctrl+A, type `cone`; Tab to the sole result; Return | Only `Find waffle cone suppliers` matches; choosing it commits that exact full title to the focused input | Read the focused result, then the committed input |

The four Thinking variants repeat the same trace labels. The pilot records
the original count of `Reading flavor briefs`, requires one fewer after this
single instance collapses, and requires restoration after expansion. It does
not require all four instances' labels to disappear. Incomplete/erroring or
truncated native trees are rejected before any negative/count-based assertion.

Search's Catalog `onSelected` callback intentionally performs no navigation.
The actual selection result is the full selected title committed to its input.
ArrowDown alone would leave keyboard focus in that input; the pilot therefore
Tabs to the result before asking Orca to read it.

Theme uses its normal button instead of Meta+D: on Linux the latter can map to
Super+D and be intercepted by a desktop window manager.

## Manual one-time disposable cloud execution

Do not run this on a user's local desktop. The root task must first authorize
one temporary Ubuntu 24.04 execution and choose the exact checkout containing
the new independent script. The separate
[`beautiful_ai_ui_orca_catalog_pilot.yml`](./workflows/beautiful_ai_ui_orca_catalog_pilot.yml)
has only a `workflow_dispatch` trigger and one Ubuntu job. It does not run on
product branch pushes or modify the existing acceptance workflows.

The repository default branch is `product/main`. After the workflow and scripts
are committed there, set `PILOT_SOURCE_SHA` to the intended full 40-character
commit and dispatch once:

```sh
gh workflow run beautiful_ai_ui_orca_catalog_pilot.yml \
  --repo pawaovo/shadcn_flutter --ref product/main \
  -f source_sha="$PILOT_SOURCE_SHA"
```

The workflow checks out that exact commit, verifies its identity, and records
the runner image and source SHA in an additional artifact directory. Build and
live execution share one job so absolute bundle paths in the provenance remain
valid. The job timeout is 25 minutes, with separate 12-minute build and 5-minute
live step limits. All three artifact directories are uploaded even after a
failure. A manual workflow's run metadata and its selected source commit can
differ; confirm the recorded runner and build provenance SHA as well as the
workflow run SHA when attributing results.

Use Flutter 3.47.0 and system `/usr/bin/python3`, which sees Ubuntu GI/AT-SPI.

Install the same real AT dependencies as the existing capability job, plus the
ordinary Flutter Linux build dependencies, in that disposable runner only:

```sh
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libstdc++-12-dev orca speech-dispatcher \
  speech-dispatcher-espeak-ng espeak-ng pulseaudio pulseaudio-utils \
  python3-gi python3-pyatspi python3-speechd gir1.2-gtk-3.0 \
  at-spi2-core dbus-x11 xvfb xauth xdotool
flutter pub get --enforce-lockfile
/usr/bin/python3 -B .github/scripts/probe_catalog_orca_linux.py \
  --build-only --flutter "$(command -v flutter)" \
  --output artifacts/catalog-orca-build
timeout 270s dbus-run-session -- xvfb-run -a \
  -s '-screen 0 1440x1200x24' \
  /usr/bin/python3 -B .github/scripts/probe_catalog_orca_linux.py \
  --build-provenance artifacts/catalog-orca-build/build-provenance.json \
  --output artifacts/catalog-orca-three-tasks --seconds 240
```

Keep an outer job timeout and upload both artifact directories even when any
step fails. A timeout, killed process, missing evidence, source drift or cleanup
failure is not success. Every build/live output directory must be fresh; the
script refuses to overwrite a previous run's evidence.

The helper runs its own reader processes without `--replace`, uses the existing
private audio/backend configuration, and cleans up complete owned process
groups even if their leaders exited. It does not stop a desktop's existing
reader or audio services.

## Artifacts, result interpretation and likely blockers

`catalog-report.json` separates task status from application and human acceptance.
Each successful task has six observed machine layers: native accessibility,
keyboard action, Orca command, utterance, synthesis and actual application result.
The report contains command timestamps, native before/after trees, the exact
reader/application/backend PIDs and per-command utterances. Each reader
checkpoint also has a command log and independent `.pcm`/`.wav` files. The
artifact manifest hashes every evidence file; the copied build provenance binds
the launched bundle. Partial preflight output and the last native tree remain
available on failure.

Exit 0 means only `three_task_machine_evidence_observed`. Both
`application_acceptance` and `human_review` remain `not_accepted`, and the
all-component and all-platform release booleans remain false. Exit 2 means one
or more machine layers were not observed. These explicit pilot statuses do not
alter the existing capability or product acceptance criteria.

Potential technical failures should be investigated from evidence, not hidden:

- **No Flutter native tree:** current Catalog enables `ENABLE_WEB_SEMANTICS`
  only under `kIsWeb`; there is no equivalent native compile flag. This pilot
  uses the actual Linux bridge/reader lifecycle, not the integration test's
  framework semantics lease. The pinned Flutter engine exposes its view through
  an ATK socket/plug and maps incoming semantics into native objects.
  [Pinned Flutter Linux view bridge](https://github.com/flutter/flutter/blob/4cf24164269a5ebf0c16a028a00727d0e77bbb05/engine/src/flutter/shell/platform/linux/fl_view.cc#L577),
  [Pinned semantics translation](https://github.com/flutter/flutter/blob/4cf24164269a5ebf0c16a028a00727d0e77bbb05/engine/src/flutter/shell/platform/linux/fl_view_accessible.cc#L144).
  A GTK-only tree or absence of `Theme: system` after the bounded startup wait
  remains a blocked Catalog run, with process/window/native-tree/Orca logs.
- **Theme/Motion focus semantics regression:** the original `_CatalogButton`
  excluded descendant Semantics without explicitly setting `focused` or
  `focusable`. A full-Catalog headless regression reached Theme by Shift+Tab,
  confirmed that its real FocusNode had focus, then failed because the produced
  SemanticsData reported `Tristate.none`. The minimal correction now exposes
  `focusable: true` and an independent actual-focus state updated by
  `onFocusChange`; the existing visual `onShowFocusHighlight` state is preserved.
  Both new tests passed for Tab/Space state changes, pointer activation and
  actual focus with highlighting suppressed, along with the existing keyboard
  navigation test. This fixes the reproduced framework semantics gap; it does
  not establish that the Linux bridge or Orca reads it correctly. The pilot
  still requires actual PID-scoped native focus and real reader evidence.
- **Composite disclosure focus or repeated trace mismatch:** preserve the raw
  focused-node paths, label, expanded state and exact trace counts. Do not
  collapse unrelated variants to make the assertion pass. For Thinking only,
  a genuinely focused, showing, same-PID strict descendant of the exact named
  button is valid control focus; both raw nodes remain in evidence. No ancestor
  Flutter View focus or fabricated focused flag is accepted. Theme and Search
  retain exact-node focus requirements.
- **Text output but missing speech:** inspect the command WAV and private
  PulseAudio/speechd logs. A `SPEECH OUTPUT` line alone cannot satisfy synthesis.
- **Reader key falls through:** the post-reader application-state check fails
  if Theme toggles twice or the disclosure reopens unexpectedly.

Before any human acceptance, a reviewer must listen to every task clip, confirm
understandable control names/roles/state feedback, and cross-check the actual
task outcome. Nonzero PCM and a matching transcript do not establish that human
judgment. This pilot does not cover touch AT, braille, other languages, devices,
or all twenty components.

Pilot preparation validation used Python AST/import checks, the safe
`--describe` mode, and recalculation of the already captured GTK PCM statistics.
The subsequent minimal Catalog focus fix was validated with the two headless
SemanticsData regressions in
[`catalog_button_focus_semantics_test.dart`](../packages/beautiful_ai_ui_catalog/test/catalog_button_focus_semantics_test.dart)
and the existing keyboard navigation test. No local GUI, Linux package
installation, native Flutter application build, or new speech synthesis was
performed. None of those checks substitutes for the pending real Orca run.
