# Isolated ATK bridge geometry repair

The first full patched Flutter engine ran the Catalog, but its original native
inspector later timed out. A separate traced attempt and a bounded debugger
attachment identified the GTK main thread waiting in
`dbus_connection_send_with_reply_and_block`, reached through nested
`atk_component_get_extents` calls. The inspector's application-name request was
waiting behind that geometry request. The original attempt remains failed.

ATK explicitly supports an AtkPlug embedded in an AtkSocket in the same process.
In GNOME at-spi2-core 2.52, the bridge nevertheless sends synchronous geometry
requests back to that same connection. It also replaces the plug's geometry
interface during the real Embedded handshake, so an SDK class-initialization
override would not fix direct plug queries. The relevant primary sources are
[the same-process API contract](https://docs.gtk.org/atk/method.Socket.embed.html),
[the geometry proxy and Embedded handler](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk-adaptor/adaptors/socket-adaptor.c),
and [the existing local-object registry](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk-adaptor/accessible-register.c).

This separate patch changes that dependency's source. For the current connection's
exact unique bus name, it resolves a canonical numeric path through the existing
registry, holds the real AtkSocket temporarily, and calls its normal ATK geometry
API. Invalid local paths and cyclic parent graphs return unavailable geometry;
they never fall back to a synchronous request to the same process. Valid remote
bus IDs retain the original IPC implementation. The application, observer,
socket/plug embedding, parent identities and existing bridge interface setup are
unchanged. No application code replaces a vtable or fabricates coordinates.

The source is pinned to upstream tag `AT_SPI2_CORE_2_52_0`, commit
`46c8de80022d28eef2da58f1054b5bff745ed7e0`. The original Flutter name/expanded
patch and its generated engine remain separate, unchanged artifacts. This
dependency patch is necessary in addition to those SDK changes and the Catalog's
already tested socket-parent attachment.

Run only inside the existing owned 4 CPU / 8 GiB SDK build container. All source,
builds and prefixes are disposable paths under `/work`; no system installation
is replaced. The source directories are separate worktrees, so stock evidence
does not change when the patch is applied.

```sh
apt-get install -y --no-install-recommends meson libxtst-dev libsystemd-dev libxml2-dev
git clone --depth 1 --branch AT_SPI2_CORE_2_52_0 \
  https://github.com/GNOME/at-spi2-core.git /work/atspi-geometry/source
git -C /work/atspi-geometry/source worktree add --detach \
  /work/atspi-geometry/patched 46c8de80022d28eef2da58f1054b5bff745ed7e0
git -C /work/atspi-geometry/patched apply \
  /plan/atspi-geometry/at-spi2-core-2.52-same-process-geometry.patch
python3 /plan/atspi-geometry/build_bridge.py stock
python3 /plan/atspi-geometry/build_bridge.py patched
```

The build script verifies the exact source and diff, limits Ninja to four jobs,
installs into a private prefix, and rejects an installed bridge with RPATH or
RUNPATH. It then selects only `libatk-bridge-2.0` into `runtime-stock` or
`runtime-patched`. An explicit diagnostic `LD_LIBRARY_PATH` selects that library;
all other GTK/ATK/AT-SPI dependencies stay at their installed versions. Source,
patch, actual shared-library hashes and original command exits are recorded.

The [native fixtures](fixtures/README.md) exercise real GTK/AtkPlug/AtkSocket
geometry and separate-process IPC. A successful native fixture is not Catalog
acceptance. Before a new Catalog attempt, its runtime binding must include the
selected dependency and verify the actual mapped shared library, while retaining
all original input, utterance, PCM, timing and cleanup requirements.

The upstream source remains licensed under LGPL-2.1-or-later as stated in its
headers. The reproducible pinned source, patch and build command are provided;
no compiled dependency is committed here.
