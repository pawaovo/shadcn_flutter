/*
 * Real GTK/ATK integration regression for AtkPlug/AtkSocket geometry.
 *
 * This fixture supplies real GtkWidget geometry, uses the public plug/socket
 * embedding and component APIs, and never replaces a bridge callback. The only
 * bridge-specific observation is the read-only Embedded-handshake marker.
 */
#define _POSIX_C_SOURCE 200809L
#include <atk/atk.h>
#include <atk-bridge.h>
#include <atspi/atspi.h>
#include <gtk/gtk.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

typedef struct {
  gint x, y, width, height;
} Rect;

typedef struct {
  Rect host[2];
  Rect leaf[2];
} Expected;

typedef struct _GeometryLeaf {
  AtkObject parent_instance;
  GWeakRef host_widget;
  GWeakRef leaf_widget;
} GeometryLeaf;

typedef struct _GeometryLeafClass {
  AtkObjectClass parent_class;
} GeometryLeafClass;

static void geometry_leaf_component_init(AtkComponentIface *iface);
G_DEFINE_TYPE_WITH_CODE(GeometryLeaf, geometry_leaf, ATK_TYPE_OBJECT,
                       G_IMPLEMENT_INTERFACE(ATK_TYPE_COMPONENT,
                                             geometry_leaf_component_init))

/* One semantics-like recursion, but offsets and dimensions are measured from
 * actual GTK widgets. The independent oracle is the leaf's GTK accessible. */
static void geometry_leaf_get_extents(AtkComponent *component, gint *x, gint *y,
                                     gint *width, gint *height,
                                     AtkCoordType coord_type) {
  GeometryLeaf *self = (GeometryLeaf *) component;
  AtkObject *parent = atk_object_get_parent(ATK_OBJECT(self));
  GtkWidget *host = g_weak_ref_get(&self->host_widget);
  GtkWidget *leaf = g_weak_ref_get(&self->leaf_widget);
  Rect base = {-1, -1, -1, -1};
  GtkAllocation allocation;
  gint local_x, local_y;
  *x = *y = *width = *height = -1;
  if (parent && ATK_IS_COMPONENT(parent) && host && leaf &&
      gtk_widget_get_realized(host) && gtk_widget_get_realized(leaf) &&
      gtk_widget_translate_coordinates(leaf, host, 0, 0, &local_x, &local_y)) {
    atk_component_get_extents(ATK_COMPONENT(parent), &base.x, &base.y,
                              &base.width, &base.height, coord_type);
    if (!(base.x == -1 && base.y == -1 && base.width == -1 && base.height == -1)) {
      gtk_widget_get_allocation(leaf, &allocation);
      *x = base.x + local_x;
      *y = base.y + local_y;
      *width = allocation.width;
      *height = allocation.height;
    }
  }
  g_clear_object(&host);
  g_clear_object(&leaf);
}

static void geometry_leaf_component_init(AtkComponentIface *iface) {
  iface->get_extents = geometry_leaf_get_extents;
  /* The public ATK defaults for GetPosition/GetSize exercise this getter too. */
}

static void geometry_leaf_finalize(GObject *object) {
  GeometryLeaf *self = (GeometryLeaf *) object;
  g_weak_ref_clear(&self->host_widget);
  g_weak_ref_clear(&self->leaf_widget);
  G_OBJECT_CLASS(geometry_leaf_parent_class)->finalize(object);
}

static void geometry_leaf_class_init(GeometryLeafClass *klass) {
  G_OBJECT_CLASS(klass)->finalize = geometry_leaf_finalize;
}

static void geometry_leaf_init(GeometryLeaf *self) {
  g_weak_ref_init(&self->host_widget, NULL);
  g_weak_ref_init(&self->leaf_widget, NULL);
}

typedef struct {
  gchar *mode;
  gchar *exchange;
  gchar *report;
  gchar *first_object;
  gint timeout_ms;
  GtkWidget *window;
  GtkWidget *host;
  GtkWidget *leaf_widget;
  AtkObject *host_accessible;
  AtkObject *leaf_accessible;
  AtkObject *socket;
  AtkObject *plug;
  GeometryLeaf *leaf;
  gchar *plug_id;
  gchar *parent_id;
  gchar *pending_parent_id;
  Expected expected;
  gint failures;
  gint checks;
  gboolean embedded;
  gboolean finished;
  gboolean socket_finalized;
  gboolean invalid_phase_started;
  gint invalid_path_index;
} Fixture;

