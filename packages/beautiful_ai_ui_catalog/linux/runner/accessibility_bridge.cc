#include "accessibility_bridge.h"

#include <atk/atk.h>

namespace {

struct InstalledParentLink {
  GWeakRef socket;
  GWeakRef wrapper;
};

void clear_installed_parent(GtkWidget*, gpointer data) {
  auto* link = static_cast<InstalledParentLink*>(data);
  g_autoptr(AtkObject) socket = ATK_OBJECT(g_weak_ref_get(&link->socket));
  g_autoptr(AtkObject) wrapper = ATK_OBJECT(g_weak_ref_get(&link->wrapper));
  // Do not clear a link that another owner replaced after initialization.
  if (socket != nullptr && wrapper != nullptr && atk_object_get_parent(socket) == wrapper) {
    atk_object_set_parent(socket, nullptr);
  }
}

void free_installed_link(gpointer data, GClosure*) {
  auto* link = static_cast<InstalledParentLink*>(data);
  g_weak_ref_clear(&link->socket);
  g_weak_ref_clear(&link->wrapper);
  delete link;
}

}  // namespace

gboolean catalog_repair_accessible_socket_parent(FlView* view) {
  g_return_val_if_fail(FL_IS_VIEW(view), FALSE);

  // Flutter 3.47 already creates this wrapper in fl_view_new/setup_engine.
  // Match GtkSocketAccessible's public parent link without changing SDK code.
  AtkObject* wrapper = gtk_widget_get_accessible(GTK_WIDGET(view));
  if (wrapper == nullptr || atk_object_get_n_accessible_children(wrapper) < 1) {
    return FALSE;
  }
  g_autoptr(AtkObject) socket = atk_object_ref_accessible_child(wrapper, 0);
  if (socket == nullptr || !ATK_IS_SOCKET(socket) ||
      atk_object_get_parent(socket) != nullptr) {
    return FALSE;
  }

  // ATK retains the parent. Pair only our installed link with GtkWidget destroy
  // so it cannot cycle with the wrapper's existing ownership of the socket.
  atk_object_set_parent(socket, wrapper);
  if (atk_object_get_parent(socket) != wrapper) {
    return FALSE;
  }
  auto* link = new InstalledParentLink;
  g_weak_ref_init(&link->socket, socket);
  g_weak_ref_init(&link->wrapper, wrapper);
  g_signal_connect_data(view, "destroy", G_CALLBACK(clear_installed_parent), link,
                        free_installed_link, static_cast<GConnectFlags>(0));
  return TRUE;
}
