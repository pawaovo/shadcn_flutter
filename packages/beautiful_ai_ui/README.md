# beautiful_ai_ui

An independent Flutter implementation of adaptive interface primitives for
AI-native products. The package uses `shadcn_flutter` as an internal behavior
and rendering foundation while owning its public models, theme, responsive
policy, interaction contracts, and accessibility behavior.

The package is under active development. Its first vertical slice is the
Beautiful UI-inspired Loading State.

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

## Design rules

- Public declarations do not expose `shadcn_flutter`-owned types.
- Widgets receive declarative data, state, and callbacks; networking and agent
  orchestration stay in the consuming application.
- Layout responds to available constraints, not device names.
- Touch, mouse, keyboard, screen-reader, text-scale, RTL, high-contrast, and
  reduced-motion behavior are part of the interface contract.

## Status

This is an independent implementation. It is not affiliated with or endorsed
by Beautiful UI, Turbo, or the `shadcn_flutter` authors. See the repository's
`THIRD_PARTY_NOTICES.md` and provenance manifests for source attribution.