static int report_fd = -1;
static Fixture fixture;

static void emit(const gchar *format, ...) {
  va_list args;
  va_start(args, format);
  gchar *line = g_strdup_vprintf(format, args);
  va_end(args);
  gsize length = strlen(line);
  (void) write(STDOUT_FILENO, line, length);
  (void) write(STDOUT_FILENO, "\n", 1);
  if (report_fd >= 0) {
    (void) write(report_fd, line, length);
    (void) write(report_fd, "\n", 1);
  }
  g_free(line);
}

/* Unlike a GLib timeout, SIGALRM also bounds a blocked GTK main thread. The
 * handler uses only async-signal-safe operations and exits with a distinct code. */
static void watchdog_expired(int signal_number) {
  (void) signal_number;
  static const char message[] =
      "{\"event\":\"watchdog_timeout\",\"exit_code\":124}\n";
  (void) write(STDOUT_FILENO, message, sizeof(message) - 1);
  if (report_fd >= 0)
    (void) write(report_fd, message, sizeof(message) - 1);
  _exit(124);
}

static void watchdog(gint timeout_ms) {
  struct itimerval timer = {0};
  timer.it_value.tv_sec = timeout_ms / 1000;
  timer.it_value.tv_usec = (timeout_ms % 1000) * 1000;
  if (setitimer(ITIMER_REAL, &timer, NULL) != 0) {
    perror("setitimer");
    exit(2);
  }
}

static void invariant(const char *name, gboolean passed) {
  fixture.checks++;
  if (!passed)
    fixture.failures++;
  emit("{\"event\":\"invariant\",\"name\":\"%s\",\"passed\":%s}",
       name, passed ? "true" : "false");
}

static void report_loaded_libraries(void) {
  const char *names[] = {"libatk-bridge-2.0.so", "libatk-1.0.so", "libgtk-3.so"};
  gboolean seen[G_N_ELEMENTS(names)] = {FALSE};
  FILE *maps = fopen("/proc/self/maps", "r");
  if (!maps)
    return;
  char *line = NULL;
  size_t capacity = 0;
  while (getline(&line, &capacity, maps) >= 0) {
    char *path = strchr(line, '/');
    if (!path)
      continue;
    path[strcspn(path, "\r\n")] = '\0';
    for (guint index = 0; index < G_N_ELEMENTS(names); index++) {
      if (!seen[index] && strstr(path, names[index])) {
        seen[index] = TRUE;
        emit("{\"event\":\"loaded_library\",\"library\":\"%s\",\"path\":\"%s\"}",
             names[index], path);
      }
    }
  }
  free(line);
  fclose(maps);
}

static gchar *exchange_path(const char *name) {
  return g_build_filename(fixture.exchange, name, NULL);
}

static gboolean write_exchange(const char *name, const char *contents) {
  gchar *path = exchange_path(name);
  GError *error = NULL;
  gboolean ok = g_file_set_contents(path, contents, -1, &error);
  if (!ok) {
    g_printerr("Cannot write %s: %s\n", path, error->message);
    g_clear_error(&error);
    fixture.failures++;
  }
  g_free(path);
  return ok;
}

static gchar *read_exchange(const char *name) {
  gchar *path = exchange_path(name);
  gchar *contents = NULL;
  (void) g_file_get_contents(path, &contents, NULL, NULL);
  g_free(path);
  return contents;
}

static Rect widget_rect(AtkObject *accessible, AtkCoordType type) {
  Rect rect = {-1, -1, -1, -1};
  atk_component_get_extents(ATK_COMPONENT(accessible), &rect.x, &rect.y,
                            &rect.width, &rect.height, type);
  return rect;
}

