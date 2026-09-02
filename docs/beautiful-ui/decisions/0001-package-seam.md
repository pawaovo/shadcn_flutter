---
status: accepted
date: 2026-09-02
---

# Keep Beautiful AI UI behind an independent package seam

The Beautiful UI adaptation will live in a publishable sibling package named `beautiful_ai_ui`, with a separate non-published catalog, rather than adding twenty composite interfaces to `shadcn_flutter` core. Its stable public API uses Flutter-native data, state, and callbacks and neither exposes nor re-exports `shadcn_flutter` types; only an internal implementation layer depends on the upstream public barrel. This adds a package boundary and some internal mapping work, but preserves independent versioning and branding, confines upstream upgrades, avoids coupling consumers to a fork, and lets genuine core fixes be reviewed and contributed upstream separately.
