# beautiful_ai_ui

An independent Flutter implementation of adaptive interface primitives for
AI-native products. The package uses `shadcn_flutter` as an internal behavior
and rendering foundation while owning its public models, theme, responsive
policy, interaction contracts, and accessibility behavior.

The package is under active development. Its public module set includes
Loading State, Thinking, Context Cards, Recommendation Card, Search, Code
Block, Streaming Text, Approval Card, Tool Chips, Task Rows, Chat, Filter Table,
and Fine-tune Card. P2 implementation is available; release-level platform and
assistive-technology validation remains in progress.

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
output, or other content-sized components. The package does not virtualize
large record sets.

Recoverable P2 action failures use `BeautifulUiOperation.approval`, `taskRetry`,
`chat`, or `streaming` through the existing root handler. Supply localized
business errors through the corresponding widget/model fields. All package
labels are replaceable; demo streams and generated replies live only in the
Catalog.

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

This is an independent implementation. It is not affiliated with or endorsed
by Beautiful UI, Turbo, or the `shadcn_flutter` authors. See the repository's
`THIRD_PARTY_NOTICES.md` and provenance manifests for source attribution.

The repository's [parity manifest](../../docs/beautiful-ui/parity_manifest.yaml)
and [P2 evidence](../../docs/beautiful-ui/quality_evidence/2026-09-03-p2-modules.md)
track implementation and verification separately. Successful automated tests
do not by themselves establish stable support across all six platforms.