static void collect_expected(void) {
  fixture.expected.host[0] = widget_rect(fixture.host_accessible, ATK_XY_SCREEN);
  fixture.expected.host[1] = widget_rect(fixture.host_accessible, ATK_XY_WINDOW);
  fixture.expected.leaf[0] = widget_rect(fixture.leaf_accessible, ATK_XY_SCREEN);
  fixture.expected.leaf[1] = widget_rect(fixture.leaf_accessible, ATK_XY_WINDOW);
}

static void save_expected(void) {
  GString *text = g_string_new(NULL);
  for (gint object = 0; object < 2; object++) {
    for (gint coord = 0; coord < 2; coord++) {
      Rect rect = object ? fixture.expected.leaf[coord] : fixture.expected.host[coord];
      g_string_append_printf(text, "%d %d %d %d\n", rect.x, rect.y,
                             rect.width, rect.height);
    }
  }
  write_exchange("host-geometry.txt", text->str);
  g_string_free(text, TRUE);
}

static gboolean load_expected(void) {
  gchar *text = read_exchange("host-geometry.txt");
  if (!text)
    return FALSE;
  Rect *h = fixture.expected.host;
  Rect *l = fixture.expected.leaf;
  gint count = sscanf(text,
      "%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
      &h[0].x, &h[0].y, &h[0].width, &h[0].height,
      &h[1].x, &h[1].y, &h[1].width, &h[1].height,
      &l[0].x, &l[0].y, &l[0].width, &l[0].height,
      &l[1].x, &l[1].y, &l[1].width, &l[1].height);
  g_free(text);
  return count == 16;
}

static void query(const char *phase, const char *object_name, AtkObject *object,
                  const char *operation, AtkCoordType coord, Rect expected) {
  Rect actual = {-1, -1, -1, -1};
  const char *coord_name = coord == ATK_XY_SCREEN ? "screen" : "window";
  emit("{\"event\":\"query_begin\",\"phase\":\"%s\",\"object\":\"%s\","
       "\"operation\":\"%s\",\"coord\":\"%s\"}",
       phase, object_name, operation, coord_name);
  gint64 start = g_get_monotonic_time();
  watchdog(fixture.timeout_ms);
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  if (!strcmp(operation, "GetExtents")) {
    atk_component_get_extents(ATK_COMPONENT(object), &actual.x, &actual.y,
                              &actual.width, &actual.height, coord);
  } else if (!strcmp(operation, "GetPosition")) {
    atk_component_get_position(ATK_COMPONENT(object), &actual.x, &actual.y, coord);
    expected.width = expected.height = -1;
  } else {
    atk_component_get_size(ATK_COMPONENT(object), &actual.width, &actual.height);
    expected.x = expected.y = -1;
  }
  G_GNUC_END_IGNORE_DEPRECATIONS
  watchdog(0);
  gint64 duration = g_get_monotonic_time() - start;
  gboolean passed = actual.x == expected.x && actual.y == expected.y &&
                    actual.width == expected.width && actual.height == expected.height;
  fixture.checks++;
  if (!passed)
    fixture.failures++;
  emit("{\"event\":\"query_result\",\"phase\":\"%s\",\"object\":\"%s\","
       "\"operation\":\"%s\",\"coord\":\"%s\",\"actual\":[%d,%d,%d,%d],"
       "\"expected\":[%d,%d,%d,%d],\"duration_us\":%" G_GINT64_FORMAT ",\"passed\":%s}",
       phase, object_name, operation, coord_name, actual.x, actual.y,
       actual.width, actual.height, expected.x, expected.y, expected.width,
       expected.height, duration, passed ? "true" : "false");
}

static void query_object(const char *phase, const char *name, AtkObject *object,
                         const Rect expected[2]) {
  for (gint coord = 0; coord < 2; coord++) {
    AtkCoordType type = coord ? ATK_XY_WINDOW : ATK_XY_SCREEN;
    query(phase, name, object, "GetExtents", type, expected[coord]);
    query(phase, name, object, "GetPosition", type, expected[coord]);
  }
  query(phase, name, object, "GetSize", ATK_XY_SCREEN, expected[0]);
}

