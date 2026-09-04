# Local physical-device discovery — 2026-09-04

The fresh read-only CoreDevice query completed successfully with **zero known
devices**. It used the installed Xcode `devicectl 506.6`, a ten-second command
limit and its supported JSON output. No iOS physical-device smoke or reader task
was performed.

`adb` did not resolve on the current shell PATH, the Catalog Android local
properties supplied no `sdk.dir`, and the default
`/Users/zzz/Library/Android/sdk/platform-tools/adb` was absent. Therefore no new
ADB device query was performed. This does **not** establish that Android hardware
is absent or that no SDK exists at any other location.

The [JSON record](2026-09-04-local-device-inventory.json) contains the exact
scope, raw CoreDevice file identity/hash and observed file timestamp. These
observations refresh the available local discovery evidence; they do not
replace physical-device, input-method or assistive-technology acceptance.
