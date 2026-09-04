# Isolated full Linux GTK/engine build

This directory builds the actual official GTK embedding with the reviewed
[SDK accessibility patch](../linux-sdk-accessibility-patch/README.md).
It does not replace the existing source-unit proof or claim that a compiled
library has already passed Catalog/Orca acceptance.

The plan pins Flutter `4cf24164269a5ebf0c16a028a00727d0e77bbb05` and its original
DEPS. Bootstrap depot_tools uses that DEPS file's exact revision
`580b4ff3f5cd0dcaa2eacda28cefe0f45320e8f7`. Documented gclient switches disable
non-Linux SDKs, web tools and remote execution; dependency versions are not
changed. Stock Linux hooks and their required sysroots are retained.

Native Linux arm64 is the first route. The pinned DEPS explicitly supplies
arm64 Clang, GN, Ninja and Dart SDK packages; all four precise versions resolved
successfully through the official CIPD API before any bulk download. The
availability record is in `arm64-package-availability.json`. The GN command
explicitly sets Linux and arm64 because a generic host build defaults to x64.

Use an unused, owned container name and an empty work directory. Example from
the repository root, after coordinating the heavy-work window:

```sh
SDK_BUILD_PLAN="$PWD/docs/beautiful-ui/diagnostics/linux-sdk-runtime-build"
SDK_BUILD_PATCH="$PWD/docs/beautiful-ui/diagnostics/linux-sdk-accessibility-patch"
SDK_BUILD_WORK=/absolute/empty/disposable/work
SDK_BUILD_CONTAINER=beautiful-flutter-gtk-build-4cf-arm64

docker build --platform linux/arm64 -t beautiful-flutter-gtk-builder:4cf-arm64 "$SDK_BUILD_PLAN"
docker run --name "$SDK_BUILD_CONTAINER" --platform linux/arm64 \
  --cpus 4 --memory 8g --memory-swap 8g --pids-limit 2048 -d \
  --label beautiful.owner=linux-sdk-runtime-build \
  -v "$SDK_BUILD_WORK:/work" -v "$SDK_BUILD_PLAN:/plan:ro" \
  -v "$SDK_BUILD_PATCH:/proof:ro" beautiful-flutter-gtk-builder:4cf-arm64
docker exec "$SDK_BUILD_CONTAINER" sh /plan/install_dependencies.sh
docker exec "$SDK_BUILD_CONTAINER" python3 /plan/build_engine.py all
```

There is no global SDK, Docker socket, user home or privileged mount. Logs and
atomic status records stay in the owned work directory. `bootstrap`, `sync`,
`configure` and `build` can also be invoked separately; a failed command keeps
its original log and does not become a successful build. No acceptance test is
retried by this script.

The selected target is debug/unoptimized with LTO and test binaries disabled.
Ninja and the official shared toolchain pool are limited to four jobs, within
the container's 4 CPU / 8 GiB limits. This is for real native behavior diagnosis,
not performance acceptance. The official GTK archive, patched Dart platform,
prebuilt Dart SDK archive and sky package are initial targets; actual missing
Flutter local-engine artifacts will be handled from concrete build errors.

After a real library exists, a separate Catalog bundle must use it through
Flutter's explicit local-engine mechanism, record the source and bundled-library
hashes, then run the unchanged real AT tasks in an explicitly authorized isolated
environment. The current CI-only pilot guard must not be bypassed by pretending
that a local container is GitHub Actions. The unit proof's engine link stubs,
private-symbol access, vtable replacement and manufactured AT events are never
part of this runtime build.

For a separately cloned and pinned Catalog fixture, populate the isolated SDK's
official universal package cache before its locked `pub get`. The SDK's official
`3.47.0` tag must peel to the pinned framework commit; `build_engine.py` fetches
and verifies that tag. A tagless clone reports `0.0.0-unknown`, while the generated
engine `sky_engine` package alone does not populate the Flutter tool's SDK cache.
Neither condition should be worked around by changing a package constraint or
lockfile.

```sh
docker exec "$SDK_BUILD_CONTAINER" /work/flutter/bin/flutter --suppress-analytics \
  precache --universal --no-linux --no-web --no-windows --no-macos --no-ios --no-fuchsia
docker exec "$SDK_BUILD_CONTAINER" sh /plan/install_runtime_dependencies.sh
```

The explicit runtime manifest binds the container identity, fixed app source,
reviewed SDK patch, build records, actual generated library and canonical local
engine build command. `probe_catalog_orca_linux.py --build-only
--sdk-runtime-manifest ...` records the real debug Catalog bundle; the live mode
also hashes the library actually mapped in the Catalog process. This remains an
isolated debug diagnosis, separate from ordinary release CI and human acceptance.

`trace_catalog_inspector.py` is a separate diagnostic for a native inspector
timeout. It imports the fixed fixture, preserves its build/source checks and
three tasks, and inserts before/after JSONL records around the existing read-only
AT-SPI calls. Every record is flushed immediately. No native object is stringified
for tracing. The original eight-second snapshot deadline, tree traversal and
acceptance predicates are unchanged; tracing adds overhead, which must be
considered when interpreting timing differences. A traced result never replaces
the original attempt.

```sh
docker exec "$SDK_BUILD_CONTAINER" timeout 270s dbus-run-session -- \
  xvfb-run -a -s '-screen 0 1440x1200x24' \
  python3 /plan/trace_catalog_inspector.py \
  --catalog-root /work/catalog \
  --sdk-runtime-manifest /work/validation/sdk-runtime-manifest.json \
  --build-provenance /work/validation/catalog-build/build-provenance.json \
  --output /work/validation/fresh-inspector-diagnostic --seconds 240
```

Each diagnostic output contains its exact script, the original probe and runtime
binding hashes, individual inspector traces, the unchanged task reports and
owned-process cleanup evidence. The source unit tests remain a separate proof;
their link stubs are never linked into this Catalog bundle.
