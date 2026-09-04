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
