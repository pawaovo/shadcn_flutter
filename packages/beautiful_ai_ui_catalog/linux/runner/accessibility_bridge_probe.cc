// Explicit native initialization probe; never installed into the app bundle.
#include "accessibility_bridge.h"

#include <atk/atk.h>
#include <cstring>

namespace {

void boolean(FlValue* map, const char* key, gboolean value) {
  fl_value_set_string_take(map, key, fl_value_new_bool(value));
}

void string(FlValue* map, const char* key, const char* value) {
  fl_value_set_string_take(map, key, fl_value_new_string(value));
}

FlValue* relation(AtkObject* wrapper, AtkObject* socket) {
  FlValue* result = fl_value_new_map();
  AtkObject* parent = socket == nullptr ? nullptr : atk_object_get_parent(socket);
  string(result, "wrapper_type", G_OBJECT_TYPE_NAME(wrapper));
  string(result, "child_type", socket == nullptr ? "none" : G_OBJECT_TYPE_NAME(socket));
  string(result, "parent_type", parent == nullptr ? "none" : G_OBJECT_TYPE_NAME(parent));
  boolean(result, "child_is_actual_atk_socket", socket != nullptr && ATK_IS_SOCKET(socket));
  boolean(result, "socket_has_embedded_plug", socket != nullptr && ATK_IS_SOCKET(socket) &&
      atk_socket_is_occupied(ATK_SOCKET(socket)));
  boolean(result, "parent_missing", parent == nullptr);
  boolean(result, "child_parent_is_wrapper", parent == wrapper);
  const gint count = atk_object_get_n_accessible_children(wrapper);
  fl_value_set_string_take(result, "wrapper_child_count", fl_value_new_int(count));
  g_autoptr(AtkObject) exposed = count > 0 ? atk_object_ref_accessible_child(wrapper, 0) : nullptr;
  boolean(result, "wrapper_child_zero_is_socket", exposed == socket && socket != nullptr);
  const gint index = socket == nullptr ? -1 : atk_object_get_index_in_parent(socket);
  fl_value_set_string_take(result, "child_index_in_parent", fl_value_new_int(index));
  g_autoptr(AtkObject) reverse = parent != nullptr && index >= 0
      ? atk_object_ref_accessible_child(parent, index) : nullptr;
  boolean(result, "parent_child_inverse", parent == wrapper && exposed == socket && socket != nullptr);
  boolean(result, "index_getter_supported", index >= 0);
  boolean(result, "index_based_child_inverse", reverse == socket && socket != nullptr);
  return result;
}

gboolean finalized(GWeakRef* reference) {
  g_autoptr(GObject) object = G_OBJECT(g_weak_ref_get(reference));
  return object == nullptr;
}

// Every guard case uses actual GTK and FlView objects. Weak observations are
// established while the objects are live, so teardown never reads a dead raw
// wrapper/view pointer. The socket reference is only an inspection reference.
class NativeFixture {
 public:
  explicit NativeFixture(FlDartProject* project) {
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    g_object_ref_sink(window);
    view = fl_view_new(project);
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
    wrapper = gtk_widget_get_accessible(GTK_WIDGET(view));
    socket = atk_object_get_n_accessible_children(wrapper) > 0
        ? atk_object_ref_accessible_child(wrapper, 0) : nullptr;
    g_weak_ref_init(&weak_view_, view);
    g_weak_ref_init(&weak_wrapper_, wrapper);
    g_weak_ref_init(&weak_socket_, socket);
  }

  NativeFixture(const NativeFixture&) = delete;
  NativeFixture& operator=(const NativeFixture&) = delete;

  ~NativeFixture() {
    if (window != nullptr) {
      close(nullptr);
    }
    g_weak_ref_clear(&weak_view_);
    g_weak_ref_clear(&weak_wrapper_);
    g_weak_ref_clear(&weak_socket_);
  }

  gboolean close(FlValue* report) {
    g_clear_object(&socket);
    gtk_widget_destroy(window);
    g_clear_object(&window);
    for (int i = 0; i < 32 && g_main_context_pending(nullptr); i++) {
      g_main_context_iteration(nullptr, FALSE);
    }
    const gboolean view_finalized = finalized(&weak_view_);
    const gboolean wrapper_finalized = finalized(&weak_wrapper_);
    const gboolean socket_finalized = finalized(&weak_socket_);
    if (report != nullptr) {
      boolean(report, "view_finalized", view_finalized);
      boolean(report, "wrapper_finalized", wrapper_finalized);
      boolean(report, "socket_finalized", socket_finalized);
    }
    return view_finalized && wrapper_finalized && socket_finalized;
  }

  GtkWidget* window;
  FlView* view;
  AtkObject* wrapper;
  AtkObject* socket;

