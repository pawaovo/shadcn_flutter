# beautiful_ai_ui

An independent Flutter implementation of adaptive interface primitives for
AI-native products. The package uses `shadcn_flutter` as an internal behavior
and rendering foundation while owning its public models, theme, responsive
policy, interaction contracts, and accessibility behavior.

The package is under active development. Its public module set includes
Loading State, Thinking, Context Cards, Recommendation Card, Search, Code
Block, Streaming Text, Approval Card, Tool Chips, Task Rows, Chat, Filter Table,
Fine-tune Card, Prompt Bar, Diff Table, Records Table, Sidebar Nav, Flowchart,
Insight Cards, and Selection Actions. All twenty composite implementations
are available. Release-level platform, assistive-technology, and performance
validation remains in progress; implementation coverage is not a stable
support or full-parity claim.

The current engineering pass has verified dependency font/media notices,
reviewed representative static states, and collected a historical native
macOS profile baseline for all seven P3 workloads. Final-source profiling
after the palette/muted-ticker and hosted-adapter fixes has not started;
desktop execution requires the user to unlock the local Mac. The dated
[release-readiness record](../../docs/beautiful-ui/quality_evidence/2026-09-03-release-readiness.md)
distinguishes these completed checks from remaining release gates.

## Quick start

Install `BeautifulUiScope` below an app widget that provides `MediaQuery`, then
use the strongly typed modules normally:

```dart
import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

WidgetsApp(
  color: const Color(0xff0285ff),
  builder: (context, child) {
    return const BeautifulUiScope(
      child: Center(
        child: BeautifulLoadingState(
          label: 'Preparing workspace',
          variant: BeautifulLoadingVariant.drive,
          elapsed: Duration(seconds: 12),
        ),
      ),
    );
  },
);
```

The consuming application owns elapsed time and other business state. The
module owns presentation, responsive layout, motion degradation, and
Semantics. `BeautifulLoadingVariant.surfer` never performs a network request;
the host may supply `surferMedia` only when it has an appropriately licensed
asset.

The remaining P1 modules follow the same ownership rule:

```dart
BeautifulThinking(
  variant: BeautifulThinkingVariant.steps,
  status: BeautifulThinkingStatus.working,
  workingLabel: 'Thinking',
  completedLabel: 'Thought for 4 seconds',
  items: const <BeautifulThinkingItem>[
    BeautifulThinkingItem(id: 'read', label: 'Reading project context'),
  ],
);

BeautifulSearch(
  items: const <BeautifulSearchItem>[
    BeautifulSearchItem(id: 'search', title: 'Search the workspace'),
  ],
  onSelected: (item) => openResult(item.id),
);

BeautifulCodeBlock.code(
  filename: 'main.dart',
  code: 'void main() {}',
);
```

Thinking receives caller-owned status and trace snapshots. Context source
actions, recommendation acceptance, search selection, and custom clipboard
writes leave through narrow callbacks. Recoverable asynchronous failures are
reported through `BeautifulUiScope.onFailure`; networking, URL launching,
agent orchestration, and persistence remain outside the package.

## Agent workflows

The P2 modules keep execution and accepted business state in your application:

| Widget | Data and actions |
|---|---|
| `BeautifulStreamingText` | Exact `BeautifulStreamingPart` text/citations, sources, lifecycle, and host callbacks for sources, feedback, follow-ups, and retry |
| `BeautifulApprovalCard` | Stable questions/options, initial answer seeds, and an asynchronous `onSubmit` accepting immutable answers |
| `BeautifulToolChips` | Immutable tool steps, execution status, output lines, and changed-file previews |
| `BeautifulTaskRows` | Immutable task rows with status/progress, capsules or list presentation, and an optional asynchronous retry callback |
| `BeautifulChat` | Conversation/message/response identities, host-owned messages, and asynchronous send/stop callbacks |
| `BeautifulFilterTable` | Task rows with caller-formatted dates/owners and a local status filter initialized once |
| `BeautifulFineTuneCard` | Accepted numeric/layout/type settings and `onChanged` proposals that your app can accept or reject |