static void query_pair(const char *phase, const Expected *expected) {
  if (!g_strcmp0(fixture.first_object, "descendant")) {
    query_object(phase, "descendant", ATK_OBJECT(fixture.leaf), expected->leaf);
    query_object(phase, "plug", fixture.plug, expected->host);
  } else {
    query_object(phase, "plug", fixture.plug, expected->host);
    query_object(phase, "descendant", ATK_OBJECT(fixture.leaf), expected->leaf);
  }
}

static const Expected unavailable = {
    {{-1, -1, -1, -1}, {-1, -1, -1, -1}},
    {{-1, -1, -1, -1}, {-1, -1, -1, -1}}};

/* Deliberately protocol-invalid negative inputs, delivered through the real
 * Socket.Embedded D-Bus method. Never alter the bridge's metadata directly.
 * The public atspi_get_a11y_bus() is also the connection used by the bridge
 * (at-spi2-core 2.52.0 atk-adaptor/bridge.c:1111). */
static void send_invalid_parent_path(void) {
  const gchar *plug_separator = strchr(fixture.plug_id + 1, ':');
  const gchar *parent_separator = strchr(fixture.parent_id + 1, ':');
  const gchar *parent_path = parent_separator + 1;
  const gchar *last_slash = strrchr(parent_path, '/');
  gchar *prefix = g_strndup(parent_path, last_slash - parent_path + 1);
  gchar *altered_path = g_strconcat(prefix,
      fixture.invalid_path_index ? "00" : "0", last_slash + 1, NULL);
  gchar *plug_bus = g_strndup(fixture.plug_id, plug_separator - fixture.plug_id);
  gchar *parent_bus = g_strndup(fixture.parent_id, parent_separator - fixture.parent_id);
  g_free(fixture.pending_parent_id);
  fixture.pending_parent_id = g_strconcat(parent_bus, ":", altered_path, NULL);
  DBusMessage *message = dbus_message_new_method_call(plug_bus, plug_separator + 1,
      "org.a11y.atspi.Socket", "Embedded");
  dbus_message_append_args(message, DBUS_TYPE_STRING, &altered_path, DBUS_TYPE_INVALID);
  dbus_message_set_no_reply(message, TRUE);
  emit("{\"event\":\"invalid_parent_path_sent\",\"case\":\"%s\","
       "\"original_parent_id\":\"%s\",\"wire_parent_path\":\"%s\"}",
       fixture.invalid_path_index ? "leading-double-zero-alias" : "leading-zero-alias",
       fixture.parent_id, altered_path);
  watchdog(fixture.timeout_ms);
  if (!dbus_connection_send(atspi_get_a11y_bus(), message, NULL)) {
    g_printerr("Cannot send negative-case Embedded message\n");
    exit(2);
  }
  dbus_message_unref(message);
  g_free(prefix);
  g_free(altered_path);
  g_free(plug_bus);
  g_free(parent_bus);
}

static gboolean same_bus(const char *first, const char *second) {
  if (!first || !second)
    return FALSE;
  const char *first_separator = strchr(first + 1, ':');
  const char *second_separator = strchr(second + 1, ':');
  return first_separator && second_separator &&
         first_separator - first == second_separator - second &&
         !strncmp(first, second, first_separator - first);
}

static void socket_finalized(gpointer data, GObject *object) {
  (void) object;
  *((gboolean *) data) = TRUE;
}

static void finish(void) {
  watchdog(0);
  fixture.finished = TRUE;
  if (!strcmp(fixture.mode, "remote-plug"))
    write_exchange("done", fixture.failures ? "failed\n" : "passed\n");
  emit("{\"event\":\"summary\",\"mode\":\"%s\",\"checks\":%d,"
       "\"failures\":%d,\"passed\":%s}", fixture.mode, fixture.checks,
       fixture.failures, fixture.failures ? "false" : "true");
  gtk_main_quit();
}

