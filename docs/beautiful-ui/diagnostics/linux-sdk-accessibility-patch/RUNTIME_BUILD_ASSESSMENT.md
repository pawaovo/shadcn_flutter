# Applying the source repair to an actual Linux embedding

The native unit proof is complete. The existing Catalog binaries still use the
stock SDK; no runtime acceptance is inferred from the unit result.

The pinned `shell/platform/linux/BUILD.gn` defines 68 GTK embedding source units.
Its ordinary `flutter_linux_gtk` library links `embedder_as_internal_library`.
This is the legitimate full artifact to rebuild with the source patch. The
source unit proof's null-engine link providers cannot participate in that build.

One smaller route was assessed: rebuild all 68 GTK source files around the
official same-revision standalone `libflutter_engine.so`, preserving the entire
embedding. The required public engine archive exists: 14,825,981 downloaded
bytes, with its URL and SHA256 in
[the read-only binary report](./evidence/standalone-engine-symbols.json).

That route has a concrete link boundary:

| GTK dependency | Evidence |
| --- | --- |
| Engine procedure table | `FlutterEngineGetProcAddresses` is exported by the official standalone library. |
| Window/view monitor isolate scopes | `fl_view_monitor.cc` and `fl_window_monitor.cc` use `common/isolate_scope.cc`, which calls `Dart_CurrentIsolate`, `Dart_EnterIsolate` and `Dart_ExitIsolate`. |
| Required Dart symbols | All three are absent from the actual ELF dynamic export table. The pinned `embedder_exports.lst` also exports only Flutter-prefixed API groups and designated snapshot/GPU symbols, with all other symbols local. |

The ELF check read the file only. It did not load the binary, alter symbol
visibility, interpose functions, inspect hidden implementation addresses or
modify any installed SDK. Removing monitor behavior, substituting unrelated
Dart runtime instances or using private symbol access would not produce an
equivalent embedding and is outside this repair.

The proper next route is therefore an **isolated official engine/GTK build**
at the pinned revision, with this single source patch applied normally. Its
GN target already links the required internal engine and Dart APIs together.
The resulting library must be selected explicitly for a separate Catalog
bundle, with source/patch/library hashes and unchanged acceptance assertions.
An ordinary stock bundle must remain separately identifiable.

The installed SDK checkout has the relevant GTK sources and headers, but it
does not contain the Dart dependency checkout, Skia, ICU or the Linux GN
toolchain required for that full build. The completed 941 MB unit-test container
is not a full engine build environment. Dependency synchronization and build
cost must be assessed and coordinated before starting; no full engine fetch or
build was launched during this assessment. The official standalone archive is
small, but its missing public Dart symbols prevent claiming a cheap relink of
the unmodified complete GTK layer.

After an isolated runtime artifact exists, run the original real GTK/FlView
initialization cases and the unchanged three-task Catalog Orca pilot. Dynamic
name updates, expanded states, native actions, exact reader utterances, PCM
boundaries and cleanup all remain required. Human speech review and broader
application AT acceptance remain separate.
