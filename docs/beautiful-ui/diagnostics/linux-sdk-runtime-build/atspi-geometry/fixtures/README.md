# Native GTK/ATK geometry regression fixture

`atspi_geometry_fixture.c` exercises the actual GNOME ATK bridge with public
`AtkPlug`, `AtkSocket`, `atk_socket_embed`, `atk_plug_set_child`, and
`atk_component_get_extents/get_position/get_size` calls. It uses GTK 3 widgets
under Xvfb and a real accessibility D-Bus. Successful geometry is never supplied
by a mock or a replaced bridge callback.

The fixture targets the bridge recursion seen in the Flutter accessibility
stack. It is a focused native integration regression, **not a Flutter, Catalog,
Orca, or full accessibility-tree acceptance test**. In particular, the synthetic
leaf represents one parent-recursion step; it does not implement Flutter's
semantics transformation pipeline or a complete GTK socket widget.

The host is a real `GtkFixed` inside a visible `GtkWindow`. A real nested
`GtkDrawingArea` supplies the descendant's dimensions and local offset. The
`AtkSocket` has the host's actual GTK accessible as its parent, matching the
linkage in GTK's `GtkSocketAccessible`. The fixture's small `AtkObject` /
`AtkComponent` descendant calls its actual `AtkPlug` parent's geometry, then adds
the measured GTK widget offset. Expected rectangles come independently from the
host and drawing area's GTK accessible objects.

The only bridge-specific readiness observation is a **read** of
`dbus-plug-parent`, which GNOME sets when the real `Socket.Embedded` message is
handled. Normal and lifecycle cases never set this metadata, replace a vtable,
or forge successful getter values. The explicit malformed-path mode sends
negative input through the real D-Bus method, as described below.

## Build

The fixture needs an existing C compiler, GTK 3 / ATK / atk-bridge / libatspi
development packages, `xvfb-run`, and `dbus-run-session`. It does not install
dependencies. In the existing owned build container, the repository's runtime
build directory is mounted read-only at `/plan`; generated files go to `/work`.

```sh
mkdir -p /work/atspi-geometry/fixtures
cc -std=c11 -O0 -g -Wall -Wextra -Werror \
  /plan/atspi-geometry/fixtures/atspi_geometry_fixture.c \
  -o /work/atspi-geometry/fixtures/atspi-geometry-fixture \
  $(pkg-config --cflags --libs gtk+-3.0 atk-bridge-2.0 atspi-2)
```

The runtime selection should point `LD_LIBRARY_PATH` at an isolated directory
containing **only** the bridge library and its normal SONAME aliases. It should
not replace GTK, ATK, libatspi, D-Bus, or unrelated dependencies. Every report
records the actual bridge, ATK, and GTK mapped paths from `/proc/self/maps`.
Build/binary hashes and the container identity should be recorded by the parent
runtime-build workflow alongside these reports.

## CLI and reports

```text
atspi-geometry-fixture --mode MODE [--report PATH] [--timeout-ms 1500]
                       [--first-object plug|descendant] [--exchange DIRECTORY]
```

| Mode | Actual scenario | Expected result on the final patch |
| --- | --- | --- |
| `same-process` | Real plug and socket share the bridge bus connection | GTK-matching direct plug and recursive descendant geometry |
| `remote-host` | Host process creates GTK widgets and a socket, then embeds the other process's plug | Host serves original IPC requests until the client finishes |
| `remote-plug` | Separate process owns the plug and descendant | Geometry matches the remote host's GTK widgets, not its own window |
| `destroy-widget` | Healthy baseline, then destroy the real host window | GTK accessible detaches from the widget; unavailable geometry returns promptly |
| `destroy-parent` | Healthy baseline, detach the socket's parent, then actually finalize the socket | Both direct and recursive queries return unavailable for parentless and stale-path phases |
| `cyclic-parent` | Healthy baseline, then public `atk_object_set_parent(socket, plug)` creates a malformed cycle | Unavailable geometry without recursive self-call |
| `invalid-parent-path` | Healthy baseline, then send real `Socket.Embedded` messages with `0` and `00` prepended to the actual socket's numeric path | Both numeric aliases are rejected promptly |

All healthy query pairs exercise `GetExtents` and `GetPosition` in screen and
window coordinates, plus `GetSize`. Both objects use all three public APIs.
`--first-object descendant` exists so stock runs can demonstrate the recursive
failure independently of the direct plug failure; the default order is plug
first. Both remote processes need the same fresh `--exchange` directory.

Stdout and optional `--report` are newline-delimited JSON (NDJSON). Events include
runtime library paths, genuine plug/parent bus identities, every query before it
starts, every completed result with actual/expected values and duration, and a
final summary. Unused rectangle fields for position/size are reported as `-1`.
Unavailable geometry is expected as `[-1,-1,-1,-1]`.

Exit codes are `0` for completed passing checks, `1` for completed failures, `2`
for setup/CLI errors, and `124` for a watchdog timeout. A POSIX `SIGALRM` watchdog
uses async-signal-safe `write` and `_exit`, so it can bound a blocked GTK main
thread. A GLib timeout alone could not do this. The watchdog is armed per query;
initialization/handshake also has an overall bound of at least 12 seconds.
Preserve the actual exit code, stderr, and last `query_begin` when recording a
stock red run. A timeout is evidence of the regression, not a passing summary.