static void exercise(void) {
  invariant("real-host-has-positive-dimensions",
            fixture.expected.host[0].width > 0 && fixture.expected.host[0].height > 0);
  invariant("real-descendant-has-positive-dimensions",
            fixture.expected.leaf[0].width > 0 && fixture.expected.leaf[0].height > 0);
  invariant("descendant-parent-is-real-plug",
            atk_object_get_parent(ATK_OBJECT(fixture.leaf)) == fixture.plug);
  query_pair("embedded", &fixture.expected);

  if (!strcmp(fixture.mode, "destroy-widget")) {
    gtk_widget_destroy(fixture.window);
    fixture.window = NULL;
    invariant("destroyed-widget-detached-from-gtk-accessible",
              gtk_accessible_get_widget(GTK_ACCESSIBLE(fixture.host_accessible)) == NULL);
    query_pair("destroyed-host-widget", &unavailable);
  } else if (!strcmp(fixture.mode, "destroy-parent")) {
    atk_object_set_parent(fixture.socket, NULL);
    query_pair("parentless-socket", &unavailable);
    g_object_weak_ref(G_OBJECT(fixture.socket), socket_finalized,
                      &fixture.socket_finalized);
    g_clear_object(&fixture.socket);
    invariant("socket-was-actually-finalized", fixture.socket_finalized);
    query_pair("stale-parent-path", &unavailable);
  } else if (!strcmp(fixture.mode, "cyclic-parent")) {
    atk_object_set_parent(fixture.socket, fixture.plug);
    invariant("cycle-constructed-through-public-parent-api",
              atk_object_get_parent(fixture.socket) == fixture.plug);
    query_pair("socket-parent-is-plug", &unavailable);
    atk_object_set_parent(fixture.socket, NULL);
  }

  invariant("bridge-parent-identity-preserved",
            !g_strcmp0(fixture.parent_id,
                       g_object_get_data(G_OBJECT(fixture.plug), "dbus-plug-parent")));
  if (!strcmp(fixture.mode, "invalid-parent-path")) {
    fixture.invalid_phase_started = TRUE;
    send_invalid_parent_path();
    return;
  }
  finish();
}

static gboolean tick(gpointer data) {
  (void) data;
  if (!gtk_widget_get_mapped(fixture.host) ||
      !gtk_widget_get_mapped(fixture.leaf_widget))
    return G_SOURCE_CONTINUE;

  if (!strcmp(fixture.mode, "remote-host")) {
    if (!fixture.embedded) {
      gchar *plug_id = read_exchange("plug.id");
      if (!plug_id)
        return G_SOURCE_CONTINUE;
      g_strstrip(plug_id);
      collect_expected();
      save_expected();
      atk_socket_embed(ATK_SOCKET(fixture.socket), plug_id);
      fixture.embedded = TRUE;
      emit("{\"event\":\"remote_host_embedded\",\"plug_id\":\"%s\",\"pid\":%ld}",
           plug_id, (long) getpid());
      g_free(plug_id);
    }
    gchar *done = read_exchange("done");
    if (!done)
      return G_SOURCE_CONTINUE;
    invariant("remote-client-completed-successfully", !strcmp(done, "passed\n"));
    g_free(done);
    finish();
    return G_SOURCE_REMOVE;
  }

  /* Read-only readiness observation of the real bridge handshake. We never
   * forge this ID, set it, or alter an AtkComponent interface table. */
  const gchar *parent_id = g_object_get_data(G_OBJECT(fixture.plug), "dbus-plug-parent");
  if (!parent_id)
    return G_SOURCE_CONTINUE;
  if (fixture.invalid_phase_started) {
    if (g_strcmp0(parent_id, fixture.pending_parent_id))
      return G_SOURCE_CONTINUE;
    watchdog(0);
    const char *name = fixture.invalid_path_index ?
        "leading-double-zero-alias" : "leading-zero-alias";
    emit("{\"event\":\"invalid_parent_path_observed\",\"case\":\"%s\","
         "\"parent_id\":\"%s\"}", name, parent_id);
    query_pair(name, &unavailable);
    fixture.invalid_path_index++;
    if (fixture.invalid_path_index < 2) {
      send_invalid_parent_path();
      return G_SOURCE_CONTINUE;
    }
    finish();
    return G_SOURCE_REMOVE;
  }
  fixture.parent_id = g_strdup(parent_id);
  gboolean remote = !strcmp(fixture.mode, "remote-plug");
  if (remote && !load_expected()) {
    g_clear_pointer(&fixture.parent_id, g_free);
    return G_SOURCE_CONTINUE;
  }
  if (!remote)
    collect_expected();
  watchdog(0);
  emit("{\"event\":\"embedded_observed\",\"plug_id\":\"%s\","
       "\"parent_id\":\"%s\",\"same_bus\":%s,\"pid\":%ld}",
       fixture.plug_id, fixture.parent_id,
       same_bus(fixture.plug_id, parent_id) ? "true" : "false", (long) getpid());
  invariant(remote ? "different-process-bus-identities" : "same-process-bus-identity",
            same_bus(fixture.plug_id, parent_id) != remote);
  if (remote) {
    Rect local = widget_rect(fixture.host_accessible, ATK_XY_SCREEN);
    invariant("remote-oracle-differs-from-plug-local-window",
              local.x != fixture.expected.host[0].x || local.y != fixture.expected.host[0].y);
  }
  exercise();
  return fixture.finished ? G_SOURCE_REMOVE : G_SOURCE_CONTINUE;
}