Supply received streaming text exactly, including whitespace. A citation
refers to a source by stable ID. Update the same answer ID while receiving
content; use a new ID for a new generation or retry:

```dart
BeautifulStreamingText(
  id: 'answer-1',
  status: BeautifulStreamingStatus.complete,
  content: const [
    BeautifulStreamingPart.text('The inventory is ready. '),
    BeautifulStreamingPart.citation('inventory'),
  ],
  sources: const [
    BeautifulStreamingSource(
      id: 'inventory',
      title: 'Inventory report',
      detail: 'inventory.csv',
    ),
  ],
  onSourcePressed: (source) => openResult(source.id),
);
```

Text is immediately selectable when the host provides an `Overlay`, normally
through `WidgetsApp` or `MaterialApp`. Without an overlay it remains readable.
The source list provides full-size source actions; the text markers themselves
are descriptive. Copy uses Flutter Clipboard unless `onCopy` is supplied. The
internal streaming primitive is not a supported import surface.

Approval Card is a question workflow. It owns editable drafts and submits
through your callback. Set `autoAdvance: false` to require Continue or Send
after every selection:

```dart
BeautifulApprovalCard(
  id: 'release-check',
  autoAdvance: false,
  questions: [
    BeautifulApprovalQuestion(
      id: 'target',
      title: 'Where should this release go?',
      options: const [
        BeautifulApprovalOption(id: 'staging', label: 'Staging'),
        BeautifulApprovalOption(id: 'production', label: 'Production'),
      ],
    ),
  ],
  onSubmit: (answers) async {
    await saveAnswers(answers);
  },
);

BeautifulChat(
  conversationId: 'release-planning',
  messages: const [
    BeautifulChatMessage(
      id: 'intro',
      role: BeautifulChatRole.assistant,
      text: 'What would you like to prepare?',
    ),
  ],
  onSend: (text) => sendMessage(text),
);
```

For Chat, append or replace message snapshots in your application. While a
response is arriving, set `status: BeautifulChatStatus.responding` and provide
a `responseId`; `onStop` receives that ID. Enter sends, Shift+Enter inserts a
newline, and active IME composition never sends. The draft and reading position
survive normal updates; changing `conversationId` resets the draft and isolates
obsolete callbacks. Readers who scroll away from the bottom keep their place
and can use the latest action.

Chat and Approval custom fields support Flutter touch selection handles,
localized 48dp edit menus, keyboard shortcuts, and native accessibility
copy/cut/paste actions. Clipboard failures are reported through the root
handler. A failed cut preserves the draft; pending clipboard work cannot
change a replacement conversation or question, even if the new text is
identical.

Fine-tune Card uses a controlled settings snapshot. Keep `settings` in your
host state and replace it when accepting an edit:

```dart
BeautifulFineTuneCard(
  settings: settings,
  options: const [
    BeautifulFineTuneOption(id: 'compact', label: 'Compact'),
    BeautifulFineTuneOption(id: 'comfortable', label: 'Comfortable'),
  ],
  onChanged: (proposal) => setState(() => settings = proposal),
);
```

Construct `settings` with `BeautifulFineTuneSettings(fields: [...])` and
`BeautifulFineTuneField` entries containing stable IDs, labels, finite values,
inclusive bounds, and positive steps. Numeric drafts support direct input,
touch buttons, arrow keys, Shift acceleration, pointer scrubbing, and
assistive adjustment. Invalid/composing drafts remain editable; Escape restores
the accepted value. A new widget key starts the Edited comparison for another
object. A null `onChanged` disables editing.

Filter Table's `initialStatus` seeds a local filter once; `onFilterChanged`
reports user changes without controlling that filter. Recreate the widget with
a different key to reset it. Compact and medium widths show cards; expanded
widths show four columns. Provide a scrollable parent for long tables, tool
output, or other content-sized components. Filter Table does not virtualize
large record sets; the separate Records Table provides a bounded lazy viewport.

