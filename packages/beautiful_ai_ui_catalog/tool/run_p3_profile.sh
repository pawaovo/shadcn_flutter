#!/usr/bin/env bash
# Native profile evidence runner. Extra arguments are forwarded as exact argv.
set -euo pipefail

p3_catalog_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
p3_device="${1:-macos}"
if (( $# > 0 )); then shift; fi
p3_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
p3_output="${P3_PERF_OUTPUT_DIR:-$p3_catalog_root/build/p3-profile/$p3_stamp}"
p3_mise="${P3_MISE_BIN:-/opt/homebrew/bin/mise}"
if [[ ! -x "$p3_mise" ]]; then
  printf 'mise executable not found: %s\nSet P3_MISE_BIN to the local executable.\n' "$p3_mise" >&2
  exit 2
fi
mkdir -p -- "$p3_output"
p3_output="$(cd -- "$p3_output" && pwd)"
export P3_PERF_OUTPUT_DIR="$p3_output"
export P3_PERF_DEVICE_ID="$p3_device"
if [[ "$p3_device" == macos && -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
cd -- "$p3_catalog_root"
"$p3_mise" exec -- flutter --version --machine > "$p3_output/flutter_version.json"
p3_command=(
  "$p3_mise" exec -- flutter drive
  -d "$p3_device" --profile --no-dds
  --driver=test_driver/p3_performance_driver.dart
  --target=integration_test/p3_performance_test.dart
  "--dart-define=P3_DEVICE_LABEL=$p3_device"
  "$@"
)
printf '%q ' "${p3_command[@]}" > "$p3_output/launch_command.txt"
printf '\n' >> "$p3_output/launch_command.txt"
printf 'Evidence directory: %s\n' "$p3_output"
printf 'The native window must be at least 1120 x 720 logical pixels. Resize it when the waiting screen appears.\n'
printf 'After measurement starts, leave this window visible and stop interacting until the process exits.\n'
set +e
"${p3_command[@]}" 2>&1 | tee "$p3_output/launch.log"
p3_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$p3_status" > "$p3_output/driver_exit_code.txt"
set +e
"$p3_mise" exec -- dart run test_driver/p3_performance_driver.dart --finalize "$p3_output" "$p3_status"
p3_finalize_status=$?
set -e
if (( p3_status == 0 )); then p3_status=$p3_finalize_status; fi
printf '%s\n' "$p3_status" > "$p3_output/exit_code.txt"
exit "$p3_status"
