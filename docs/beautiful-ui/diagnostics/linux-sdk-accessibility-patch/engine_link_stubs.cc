// This unit target never creates or starts a Flutter engine. These are its only
// two engine link dependencies; all ATK/GObject behavior uses the real libraries.
#include "flutter/shell/platform/linux/fl_engine_private.h"

GType fl_engine_get_type() {
  // The tested node's construct-only engine property is always null. No object
  // is represented as a real running FlEngine by this unit-only type provider.
  return G_TYPE_OBJECT;
}

void fl_engine_dispatch_semantics_action(FlEngine*, FlutterViewId, uint64_t,
                                        FlutterSemanticsAction, GBytes*) {
  g_error("Unexpected engine dispatch: this unit proof cannot execute Dart or accept an application");
}