Recoverable P2 action failures use `BeautifulUiOperation.approval`, `taskRetry`,
`chat`, or `streaming` through the existing root handler. Supply localized
business errors through the corresponding widget/model fields. All package
labels are replaceable; demo streams and generated replies live only in the
Catalog.

## Composition, data, and editing

The P3 modules follow the same host-owned business-state rule. Their approved
[component contracts](../../docs/beautiful-ui/p3_contracts.md) define adaptive
presentations, workloads, and the source features each module retains.

| Widget | Public models and integration |
|---|---|
| `BeautifulPromptBar` | `BeautifulPromptSource`, `BeautifulPromptCommand`, `BeautifulPromptModel`, `BeautifulPromptAttachment`, and immutable `BeautifulPromptSubmission`; host send/file/dictation/connection callbacks |
| `BeautifulDiffTable` | `BeautifulDiffColumn` and immutable `BeautifulDiffRow` before/after maps; `onApply` receives the included changed-row IDs |
| `BeautifulRecordsTable` | `BeautifulRecordColumn`, `BeautifulRecordRow`, `BeautifulRecordCell`, tools and property configuration; host save/add/run/cell callbacks |
| `BeautifulSidebarNav` | Workspaces, primary destinations, and recents with host-selected IDs; navigation, new chat, and workspace callbacks |
| `BeautifulFlowchart` | Validated `BeautifulFlowchartData` with DAG nodes, edges, conditions, and fields; `onChanged` proposes the complete next snapshot |
| `BeautifulInsightCards` | `BeautifulInsightPage` containing comparison, anomaly, or allocation charts; page/metric/segment selections remain host controlled |
| `BeautifulSelectionActions` | Host document identity and text; `BeautifulSelectionRequest` carries the precise native range, and `BeautifulSelectionEdit` carries the proposed replacement |

Prompt Bar owns its local draft and attachment descriptors. `initialDraft`
and `initialAttachments` seed a new `composerId`; the model and source
connection state remain controlled. File picking, microphone permission,
dictation, and submission are real host integrations:

```dart
BeautifulPromptBar(
  composerId: 'planning',
  variant: BeautifulPromptBarVariant.rounded,
  sources: const [
    BeautifulPromptSource(id: 'docs', label: 'Project docs'),
  ],
  commands: const [
    BeautifulPromptCommand(id: 'summarize', label: 'summarize'),
  ],
  onAttach: () => chooseAttachmentDescriptors(),
  onSend: (submission) => submitPrompt(submission),
);
```

Typing `@` or `/` opens lazy suggestions with arrow navigation, Enter/Tab
selection, and Escape dismissal. Choosing a command inserts text. IME
composition is protected. Successful send clears only the unchanged submitted
draft and its attachment entries; new edits or reattached files survive.
`onStopDictation` stops the host's current dictation operation. The package
does not open a microphone, file picker, or network connection itself.

Diff Table infers additions, removals, modifications, and unchanged context
from exact host-formatted string maps. Inclusion choices span every page:

```dart
BeautifulDiffTable(
  id: 'proposal-1',
  title: 'Proposed inventory change',
  columns: const [BeautifulDiffColumn(id: 'name', label: 'Name')],
  rows: [
    BeautifulDiffRow(id: 'new-item', after: {'name': 'New item'}),
  ],
  onApply: (includedIds) => applySelectedChanges(includedIds),
);
```

Pages default to 20 records and accept at most 100. Compact layouts show
change cards; expanded layouts align before/after fields. Records Table
instead uses a lazy vertical viewport, with locally cached search/sort and
selection plus column pin/hide/width controls. Its default viewport height is
480dp. Provide an outer scrollable for property and detail disclosures. Save,
add, and run callbacks submit proposals; only accepted host snapshots change
properties or cell values. The documented target is 1,000 rows and at most
20 columns, without a spreadsheet formula engine.

Sidebar Nav adapts to drawer, rail, and expanded presentations. Use
`presentation` to choose the mode explicitly when a larger page gives the
widget only a narrow navigation lane. The default expanded width is 288dp
and height is 600dp; recents are lazy. Query, focus, and list position survive
presentation changes. All selected IDs and routing remain in the host.

