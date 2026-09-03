# Isolated hosted consumer gate

From the repository root:

```sh
python3 tool/verify_hosted_consumer.py \
  --flutter /absolute/path/to/flutter/bin/flutter \
  --output artifacts/hosted-consumer.json
```

The command resolves Flutter to an absolute executable before entering its
fresh temporary directory. It uses a disposable `PUB_CACHE` and the official
`https://pub.dev` hosted source. Existing package caches, the Flutter SDK, and
repository package files are never patched. Each Flutter process has a
300-second timeout by default; `--timeout` changes that bound. The temporary
directory is removed on success and failure unless `--keep-temp` is requested.
The gate runs headless Flutter tests and does not launch desktop app windows.

The consumer explicitly depends on unmodified `shadcn_flutter 0.0.54` and a
separate copy of the Beautiful AI UI runtime publication surface. Its pubspec
contains neither workspace membership nor dependency overrides. The copy keeps
`lib/`, `pubspec.yaml`, and package-root `LICENSE`, `NOTICES`, `README.md`, and
`CHANGELOG.md` when present. Only the copy's `resolution: workspace` directive
is removed, allowing standalone resolution of the development snapshot. This
normalization is not a claim that the pub.dev upload process removes the field;
published hosted dependency archives can retain it. The gate is not a package
publication and does not replace `pub publish --dry-run` packaging checks.

The gate requires:

1. The approved official archive SHA-256, actual downloaded archive, pub lock
   source/version/hash, and installed public dependency runtime files agree.
   `package_config.json` must point to the disposable hosted cache and the
   isolated Beautiful AI UI copy, with no workspace fork substitution.
2. Strict consumer analysis and minimal public-barrel application integration
   succeed. Light/dark/high-contrast theme transitions expose matching public
   tokens, shadcn inherited colors, text, and icon colors immediately and at
   75ms/175ms. The same consumer State and Search editor controller, draft,
   selection, and focus must survive every transition.
3. Flutter's generated `NOTICES`/`NOTICES.Z` and the real production
   `LicenseRegistry` both contain every complete expected notice. Expected
   bodies are independently read from the audited inventory and preserved
   license sources, then copied into a plain JSON fixture. The probe does not
   inject license entries or replace Flutter's asset loader.

JSON evidence records the exact copied file hashes, hosted archive identity,
command results, and notices/registry checks. Adjacent text logs plus resolved
lock and package-config snapshots preserve the raw results. A nonzero exit
means this consumer gate failed, including when dependency resolution or a
bounded command fails.

For a real before/after comparison, `--library-source` accepts a previously
frozen package directory. Expected failures remain failures in the JSON; the
script never treats them as a successful release check. Changing the dependency
version requires an explicit `--shadcn-version` and approved
`--archive-sha256`, followed by the corresponding source/asset review.

This verifies the declared minimum public dependency on the current Flutter
SDK. It does not establish compatibility with every later version allowed by
the pubspec, every platform/renderer, or actual screen-reader task sequences.
