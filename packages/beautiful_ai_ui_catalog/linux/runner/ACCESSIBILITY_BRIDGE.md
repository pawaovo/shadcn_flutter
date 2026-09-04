# Catalog's bounded Linux accessibility parent repair

Flutter 3.47 constructs a real `AtkSocket` child in `FlSocketAccessible` but
omits the inverse parent assignment. Its downward child traversal therefore
works even when a reader cannot walk from a semantic control back to the GTK
window. The upstream GTK implementation explicitly makes this link:
[GTK 3.24.41 GtkSocketAccessible](https://github.com/GNOME/gtk/blob/3.24.41/gtk/a11y/gtksocketaccessible.c#L58).
The missing link matches the observed Orca `filler claims to have no parent`
failure; `Semantics.onFocus` would not repair that relation.

`catalog_repair_accessible_socket_parent` uses only public GTK/ATK APIs and only
the actual FlView's first direct child when it is an `AtkSocket` with no parent.
It never changes an existing non-null parent, including an already-fixed future
SDK, and does nothing for a different accessibility implementation. It changes
no focus state, actions, reader behavior, or synthetic AT-SPI data.

The host calls it after attaching the FlView to its GtkWindow and before
realization/first-frame exposure. In pinned Flutter 3.47, `fl_view_new` already
calls `gtk_widget_get_accessible` during `setup_engine`, so this repair does not
advance accessibility-object creation. The public GTK getter can create an
accessible lazily in another implementation; a future SDK change must be
reviewed with that lifecycle in mind. ATK's public `set_parent` retains the
parent, while the wrapper already owns the socket. The helper therefore pairs
only its own installed link with a GtkView `destroy` callback. That callback
uses weak references and clears the link only if it still points to the original
wrapper; it never clears an existing SDK-owned or subsequently replaced link.
This breaks the parent/child ownership cycle at the widget lifecycle boundary.

The explicit `catalog_accessibility_bridge_probe` CMake target is excluded from
normal builds and bundle installation. Build it only after an ordinary release
Catalog build. It links the already-built Flutter runtime through a separate
imported target, without triggering another `flutter_assemble` or altering the
bound application bundle.

The probe creates a real GtkWindow and FlView at the same unrealized
initialization point and requires its actual AtkSocket to contain an embedded
plug. Its JSON records actual ATK getters before/after repair,
the raw parent index and reverse child lookup, a repeated-call no-op, preservation
of an initially non-null parent, and weak-reference finalization after releasing
the GTK owner. An already-correct baseline may pass without a repair; a changed
or unverified bridge cannot silently pass. This initialization check starts no
Dart application or screen reader and does not grant application, AT task, or
human acceptance. The full ordinary Catalog/Orca run remains a separate gate.

An empty natural baseline does not by itself test an existing-parent branch.
Two separately labelled guard cases therefore use additional actual FlViews:

- `constructed_preexisting_parent_case`: when needed, the test owner explicitly
  installs the wrapper as parent with public ATK API, then verifies that the
  helper leaves it unchanged and returns false. The test owner clears only its
  constructed relation before checking finalization.
- `constructed_replaced_parent_case`: after the helper installs its natural
  missing link, the test explicitly replaces that parent with another real GTK
  window's accessible object. Destroying the original view must preserve this
  replacement; the test owner then clears the constructed relation and verifies
  cleanup. This case is explicitly not applicable if a future SDK already has
  a parent, because no helper-owned destruction hook would have been installed.

These are transparent, constructed public-API preconditions, not natural SDK
baselines, valid application ancestry claims or fabricated AT-SPI observations.

ATK 2.52's `AtkSocket` does not implement the C-level `get_index_in_parent`
virtual method, so that raw getter can return -1 even with a valid parent. The
probe records that result without inventing an index. The initialization check
requires the actual `wrapper.get_child(0) == socket` and
`socket.get_parent() == wrapper` inverse relation. The supplemental AT-SPI
observer independently records its own index getter and reverse lookup.

From the repository root on the disposable Linux runner:

```sh
mkdir -p artifacts/catalog-orca-native-bridge
cmake --build packages/beautiful_ai_ui_catalog/build/linux/x64/release \
  --target catalog_accessibility_bridge_probe
GTK_MODULES=gail:atk-bridge NO_AT_BRIDGE=0 GDK_BACKEND=x11 \
dbus-run-session -- xvfb-run -a \
  packages/beautiful_ai_ui_catalog/build/linux/x64/release/native_bridge_probe/catalog_accessibility_bridge_probe \
  --bundle "$PWD/packages/beautiful_ai_ui_catalog/build/linux/x64/release/bundle" \
  --report "$PWD/artifacts/catalog-orca-native-bridge/report.json" \
  > artifacts/catalog-orca-native-bridge/stdout.log \
  2> artifacts/catalog-orca-native-bridge/stderr.log
```

The explicit `--report` path receives the complete JSON encoded by Flutter's JSON codec;
encoding or file-write failure returns exit 2. Preserve stdout and stderr as
separate original logs: GTK, the accessibility registry and the unstarted engine
can emit initialization or teardown diagnostics on stdout. Those diagnostics
are not JSON and must not be silently filtered from the original log. The
macOS preparation host has no GTK development tooling;
actual C++ compilation, real GTK getters, finalization and full Orca outcomes
must be reported from the Linux CI execution, not inferred from source review.