static void setup_widgets(void) {
  fixture.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(fixture.window), "AT-SPI geometry fixture");
  gtk_window_set_decorated(GTK_WINDOW(fixture.window), FALSE);
  gtk_window_set_default_size(GTK_WINDOW(fixture.window), 640, 420);
  gboolean remote_plug = !strcmp(fixture.mode, "remote-plug");
  gtk_window_move(GTK_WINDOW(fixture.window), remote_plug ? 600 : 110,
                   remote_plug ? 550 : 75);
  GtkWidget *outer = gtk_fixed_new();
  fixture.host = gtk_fixed_new();
  fixture.leaf_widget = gtk_drawing_area_new();
  gtk_widget_set_size_request(fixture.host, 287, 149);
  gtk_widget_set_size_request(fixture.leaf_widget, 83, 47);
  gtk_container_add(GTK_CONTAINER(fixture.window), outer);
  gtk_fixed_put(GTK_FIXED(outer), fixture.host, 41, 29);
  gtk_fixed_put(GTK_FIXED(fixture.host), fixture.leaf_widget, 23, 17);
  gtk_widget_show_all(fixture.window);
  fixture.host_accessible = g_object_ref(gtk_widget_get_accessible(fixture.host));
  fixture.leaf_accessible = g_object_ref(gtk_widget_get_accessible(fixture.leaf_widget));
}

static void setup_plug(void) {
  fixture.plug = atk_plug_new();
  fixture.leaf = g_object_new(geometry_leaf_get_type(), NULL);
  atk_object_initialize(ATK_OBJECT(fixture.leaf), NULL);
  atk_object_set_role(ATK_OBJECT(fixture.leaf), ATK_ROLE_PANEL);
  atk_object_set_name(ATK_OBJECT(fixture.leaf), "GTK-backed recursive geometry leaf");
  g_weak_ref_set(&fixture.leaf->host_widget, fixture.host);
  g_weak_ref_set(&fixture.leaf->leaf_widget, fixture.leaf_widget);
  atk_plug_set_child(ATK_PLUG(fixture.plug), ATK_OBJECT(fixture.leaf));
  fixture.plug_id = atk_plug_get_id(ATK_PLUG(fixture.plug));
  if (!fixture.plug_id) {
    g_printerr("atk_plug_get_id returned NULL; bridge was not initialized\n");
    exit(2);
  }
}

