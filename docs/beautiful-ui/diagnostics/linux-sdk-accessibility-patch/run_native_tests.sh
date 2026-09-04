#!/bin/sh
set -eu
export PROOF_WORK_DIR="${PROOF_WORK_DIR:-/work}"

# Run inside the documented disposable container: /sdk and /proof are read-only;
# /work contains the two source copies created by prepare_sources.py.
for variant in original patched; do
  cmake -S /proof -B "$PROOF_WORK_DIR/build-$variant" -G Ninja \
    -DCMAKE_CXX_COMPILER=clang++ -DSDK_SOURCE_ROOT=/sdk \
    -DNODE_SOURCE="$PROOF_WORK_DIR/$variant/engine/src/flutter/shell/platform/linux/fl_accessible_node.cc" \
    > "$PROOF_WORK_DIR/$variant-configure.log" 2>&1
  cmake --build "$PROOF_WORK_DIR/build-$variant" --parallel 2 \
    > "$PROOF_WORK_DIR/$variant-build.log" 2>&1
  status=0
  "$PROOF_WORK_DIR/build-$variant/atk_source_test" --gtest_output="json:$PROOF_WORK_DIR/$variant-tests.json" \
    > "$PROOF_WORK_DIR/$variant-tests.log" 2>&1 || status=$?
  printf '%s\n' "$status" > "$PROOF_WORK_DIR/$variant-exit-code.txt"
done

ldd "$PROOF_WORK_DIR/build-patched/atk_source_test" > "$PROOF_WORK_DIR/linked-libraries.txt"
python3 - <<'PY'
import hashlib, json, os, platform, subprocess
from pathlib import Path
root = Path(os.environ['PROOF_WORK_DIR'])
original = json.loads((root / 'original-tests.json').read_text())
patched = json.loads((root / 'patched-tests.json').read_text())
old_exit = int((root / 'original-exit-code.txt').read_text())
new_exit = int((root / 'patched-exit-code.txt').read_text())
passed = (original['tests'] == 10 and original['failures'] == 8 and old_exit == 1
          and patched['tests'] == 10 and patched['failures'] == 0 and new_exit == 0)
files = ['source-manifest.json', 'original-tests.json', 'original-tests.log',
         'patched-tests.json', 'patched-tests.log', 'linked-libraries.txt']
report = {
    'status': 'native_source_red_green_verified' if passed else 'not_verified',
    'platform': platform.platform(),
    'libraries': subprocess.check_output(['pkg-config', '--modversion', 'gtk+-3.0', 'atk', 'glib-2.0'], text=True).splitlines(),
    'compiler': subprocess.check_output(['clang++', '--version'], text=True).splitlines()[0],
    'baseline': {'tests': original['tests'], 'failures': original['failures'], 'exit_code': old_exit},
    'patched': {'tests': patched['tests'], 'failures': patched['failures'], 'exit_code': new_exit},
    'engine_boundary': 'Null engine only; GType link provider and aborting dispatch stub. No ATK/GObject mocks.',
    'application_acceptance': 'not_accepted', 'screen_reader_acceptance': 'not_accepted',
    'files': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files},
}
(root / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
raise SystemExit(0 if passed else 1)
PY
