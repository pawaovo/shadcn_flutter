# Isolated Flutter 3.47 Linux accessibility source patch

The [patch](./flutter-3.47.0-atk-name-expanded.patch) corrects two contracts in
the actual `fl_accessible_node.cc` source: dynamic accessible names publish a
GObject property notification, and Flutter's expanded tristate maps to ATK's
expandable/expanded states and change notifications. No Catalog component,
observer, global SDK installation or native parent helper is modified here.

The source is pinned to Flutter **3.47.0**, framework revision
`4cf24164269a5ebf0c16a028a00727d0e77bbb05`, whose engine version is
`5f77625673248ee5846fbcaf5d3e1a3878386fd7`. The original complete translation
unit has SHA256
`8fe18d11f896a26c3236c80411b7eaca25a7f755803f3e3cee19ada89a3a861f`.

## Actual native result

[The structured report](./evidence/report.json) records **10 tests: original
source 2 passed / 8 failed; patched source 10 passed / 0 failed**. Both binaries
compile the complete source unit and use actual GTK 3.24.41, ATK 2.52.0 and
GObject/GLib 2.80.0 in Linux arm64, built with Clang 18.1.3 and GTest 1.14.0.
The baseline exits 1 and the patched binary exits 0. Logs, GTest JSON, source
hashes, linked libraries and container provenance are in [evidence](./evidence).

The tests observe actual `notify::accessible-name`,
`property-change::accessible-name` and `state-change` signals. They require the
updated name/state to be readable within each callback, check GObject's real
freeze/thaw coalescing, and cover all expanded tristate transitions without
changing existing focus, enabled or role behavior.

Initial name assignment remains silent, as in ATK's public setter. A private
`name_initialized` flag preserves the SDK setter's existing nullable values:
clearing a name cannot incorrectly suppress its later reassignment. Two
additional real regressions first failed the earlier nullable guard; their
[red results](./evidence/nullable-review-red.json) are retained. No null value
is converted to a synthetic string.

This follows ATK's own
[name setter and initial-notification rule](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk/atkobject.c#L960),
[GObject-to-ATK property notification path](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk/atkobject.c#L1434),
and [state-change API](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk/atkobject.c#L1118).
The normal Flutter semantics producer uses `std::string::c_str()` labels, but
the node setter itself does not reject null; its prior getter behavior is kept.

## Unit boundary

This is a native source-unit proof, **not** a rebuilt Flutter runtime or an
accepted Catalog/Orca session. The node's engine property is always null. The
only two engine link providers are explicit in
[engine_link_stubs.cc](./engine_link_stubs.cc): a GObject type for that unused
null property, and a semantics dispatcher that aborts if called. No ATK or
GObject function, getter or signal is replaced, and no Dart engine starts.
These link providers must never be used in an application build.

## Reproduce in a disposable Linux container

Run from this repository root with an unmodified checkout of the pinned Flutter
SDK. `prepare_sources.py` checks the original source and three relevant headers
against their pinned Git blobs, refuses output inside the SDK or a nonempty
evidence directory, then applies the patch only to its isolated copy.

```sh
ATK_PROOF_SDK=/absolute/path/to/flutter-3.47.0
ATK_PROOF_SOURCE="$PWD/docs/beautiful-ui/diagnostics/linux-sdk-accessibility-patch"
ATK_PROOF_WORK=$(mktemp -d /tmp/beautiful-atk-proof.XXXXXX)
ATK_PROOF_CONTAINER=beautiful-atk-proof-manual

python3 "$ATK_PROOF_SOURCE/prepare_sources.py" \
  --sdk-root "$ATK_PROOF_SDK" --output "$ATK_PROOF_WORK"

docker run --rm --name "$ATK_PROOF_CONTAINER" --platform linux/arm64 \
  --cpus 2 --memory 2g --pids-limit 512 \
  -v "$ATK_PROOF_SDK/engine/src:/sdk:ro" \
  -v "$ATK_PROOF_SOURCE:/proof:ro" \
  -v "$ATK_PROOF_WORK:/work" \
  -e DEBIAN_FRONTEND=noninteractive \
  ubuntu@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517 \
  sh -c 'apt-get update > /work/toolchain-install.log 2>&1 &&
    apt-get install -y --no-install-recommends clang cmake ninja-build pkg-config \
      libgtk-3-dev libgtest-dev patch ca-certificates python3 \
      >> /work/toolchain-install.log 2>&1 && sh /proof/run_native_tests.sh'
```

Use an unused container name. The documented preparation downloaded 207 MB of
packages and installed about 941 MB; later package repository revisions may
change that. The base image digest is fixed, and each run records actual library
and compiler versions. Only `/work` is writable on the host; no Docker socket,
home directory or privileged access is mounted. The preparation container was
stopped after validation; its name and limits are in the provenance file.

## Using the patch in a real Catalog

The [runtime build assessment](./RUNTIME_BUILD_ASSESSMENT.md) distinguishes this
completed proof from the remaining production embedding build. The official
standalone engine binary cannot directly replace the stock GTK embedding's
internal engine dependency: required Dart isolate APIs are not exported.
No hidden-symbol access, vtable changes, signal injection, observer cache reset
or semantic-node replacement is a valid substitute. A properly rebuilt isolated
embedding artifact must still run the unchanged real Catalog/Orca tasks before
claiming those SDK failures are resolved in the application.