Flowchart accepts a small DAG of at most 24 nodes and 48 edges. Condition and
position edits propose a complete `BeautifulFlowchartData` through
`onChanged`; retain it in host state to accept the change. Expanded mode
offers pan, 1–2× zoom, drag, and keyboard movement. Compact mode uses editable
ordered steps. A null callback leaves editing read-only while navigation
remains available. Invalid endpoints, cycles, and out-of-range graph data
are rejected.

Insight Cards requires the accepted `selectedPageId`. The selected anomaly
metric and allocation segment are contained in their typed chart snapshots.
Accept selection callbacks by replacing the relevant host snapshot. Charts
use supplied numeric values and formatted labels, provide point inspection,
and expose full text data on request. Only the selected chart is painted;
there is no autoplay or generated time series.

Selection Actions uses actual native read-only text selection. Its anchored
toolbar and in-flow preview offer the same request and acceptance operations.
An optional `initialSelection` seeds a precise Flutter `TextSelection` once
per document identity. Requests preserve exact UTF-16 offsets and whitespace:

```dart
BeautifulSelectionActions(
  documentId: documentId,
  text: documentText,
  onRequest: (request) => requestSelectedEdit(request),
  onApply: (edit) {
    if (edit.request.documentId != documentId ||
        edit.request.baseText != documentText) {
      throw StateError('The document changed before this edit was accepted.');
    }
    setState(() => documentText = edit.updatedText);
  },
);
```

`onRequest` may return replacement or explanation text immediately or as a
Future. Explanation actions never replace content. Keeping a replacement
calls `onApply`; omitting it makes the surface preview-only. Native gestures,
keyboard selection, and clipboard controls use the shared guarded selection
infrastructure. The document viewport defaults to eight visible lines, with
internal scrolling for the 20,000-character workload target. Document/range/
instruction changes invalidate obsolete results without changing host text.

Recoverable P3 actions report `BeautifulUiOperation.prompt`, `diff`, `records`,
or `selection` through `BeautifulUiScope.onFailure`; clipboard errors continue
to use `clipboard`. No P3 callback result silently executes a model, writes a
database, applies a document edit, or changes controlled selections.

## Design rules

- Public declarations do not expose `shadcn_flutter`-owned types.
- Widgets receive declarative data, state, and callbacks; networking and agent
  orchestration stay in the consuming application.
- Layout responds to available constraints, not device names.
- Touch, mouse, keyboard, screen-reader, text-scale, RTL, high-contrast, and
  reduced-motion behavior are part of the interface contract.
- Interactive descendants disappear from focus and Semantics traversal when
  their disclosure is collapsed.
- Asynchronous actions de-duplicate pending activation and commit visual
  success only after the host callback completes.

## Status

The current local verification includes **528 library tests, 26 Catalog tests,
and strict analysis of both packages**. The macOS golden suite passed 12
checks, and 49 supplemental images across all twenty modules were individually
reviewed against the final frozen visual source. Ten current macOS image
hashes are recorded. The hosted-adapter fix changed no review/golden pixels;
the eight Linux candidates from run `33736546039` were reviewed and accepted.
Their strict Ubuntu comparison passed in run `33741053163`.

Filled actions derive a contrasting foreground from the theme. Selected
actions have a distinct fill/border, Approval checks use drawn paths, and
Sidebar's compact trigger accommodates enlarged text. Fine-tune and Insight
adjustable controls expose slider flags and native adjustment semantics.
These improvements have focused evidence; they do not replace complete
screen-reader, physical-device, localization, or temporal-motion review.

The final text-palette corrections make tested normal placeholder/metadata
pairs meet 4.5:1 and raise light accent text on its tinted background to
4.925:1. Shared actions also apply colors immediately when an ancestor mutes
tickers, preserving readable Flowchart buttons when themes change under
reduced motion. Four palette and three actual-paint regressions cover these
last fixes; the latest Wasm release build passed afterward.

