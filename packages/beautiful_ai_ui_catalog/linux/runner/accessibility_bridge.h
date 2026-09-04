#ifndef CATALOG_RUNNER_ACCESSIBILITY_BRIDGE_H_
#define CATALOG_RUNNER_ACCESSIBILITY_BRIDGE_H_

#include <flutter_linux/flutter_linux.h>

// Repairs only a missing parent on the real FlView's direct AtkSocket child.
// Returns TRUE only if this call installs the missing link. Existing parents
// and different/future accessibility implementations are left untouched.
gboolean catalog_repair_accessible_socket_parent(FlView* view);

#endif  // CATALOG_RUNNER_ACCESSIBILITY_BRIDGE_H_