int main(int argc, char **argv) {
  fixture.timeout_ms = 3000;
  GOptionEntry entries[] = {
      {"mode", 0, 0, G_OPTION_ARG_STRING, &fixture.mode,
       "same-process, remote-host, remote-plug, destroy-parent, destroy-widget, cyclic-parent, invalid-parent-path", "MODE"},
      {"first-object", 0, 0, G_OPTION_ARG_STRING, &fixture.first_object,
       "Query plug or descendant first (default plug); useful for separate stock red runs", "OBJECT"},
      {"exchange", 0, 0, G_OPTION_ARG_STRING, &fixture.exchange,
       "Fresh directory shared only by a remote-host/remote-plug pair", "DIRECTORY"},
      {"report", 0, 0, G_OPTION_ARG_STRING, &fixture.report,
       "Also write the NDJSON report to this path", "PATH"},
      {"timeout-ms", 0, 0, G_OPTION_ARG_INT, &fixture.timeout_ms,
       "Watchdog limit for each geometry call (default 3000)", "MILLISECONDS"},
      {NULL, 0, 0, 0, NULL, NULL, NULL}};
  GOptionContext *options = g_option_context_new("- real GTK/ATK geometry integration fixture");
  g_option_context_add_main_entries(options, entries, NULL);
  GError *error = NULL;
  if (!g_option_context_parse(options, &argc, &argv, &error)) {
    g_printerr("%s\n", error->message);
    return 2;
  }
  g_option_context_free(options);
  gboolean remote_host = !g_strcmp0(fixture.mode, "remote-host");
  gboolean remote_plug = !g_strcmp0(fixture.mode, "remote-plug");
  if (!fixture.mode || fixture.timeout_ms < 100 || fixture.timeout_ms > 60000 ||
      (!remote_host && !remote_plug && strcmp(fixture.mode, "same-process") &&
       strcmp(fixture.mode, "destroy-parent") && strcmp(fixture.mode, "destroy-widget") &&
       strcmp(fixture.mode, "cyclic-parent") && strcmp(fixture.mode, "invalid-parent-path")) ||
      (fixture.first_object && strcmp(fixture.first_object, "plug") &&
       strcmp(fixture.first_object, "descendant")) ||
      ((remote_host || remote_plug) && !fixture.exchange)) {
    g_printerr("Valid --mode and --timeout-ms 100..60000 required; remote modes need --exchange\n");
    return 2;
  }
  if (fixture.report) {
    report_fd = open(fixture.report, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (report_fd < 0) {
      perror("open report");
      return 2;
    }
  }
  struct sigaction action = {0};
  action.sa_handler = watchdog_expired;
  sigemptyset(&action.sa_mask);
  sigaction(SIGALRM, &action, NULL);
  /* Include initial GTK/bridge setup in the bounded run. */
  watchdog(MAX(fixture.timeout_ms * 4, 12000));
  gtk_init(&argc, &argv);
  if (atk_bridge_adaptor_init(NULL, NULL) != 0) {
    g_printerr("atk_bridge_adaptor_init failed\n");
    return 2;
  }
  emit("{\"event\":\"start\",\"mode\":\"%s\",\"pid\":%ld,"
       "\"gtk_version\":\"%u.%u.%u\",\"atk_version\":\"%s\",\"timeout_ms\":%d}",
       fixture.mode, (long) getpid(), gtk_get_major_version(), gtk_get_minor_version(),
       gtk_get_micro_version(), atk_get_version(), fixture.timeout_ms);
  report_loaded_libraries();
  setup_widgets();
  if (!remote_plug) {
    fixture.socket = atk_socket_new();
    /* Match GtkSocketAccessible's real parent linkage. */
    atk_object_set_parent(fixture.socket, fixture.host_accessible);
  }
  if (!remote_host) {
    setup_plug();
    if (remote_plug) {
      if (!write_exchange("plug.id", fixture.plug_id))
        return 2;
    } else {
      atk_socket_embed(ATK_SOCKET(fixture.socket), fixture.plug_id);
    }
  }
  g_timeout_add(10, tick, NULL);
  gtk_main();
  watchdog(0);
  if (fixture.socket)
    atk_object_set_parent(fixture.socket, NULL);
  if (fixture.window)
    gtk_widget_destroy(fixture.window);
  g_clear_object(&fixture.socket);
  g_clear_object(&fixture.plug);
  g_clear_object(&fixture.leaf);
  g_clear_object(&fixture.host_accessible);
  g_clear_object(&fixture.leaf_accessible);
  g_free(fixture.plug_id);
  g_free(fixture.parent_id);
  g_free(fixture.pending_parent_id);
  g_free(fixture.mode);
  g_free(fixture.exchange);
  g_free(fixture.report);
  g_free(fixture.first_object);
  if (report_fd >= 0)
    close(report_fd);
  return fixture.finished && !fixture.failures ? 0 : 1;
}