The current typography uses verified inherited **Geist Sans and Geist Mono**.
No Inter or JetBrains Mono files are bundled. Exact source/runtime font hashes
and complete generated notices were checked, including a real 13-label
Flutter `LicenseRegistry` probe. Fresh JavaScript, Wasm, and macOS release
asset audits passed; the resource inventories remain authoritative for those
specific files and versions.

The publishable package includes its own `NOTICES`, preserving its complete
BSD/Beautiful UI MIT terms and the verified dependency asset notices. Flutter
therefore receives those notices when an independent application resolves
the hosted `shadcn_flutter 0.0.54`, without requiring this repository's sibling
package patch. The source audit checks both notice carriers. An
[independent consumer](../../docs/beautiful-ui/quality_evidence/hosted-consumer-after.json)
with a fresh dependency cache and no overrides verified the unchanged hosted
core, public integration/theme behavior, and all 13 required generated
notice/registry texts. The [license audit](../../docs/beautiful-ui/quality_evidence/2026-09-03-license-audit.md)
keeps this temporary publication-surface test separate from workspace checks
and from an actual package publication.
The [hosted-consumer record](../../docs/beautiful-ui/quality_evidence/2026-09-03-hosted-consumer.md)
also confirms 12 atomic theme/state/focus observations using the private
adapter, without changing the hosted dependency. Latest portable-source
Wasm and ordinary macOS release builds passed.

Before publishing from this repository, run the source notice audit and
separate hosted-consumer check from the repository root:

```sh
python3 tool/audit_dependency_assets.py --require-complete-provenance
python3 tool/verify_hosted_consumer.py --output /tmp/beautiful-ai-ui-hosted-consumer.json
```

The package's `LICENSE` and `NOTICES` both belong in the publication surface.
These checks validate that surface and its independently resolved dependency;
they do not publish it.

All seven bounded P3 workloads completed in historical profile baseline
`20260903T080855Z` on an M1
Pro/32 GiB machine, yielding 4,524 frame samples and 480 process RSS samples.
The sampled window was 1,728×963 logical pixels at DPR 2 and 120 Hz. The
[profile record](../../docs/beautiful-ui/quality_evidence/performance/2026-09-03-macos-profile/README.md)
reports measured peaks and limitations. Other platforms, repeated runs, and
agreed product frame/memory budgets remain to be assessed. That source
fingerprint predates the final palette, muted-ticker and hosted-adapter
changes. Final profile run 4 has not started because the Mac session is
locked and Computer Use requires manual unlock. The post-TickerMode Safari
visual recheck is also unfinished. Historical measurements remain historical.

The complete ordinary macOS Catalog journey and a native AX comparison have
passed. Third run `33742943774` completed with 11 successful jobs, one Apple
failure and no skips. Quality passed 410 behavior, 106 Semantics and 12 golden
checks (528 library total), 19 Catalog tests and 571 core regressions. Cloud
hosted-consumer checks again pass all 209 files, 12 theme observations and 13
complete required notices.

Launcher self-tests, simulator build and installation passed. Although
console VM discovery timed out and the driver did not attach, unified logs
prove the app and Catalog test ran. Teardown reported an active
`SemanticsHandle`, with no other body assertion failure recorded. Scoped
discovery and the iOS platform-handle baseline are being repaired with strict
leak checks. Earlier runs remain in readiness; no all-pass run is claimed.
All six platforms are **Partial**, and all 27 registry entries remain
`in_progress`.

This is an independent implementation. It is not affiliated with or endorsed
by Beautiful UI, Turbo, or the `shadcn_flutter` authors. See the repository's
`THIRD_PARTY_NOTICES.md` and provenance manifests for source attribution.

The repository's [parity manifest](../../docs/beautiful-ui/parity_manifest.yaml)
and [release-readiness evidence](../../docs/beautiful-ui/quality_evidence/2026-09-03-release-readiness.md)
track implementation and verification separately. Successful automated tests
do not by themselves establish stable support across all six platforms.