 private:
  GWeakRef weak_view_;
  GWeakRef weak_wrapper_;
  GWeakRef weak_socket_;
};

FlValue* verify_preexisting_parent(FlDartProject* project, gboolean* passed) {
  NativeFixture fixture(project);
  FlValue* report = fl_value_new_map();
  string(report, "case", "constructed_preexisting_parent_noop");
  string(report, "scope", "guard fixture, not the natural SDK baseline or application AT acceptance");
  fl_value_set_string_take(report, "natural_before_setup", relation(fixture.wrapper, fixture.socket));
  const gboolean actual_socket = fixture.socket != nullptr && ATK_IS_SOCKET(fixture.socket);
  const gboolean constructed = actual_socket && atk_object_get_parent(fixture.socket) == nullptr;
  if (constructed) {
    atk_object_set_parent(fixture.socket, fixture.wrapper);
  }
  boolean(report, "precondition_constructed_by_test", constructed);
  fl_value_set_string_take(report, "before_helper", relation(fixture.wrapper, fixture.socket));
  AtkObject* expected = actual_socket ? atk_object_get_parent(fixture.socket) : nullptr;
  const gboolean changed = catalog_repair_accessible_socket_parent(fixture.view);
  const gboolean preserved = expected != nullptr && atk_object_get_parent(fixture.socket) == expected;
  boolean(report, "helper_changed_parent", changed);
  boolean(report, "existing_parent_preserved", preserved);
  fl_value_set_string_take(report, "after_helper", relation(fixture.wrapper, fixture.socket));
  // The test owns its constructed relation; the helper must not have added a
  // teardown hook for it. Clear it explicitly before releasing this fixture.
  if (constructed && atk_object_get_parent(fixture.socket) == fixture.wrapper) {
    atk_object_set_parent(fixture.socket, nullptr);
  }
  boolean(report, "test_owner_cleared_constructed_parent", constructed &&
      atk_object_get_parent(fixture.socket) == nullptr);
  *passed = actual_socket && expected == fixture.wrapper && preserved && !changed;
  const gboolean lifetime = fixture.close(report);
  *passed = *passed && lifetime;
  string(report, "status", *passed ? "verified" : "not_verified");
  return report;
}

FlValue* verify_replaced_parent(FlDartProject* project, gboolean* passed) {
  NativeFixture fixture(project);
  FlValue* report = fl_value_new_map();
  string(report, "case", "constructed_replacement_survives_view_destroy");
  string(report, "scope", "public-API parent replacement fixture, not an application ancestry claim");
  fl_value_set_string_take(report, "natural_before_setup", relation(fixture.wrapper, fixture.socket));
  const gboolean actual_socket = fixture.socket != nullptr && ATK_IS_SOCKET(fixture.socket);
  if (!actual_socket || atk_object_get_parent(fixture.socket) != nullptr) {
    // A future SDK's already-owned link is not removed just to manufacture a
    // missing-parent baseline. The native baseline and no-op case cover it.
    boolean(report, "applicable", FALSE);
    string(report, "status", actual_socket ? "not_applicable_sdk_parent_already_present" : "not_verified");
    const gboolean lifetime = fixture.close(report);
    *passed = actual_socket && lifetime;
    return report;
  }
  boolean(report, "applicable", TRUE);
  const gboolean changed = catalog_repair_accessible_socket_parent(fixture.view);
  boolean(report, "helper_installed_original_parent", changed);
  fl_value_set_string_take(report, "after_helper", relation(fixture.wrapper, fixture.socket));

  // A second real GTK owner supplies a different real AtkObject. This explicit
  // guard precondition tests preservation, not a valid application child tree.
  GtkWidget* replacement_owner = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  g_object_ref_sink(replacement_owner);
  AtkObject* replacement = gtk_widget_get_accessible(replacement_owner);
  GWeakRef weak_replacement;
  g_weak_ref_init(&weak_replacement, replacement);
  atk_object_set_parent(fixture.socket, replacement);
  boolean(report, "replacement_constructed_by_test", TRUE);
  boolean(report, "replacement_set_before_destroy", atk_object_get_parent(fixture.socket) == replacement);
  string(report, "replacement_type", G_OBJECT_TYPE_NAME(replacement));
  gtk_widget_destroy(fixture.window);
  const gboolean preserved = atk_object_get_parent(fixture.socket) == replacement;
  boolean(report, "replacement_preserved_after_view_destroy", preserved);
  // Only this test owns the replacement relation and its cleanup.
  atk_object_set_parent(fixture.socket, nullptr);
  gtk_widget_destroy(replacement_owner);
  g_object_unref(replacement_owner);
  const gboolean lifetime = fixture.close(report);
  const gboolean replacement_finalized = finalized(&weak_replacement);
  boolean(report, "replacement_accessible_finalized", replacement_finalized);
  g_weak_ref_clear(&weak_replacement);
  *passed = changed && preserved && lifetime && replacement_finalized;
  string(report, "status", *passed ? "verified" : "not_verified");
  return report;
}

int write_report(FlValue* report, gboolean passed, const char* report_path) {
  string(report, "status", passed ? "native_bridge_initialization_verified" : "not_verified");
  string(report, "application_acceptance", "not_accepted");
  string(report, "human_review", "not_accepted");
  g_autoptr(FlJsonMessageCodec) codec = fl_json_message_codec_new();
  g_autoptr(GError) error = nullptr;
  g_autoptr(GBytes) json = fl_message_codec_encode_message(FL_MESSAGE_CODEC(codec), report, &error);
  if (json == nullptr) {
    g_printerr("Could not encode native evidence: %s\n", error == nullptr ? "unknown error" : error->message);
    return 2;
  }
  gsize length = 0;
  const void* data = g_bytes_get_data(json, &length);
  if (!g_file_set_contents(report_path, static_cast<const gchar*>(data),
                           static_cast<gssize>(length), &error)) {
    g_printerr("Could not write native evidence to %s: %s\n", report_path,
               error == nullptr ? "unknown error" : error->message);
    return 2;
  }
  return passed ? 0 : 2;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 5 || std::strcmp(argv[1], "--bundle") != 0 ||
      std::strcmp(argv[3], "--report") != 0 || argv[4][0] == '\0') {
    g_printerr("Usage: catalog_accessibility_bridge_probe --bundle /absolute/release/bundle --report /path/report.json\n");
    return 2;
  }
  g_autofree gchar* bundle = g_canonicalize_filename(argv[2], nullptr);
  g_autofree gchar* assets = g_build_filename(bundle, "data", "flutter_assets", nullptr);
  g_autofree gchar* icu = g_build_filename(bundle, "data", "icudtl.dat", nullptr);
  g_autofree gchar* aot = g_build_filename(bundle, "lib", "libapp.so", nullptr);
  if (!g_file_test(assets, G_FILE_TEST_IS_DIR) || !g_file_test(icu, G_FILE_TEST_IS_REGULAR) ||
      !g_file_test(aot, G_FILE_TEST_IS_REGULAR)) {
    g_printerr("The ordinary compiled Catalog bundle is incomplete\n");
    return 2;
  }
  if (!gtk_init_check(nullptr, nullptr)) {
    g_printerr("A disposable GTK/X11 display is required\n");
    return 2;
  }

