# Isolated hosted consumer evidence

Date: 2026-09-03 (Asia/Shanghai)
Toolchain: Flutter `3.47.0`, Dart `3.13.0`, local macOS arm64 headless tests
Dependency: unmodified hosted `shadcn_flutter 0.0.54`
Status: failing baseline reproduced; corrected publication surface passes

## Executed boundary

[`tool/verify_hosted_consumer.py`](../../../tool/verify_hosted_consumer.py)
created a fresh directory outside the repository for each run. The consumer
had no workspace configuration or `dependency_overrides`, explicitly pinned
`shadcn_flutter: 0.0.54`, and resolved it from `https://pub.dev` into a fresh,
disposable `PUB_CACHE`. Existing package caches and SDK files were not patched.

The unpublished Beautiful AI UI package was consumed through a separate
runtime-publication-surface copy containing its `lib/`, pubspec, and package-root
README, changelog, LICENSE and NOTICES when present. Only the temporary copy's
`resolution: workspace` directive was removed. This is development-snapshot
normalization for isolation, not a claim that pub.dev strips that field from
uploaded archives. No sibling shadcn package was copied into the consumer.

Both runs verified the lockfile's hosted source, exact version and archive
digest, checked package-config locations, and compared all **209 runtime/source
files** from the installed dependency with the official archive. Its root
contains LICENSE and has no NOTICES file. The approved official archive SHA-256
was identical in both runs:

```text
403a9e790447dc4b6bae73a810d7ffa52baece4d7b29b32de56d0dd769be080e
```

## Before and after

The baseline used a package copy frozen before the adapter compatibility and
portable-NOTICES changes. The corrected run copied the actual updated package.
Neither run substituted a modified hosted dependency.

| Check | Frozen baseline | Corrected package |
|---|---|---|
| Exact hosted resolution and 209-file archive comparison | Passed | Passed |
| Strict consumer static analysis | Passed | Passed |
| Minimal application using public package entry points | Passed | Passed |
| Atomic inherited theme after light-to-dark switch | Failed: expected dark, inherited shadcn theme remained light | Passed |
| Theme/state/focus observation sequence | Stopped at the real theme failure | 12 observations passed |
| Complete generated expected notice labels | 4 / 13 | 13 / 13 |
| Real production `LicenseRegistry` probe | Failed: nine complete labels missing | Passed: all 13 complete labels |
| Overall script exit | 1 | 0 |

The theme fixture uses only public package imports. Four light/dark/high-contrast
transitions are checked immediately, at 75ms and at 175ms. Public Beautiful AI
UI tokens and inherited shadcn theme, default text and icon values must agree.
The same ordinary-keyed consumer State and Beautiful Search controller, draft,
selection and focus must survive each transition.

The baseline lacked complete notices for Bootstrap Icons, Feather-derived
Lucide icons, Geist and Geist Mono modern/legacy families, Lucide, Radix Icons,
and flag-icons. The updated Beautiful AI UI publication copy itself carries
the complete NOTICES file, with SHA-256:

```text
30ea1bec73647df83b3716f1107ab27a56c945ec4cc2693b8e1cdc13768854e7
```

Flutter generated the consumer's actual `build/unit_test_assets/NOTICES.Z`;
the production-binding probe loaded it through `LicenseRegistry` without
synthetic entries or a replacement asset loader. Expected bodies came from
the independent audited inventory and preserved license sources. The corrected
generated artifact SHA-256 is:

```text
803026de97a191d81e842aedf1285d2daa52c68184f8a5ea4cae65d8d076995f
```

That artifact hash is specific to this resolved consumer and toolchain. The
gate checks complete notice contents rather than requiring every future
consumer to reproduce this exact compressed hash.

## Raw results and reuse

- [Baseline JSON](./hosted-consumer-before.json), [actual theme failure](./hosted-consumer-before/public-integration-and-atomic-theme.txt), and [missing-license probe](./hosted-consumer-before/production-license-registry.txt).
- [Corrected JSON](./hosted-consumer-after.json), [public integration/theme tests](./hosted-consumer-after/public-integration-and-atomic-theme.txt), and [production registry test](./hosted-consumer-after/production-license-registry.txt).
- [Corrected consumer lockfile](./hosted-consumer-after/pubspec.lock) and [package-config snapshot](./hosted-consumer-after/package_config.json). Their temporary paths record the inspected locations; the disposable runs were cleaned up.

Run from the repository root, supplying an absolute executable because the
temporary consumer does not inherit the repository's mise configuration:

```sh
python3 tool/verify_hosted_consumer.py \
  --flutter /Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter \
  --output artifacts/hosted-consumer.json
```

Each Flutter command has a bounded timeout. The script exits nonzero on source,
resolution, analysis, integration, theme/state, notice or registry failures.
The [fixture README](../../../tool/hosted_consumer/README.md) describes CI reuse
and the explicit version/hash update procedure.

This closes the observed dependency-portability gap for the declared minimum
hosted version on the recorded SDK. It does not publish either package,
replace archive packaging preflight, prove every later allowed dependency
version, or complete platform and screen-reader release acceptance.