`destroy-parent` intentionally keeps the real widgets alive through the
parentless and stale-path queries, ensuring the descendant still recurses into
the plug. A weak-finalization callback verifies that the socket really died.
`destroy-widget` is separate so the missing-widget case cannot hide a stale-path
recursion failure.

`invalid-parent-path` is explicitly a protocol-invalid safety test, not ordinary
application behavior. It uses the public `atspi_get_a11y_bus()` connection, which
the pinned bridge itself uses, and asynchronously sends `Socket.Embedded` to the
real plug object. It waits for the read-only handshake marker to reflect each
wire path before querying. Thus the test exercises real message dispatch and
parsing without directly writing private object metadata. The healthy baseline
must pass before any invalid input is sent. A bridge that accepts numeric aliases
returns the real positive GTK geometry and correctly **fails** these negative
assertions; the fixture does not change the expected values to hide that defect.

## Bounded stock red and patched local matrix

Run each process in a fresh bus/display session. The outer workflow must capture
the actual exit code rather than using an unconditional success as acceptance.

```sh
binary=/work/atspi-geometry/fixtures/atspi-geometry-fixture
stock=/work/atspi-geometry/runtime-stock
patched=/work/atspi-geometry/runtime-patched-canonical

# Expected stock result: exit 124 and query_begin followed by watchdog_timeout.
xvfb-run -a -s '-screen 0 1280x1024x24' dbus-run-session -- \
  env LD_LIBRARY_PATH="$stock" NO_AT_BRIDGE=0 "$binary" \
  --mode same-process --first-object plug --timeout-ms 1500 \
  --report /work/atspi-geometry/fixtures/stock-direct.ndjson

# Separate expected stock red, entering through the recursive descendant.
xvfb-run -a -s '-screen 0 1280x1024x24' dbus-run-session -- \
  env LD_LIBRARY_PATH="$stock" NO_AT_BRIDGE=0 "$binary" \
  --mode same-process --first-object descendant --timeout-ms 1500 \
  --report /work/atspi-geometry/fixtures/stock-recursive.ndjson

# Every patched invocation must exit 0 with summary.failures == 0.
for mode in same-process destroy-widget destroy-parent cyclic-parent invalid-parent-path; do
  xvfb-run -a -s '-screen 0 1280x1024x24' dbus-run-session -- \
    env LD_LIBRARY_PATH="$patched" NO_AT_BRIDGE=0 "$binary" \
    --mode "$mode" --timeout-ms 1500 \
    --report "/work/atspi-geometry/fixtures/patched-$mode.ndjson" || exit "$?"
done
```

## Separate-process IPC control

Run this once with the stock bridge and once with the final patched bridge.
Unlike the stock same-process red case, **both** stock remote processes must
complete successfully. The host writes its independently measured GTK rectangles
to the fresh exchange directory. The plug's own real window is placed elsewhere;
the report asserts different bridge bus identities and a different local screen
origin, so accidentally using the plug's local window cannot satisfy the oracle.

```sh
export GEOMETRY_BIN=/work/atspi-geometry/fixtures/atspi-geometry-fixture
export LD_LIBRARY_PATH=/work/atspi-geometry/runtime-patched-canonical
export NO_AT_BRIDGE=0
export GEOMETRY_EXCHANGE="$(mktemp -d /work/atspi-geometry/fixtures/remote.XXXXXX)"
export GEOMETRY_BASE=/work/atspi-geometry/fixtures/remote-example

xvfb-run -a -s '-screen 0 1280x1024x24' dbus-run-session -- sh <<'REMOTE'
set +e
"$GEOMETRY_BIN" --mode remote-host --exchange "$GEOMETRY_EXCHANGE" \
  --timeout-ms 1500 --report "$GEOMETRY_BASE-host.ndjson" &
host_pid=$!
"$GEOMETRY_BIN" --mode remote-plug --exchange "$GEOMETRY_EXCHANGE" \
  --timeout-ms 1500 --report "$GEOMETRY_BASE-plug.ndjson"
plug_status=$?
wait "$host_pid"
host_status=$?
printf 'plug_exit=%s host_exit=%s\n' "$plug_status" "$host_status"
test "$plug_status" -eq 0 && test "$host_status" -eq 0
REMOTE
```

## Source contract

- The pinned bridge stores the `Embedded` parent and installs its plug geometry
  callbacks in [socket-adaptor.c:196–205](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk-adaptor/adaptors/socket-adaptor.c#L196-L205).
  Its original GetExtents performs a blocking call at
  [lines 61–74](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk-adaptor/adaptors/socket-adaptor.c#L61-L74).
- The bridge's shared public libatspi connection is selected at
  [bridge.c:1111](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk-adaptor/bridge.c#L1111).
- ATK delegates socket extents to its parent in
  [atksocket.c:175–198](https://github.com/GNOME/at-spi2-core/blob/AT_SPI2_CORE_2_52_0/atk/atksocket.c#L175-L198).
  GTK supplies that parent in
  [gtksocketaccessible.c:63–72](https://github.com/GNOME/gtk/blob/3.24.41/gtk/a11y/gtksocketaccessible.c#L63-L72).
- GTK's real widget geometry is implemented at
  [gtkwidgetaccessible.c:566](https://github.com/GNOME/gtk/blob/3.24.41/gtk/a11y/gtkwidgetaccessible.c#L566).

These are source-level integration checks. Passing them does not by itself
establish Catalog usability, Orca speech behavior, or the complete Linux SDK
accessibility gate.
