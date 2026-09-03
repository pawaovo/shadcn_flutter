#!/usr/bin/env bash
# Native profile evidence runner. Extra arguments are forwarded as exact argv.
set -euo pipefail

p3_catalog_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
p3_device="${1:-macos}"
if (( $# > 0 )); then shift; fi
p3_suite="${P3_PERF_SUITE:-p3}"
case "$p3_suite" in
  p3) p3_target=integration_test/p3_performance_test.dart ;;
  p1p2|all) p3_target=integration_test/release_performance_test.dart ;;
  *) printf 'P3_PERF_SUITE must be p3, p1p2 or all: %s\n' "$p3_suite" >&2; exit 2 ;;
esac
p3_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
p3_output="${P3_PERF_OUTPUT_DIR:-$p3_catalog_root/build/p3-profile/$p3_stamp}"
p3_mise="${P3_MISE_BIN:-/opt/homebrew/bin/mise}"
# A retry must not combine new launch metadata with an earlier successful run.
# Include hidden files, and reject before touching any existing evidence.
if [[ -d "$p3_output" ]]; then
  shopt -s nullglob dotglob
  p3_existing_entries=("$p3_output"/*)
  shopt -u nullglob dotglob
  if (( ${#p3_existing_entries[@]} > 0 )); then
    printf 'Evidence directory is not empty: %s\nChoose a new output directory for each run.\n' "$p3_output" >&2
    exit 2
  fi
fi
mkdir -p -- "$p3_output"
p3_output="$(cd -- "$p3_output" && pwd)"
p3_phase=preflight
p3_record_exit() {
  local p3_exit_status=$?
  local p3_run_status=failed
  trap - EXIT
  if (( p3_exit_status == 0 )); then p3_run_status=complete; fi
  printf '{"status":"%s","phase":"%s","exit_code":%s}\n' \
    "$p3_run_status" "$p3_phase" "$p3_exit_status" > "$p3_output/runner_status.json"
  printf '%s\n' "$p3_exit_status" > "$p3_output/exit_code.txt"
  exit "$p3_exit_status"
}
trap p3_record_exit EXIT
if [[ ! -x "$p3_mise" ]]; then
  printf 'mise executable not found: %s\nSet P3_MISE_BIN to the local executable.\n' "$p3_mise" >&2
  exit 2
fi
export P3_PERF_OUTPUT_DIR="$p3_output"
export P3_PERF_DEVICE_ID="$p3_device"
export P3_PERF_SUITE="$p3_suite"
if [[ "$p3_device" == macos && -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
cd -- "$p3_catalog_root"
p3_phase=flutter_version
"$p3_mise" exec -- flutter --version --machine > "$p3_output/flutter_version.json"
# Native plugin generation must see the same full-Xcode environment as the
# build; the global xcode-select may intentionally still point at CLT.
p3_phase=pub_get
"$p3_mise" exec -- flutter pub get 2>&1 | tee "$p3_output/pub_get.log"
p3_phase=source_capture
python3 tool/profile_source_snapshot.py capture "$p3_output/source_before.json"
p3_command=(
  "$p3_mise" exec -- flutter drive
  -d "$p3_device" --profile --no-dds --no-pub
  --driver=test_driver/p3_performance_driver.dart
  "--target=$p3_target"
  "--dart-define=P3_PERF_SUITE=$p3_suite"
  "--dart-define=P3_DEVICE_LABEL=$p3_device"
  "$@"
)
printf '%q ' "${p3_command[@]}" > "$p3_output/launch_command.txt"
printf '\n' >> "$p3_output/launch_command.txt"
printf 'Evidence directory: %s\n' "$p3_output"
printf 'Performance suite: %s\n' "$p3_suite"
printf 'The native window must be at least 1120 x 720 logical pixels. Resize it when the waiting screen appears.\n'
printf 'Activate the app and click Start native measurements; restored dimensions alone do not start capture.\n'
printf 'After measurement starts, leave this window visible and stop interacting until the process exits.\n'
p3_phase=driver
set +e
"${p3_command[@]}" 2>&1 | tee "$p3_output/launch.log"
p3_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$p3_status" > "$p3_output/driver_exit_code.txt"
p3_phase=source_comparison
set +e
python3 tool/profile_source_snapshot.py compare \
  "$p3_output/source_before.json" "$p3_output/source_after.json" \
  > "$p3_output/source_integrity.json"
p3_source_status=$?
set -e
p3_phase=finalizer
set +e
"$p3_mise" exec -- dart run test_driver/p3_performance_driver.dart --finalize "$p3_output" "$p3_status"
p3_finalize_status=$?
set -e
if (( p3_status == 0 )); then p3_status=$p3_finalize_status; fi
if (( p3_status == 0 )); then p3_status=$p3_source_status; fi
p3_phase=finalized
exit "$p3_status"
