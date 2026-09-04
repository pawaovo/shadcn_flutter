#!/usr/bin/env python3
"""Build stock/patched ATK bridge in owned prefixes; never install system-wide."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

PIN = "46c8de80022d28eef2da58f1054b5bff745ed7e0"
WORK = Path("/work/atspi-geometry")
PATCH = Path(__file__).with_name("at-spi2-core-2.52-same-process-geometry.patch")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(command, logdir, name, **kwargs):
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with (logdir / (name + ".log")).open("xb") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, **kwargs)
    (logdir / (name + ".json")).write_text(json.dumps({
        "command": command, "cwd": str(kwargs.get("cwd", Path.cwd())),
        "started_utc": started, "exit_code": result.returncode}, indent=2) + "\n")
    result.check_returncode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("variant", choices=("stock", "patched"))
    parser.add_argument("--output-tag", help="Fresh output label when a reviewed patch evolves")
    args = parser.parse_args()
    if (sys.platform != "linux" or not Path("/.dockerenv").exists()
            or not Path("/work/owner.json").is_file()):
        raise SystemExit("Requires the explicit owned Linux SDK build container")
    variant = args.variant
    tag = args.output_tag or variant
    if not re.fullmatch(re.escape(variant) + r"(?:-[a-z0-9]+)*", tag):
        raise SystemExit("Output tag must start with the variant and contain only simple suffixes")
    source = WORK / ("source" if variant == "stock" else "patched")
    if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip() != PIN:
        raise SystemExit("Wrong GNOME source revision")
    diff = subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=source)
    if variant == "stock" and diff:
        raise SystemExit("Stock source must be unchanged")
    if variant == "patched" and diff != PATCH.read_bytes():
        raise SystemExit("Patched source must match the exact reviewed patch")
    manifest = WORK / (tag + "-artifact.json")
    if manifest.exists():
        raise SystemExit("Completed artifacts are immutable; use a fresh experiment directory")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    logs = WORK / "logs" / (tag + "-" + stamp)
    logs.mkdir(parents=True, exist_ok=False)
    (logs / "source.patch").write_bytes(diff)
    build = WORK / ("build-" + variant)
    prefix = WORK / ("prefix-" + tag)
    options = ["--prefix=" + str(prefix), "--libdir=lib", "-Dintrospection=disabled",
               "-Ddocs=false", "-Dgtk2_atk_adaptor=false"]
    setup = (["meson", "configure", str(build)] if (build / "build.ninja").exists()
             else ["meson", "setup", str(build), str(source)])
    run(setup + options, logs, "configure")
    run(["ninja", "-C", str(build), "-j4", "-l4"], logs, "build")
    run(["meson", "install", "-C", str(build), "--no-rebuild"], logs, "install")
    # Select only the bridge shared library. Its installed ELF has no build
    # RUNPATH; all other GTK/ATK/AT-SPI dependencies remain the installed system
    # versions. LD_LIBRARY_PATH is explicit for a diagnostic process only.
    library_name = "libatk-bridge-2.0.so.0.0.0"
    installed = prefix / "lib" / library_name
    dynamic = subprocess.check_output(["readelf", "-d", str(installed)], text=True)
    if "(RPATH)" in dynamic or "(RUNPATH)" in dynamic:
        raise SystemExit("Installed bridge unexpectedly retains a dependency search override")
    selected = WORK / ("runtime-" + tag)
    selected.mkdir(exist_ok=False)
    library = selected / library_name
    shutil.copyfile(installed, library)
    for name in ("libatk-bridge-2.0.so.0", "libatk-bridge-2.0.so"):
        (selected / name).symlink_to(library_name)
    (logs / "readelf-dynamic.log").write_text(dynamic)
    run(["ldd", str(library)], logs, "linked-dependencies",
        env={**os.environ, "LD_LIBRARY_PATH": str(selected)})
    record = {"schema_version": 1, "scope": "isolated native dependency diagnostic",
              "variant": variant, "output_tag": tag, "source_pin": PIN, "source": str(source),
              "source_diff_sha256": hashlib.sha256(diff).hexdigest(),
              "patch_sha256": sha(PATCH) if variant == "patched" else None,
              "library": str(library), "sha256": sha(library),
              "bytes": library.stat().st_size, "runtime_library_directory": str(selected),
              "logs": str(logs), "system_libraries_replaced": False,
              "application_acceptance": "not_accepted"}
    manifest.write_text(json.dumps(record, indent=2) + "\n")
    print(manifest)


if __name__ == "__main__":
    main()