  g_autoptr(FlValue) report = fl_value_new_map();
  fl_value_set_string_take(report, "schema_version", fl_value_new_int(1));
  string(report, "scope", "real_unrealized_fl_view_gtk_initialization_and_parent_inverse");
  string(report, "bundle", bundle);
  string(report, "engine_execution", "not_requested; probe does not realize or show the view");

  // fl_view_new itself creates the real engine-owned accessibility wrapper and
  // socket. Like the host call site, attach the view before repairing the link,
  // without realizing/showing it or starting the Dart isolate for this probe.
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_assets_path(project, assets);
  fl_dart_project_set_icu_data_path(project, icu);
  fl_dart_project_set_aot_library_path(project, aot);
  NativeFixture fixture(project);
  FlView* view = fixture.view;
  AtkObject* wrapper = fixture.wrapper;
  AtkObject* socket = fixture.socket;
  const gboolean actual_socket = socket != nullptr && ATK_IS_SOCKET(socket);
  const gboolean embedded_plug = actual_socket && atk_socket_is_occupied(ATK_SOCKET(socket));
  AtkObject* original_parent = socket == nullptr ? nullptr : atk_object_get_parent(socket);
  boolean(report, "original_parent_was_nonempty", original_parent != nullptr);
  const gboolean was_realized = gtk_widget_get_realized(GTK_WIDGET(view));
  fl_value_set_string_take(report, "before", relation(wrapper, socket));

  const gboolean changed = catalog_repair_accessible_socket_parent(view);
  boolean(report, "repair_changed_parent", changed);
  fl_value_set_string_take(report, "after", relation(wrapper, socket));
  const gboolean correct_parent = actual_socket && atk_object_get_parent(socket) == wrapper;
  const gboolean preserved_original = original_parent == nullptr ||
      (socket != nullptr && atk_object_get_parent(socket) == original_parent);
  boolean(report, "original_nonempty_parent_preserved", preserved_original);
  const gboolean repeat_changed = catalog_repair_accessible_socket_parent(view);
  boolean(report, "repeat_changed_parent", repeat_changed);
  fl_value_set_string_take(report, "after_repeat", relation(wrapper, socket));
  boolean(report, "view_realized_before", was_realized);
  boolean(report, "view_realized_after", gtk_widget_get_realized(GTK_WIDGET(view)));
  const gboolean did_not_realize = !was_realized && !gtk_widget_get_realized(GTK_WIDGET(view));
  g_autoptr(AtkObject) exposed = atk_object_ref_accessible_child(wrapper, 0);
  const gboolean inverse = actual_socket && exposed == socket &&
      atk_object_get_parent(socket) == wrapper;

  g_clear_object(&exposed);
  const gboolean lifetime = fixture.close(report);
  gboolean preexisting_verified = FALSE;
  gboolean replaced_verified = FALSE;
  fl_value_set_string_take(report, "constructed_preexisting_parent_case",
      verify_preexisting_parent(project, &preexisting_verified));
  fl_value_set_string_take(report, "constructed_replaced_parent_case",
      verify_replaced_parent(project, &replaced_verified));
  return write_report(report, actual_socket && embedded_plug && correct_parent && inverse && !repeat_changed &&
      preserved_original && did_not_realize && lifetime && preexisting_verified && replaced_verified, argv[4]);
}
