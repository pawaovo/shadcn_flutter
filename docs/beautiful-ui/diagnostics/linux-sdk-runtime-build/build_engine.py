#!/usr/bin/env python3
"""Build the actual pinned Linux GTK embedding in the owned /work directory.

Run only in the documented disposable Linux arm64 container. It has no global
SDK or Docker socket mount. Each real command retains its own attempt log.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time

SDK_REVISION = "4cf24164269a5ebf0c16a028a00727d0e77bbb05"
DEPOT_REVISION = "580b4ff3f5cd0dcaa2eacda28cefe0f45320e8f7"
WORK = Path("/work")
SDK = WORK / "flutter"
DEPOT = WORK / "depot_tools"
PLAN = Path("/plan")
PROOF = Path("/proof")
OUTPUT = SDK / "engine/src/out/host_debug_unopt_arm64"
TARGETS = [
    "flutter/shell/platform/linux:flutter_gtk",
    "flutter/build/archives:flutter_patched_sdk",
    "flutter/build/archives:dart_sdk_archive",
    "flutter/sky",
]


def write(path, value):
    temporary = path.with_suffix(path.suffix + ".next")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(label, command, cwd=WORK):
    attempt = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    log = WORK / "logs" / f"{attempt}-{label}.log"
    status = {"stage": label, "command": command, "cwd": str(cwd),
              "started_utc": attempt, "log": str(log), "status": "running"}
    write(WORK / "status.json", status)
    print(f"[{label}] {log}", flush=True)
    start = time.monotonic()
    with log.open("wb") as stream:
        result = subprocess.run(command, cwd=cwd, env=ENV,
                                stdout=stream, stderr=subprocess.STDOUT)
    status.update(exit_code=result.returncode,
                  elapsed_seconds=round(time.monotonic() - start, 3),
                  status="passed" if result.returncode == 0 else "failed")
    write(log.with_suffix(".json"), status)
    write(WORK / "status.json", status)
    if result.returncode:
        raise RuntimeError(f"{label} exited {result.returncode}; original log: {log}")


def output(command, cwd=WORK):
    return subprocess.check_output(command, cwd=cwd, env=ENV, text=True).strip()


def checkout(directory, remote, revision, label):
    if not (directory / ".git").exists():
        directory.mkdir(exist_ok=True)
        if any(directory.iterdir()):
            raise RuntimeError(f"Refusing to adopt a nonempty checkout directory: {directory}")
        run(label + "-init", ["git", "init", str(directory)])
        run(label + "-remote", ["git", "remote", "add", "origin", remote], directory)
    actual_remote = output(["git", "remote", "get-url", "origin"], directory)
    if actual_remote != remote:
        raise RuntimeError(f"Unexpected remote in {directory}")
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=directory,
                            capture_output=True, text=True)
    current = result.stdout.strip() if result.returncode == 0 else None
    if current != revision:
        if current:
            raise RuntimeError(f"Checkout has a different revision: {directory}: {current}")
        run(label + "-fetch", ["git", "fetch", "--depth=1", "--no-tags", "origin", revision], directory)
        run(label + "-checkout", ["git", "checkout", "--detach", revision], directory)
    if output(["git", "rev-parse", "HEAD"], directory) != revision:
        raise RuntimeError(f"Revision verification failed: {directory}")


def bootstrap():
    checkout(DEPOT, "https://chromium.googlesource.com/chromium/tools/depot_tools.git",
             DEPOT_REVISION, "depot")
    checkout(SDK, "https://github.com/flutter/flutter.git", SDK_REVISION, "sdk")
    # Flutter's package solver derives the framework version from Git tags.
    # Fetch the official tag and verify it points to the already pinned commit;
    # do not invent a local version tag or alter the source revision.
    run("sdk-release-tag", ["git", "fetch", "--depth=1", "origin",
                           "refs/tags/3.47.0:refs/tags/3.47.0"], SDK)
    if output(["git", "rev-parse", "refs/tags/3.47.0^{}"], SDK) != SDK_REVISION:
        raise RuntimeError("Official release tag does not match the pinned source")
    pinned_deps = subprocess.check_output(["git", "show", f"{SDK_REVISION}:DEPS"], cwd=SDK)
    if (SDK / "DEPS").read_bytes() != pinned_deps:
        raise RuntimeError("DEPS differs from the pinned official commit")
    shutil.copyfile(PLAN / "linux-only.gclient", SDK / ".gclient")
    write(WORK / "checkout.json", {
        "sdk_revision": SDK_REVISION, "depot_revision": DEPOT_REVISION,
        "deps_sha256": sha(SDK / "DEPS"), "gclient_sha256": sha(SDK / ".gclient"),
        "platform": platform.platform(), "machine": platform.machine(),
        "scope": "Isolated full official engine build; no global SDK modified",
    })


def sync():
    run("dependency-sync", [str(DEPOT / "gclient"), "sync", "--no-history", "--nohooks", "--jobs=4"], SDK)
    run("dependency-hooks", [str(DEPOT / "gclient"), "runhooks"], SDK)
    run("dependency-revisions", [str(DEPOT / "gclient"), "revinfo", "--actual"], SDK)
    run("native-clang", [str(SDK / "engine/src/flutter/buildtools/linux-arm64/clang/bin/clang"), "--version"])
    run("native-gn", [str(SDK / "engine/src/flutter/third_party/gn/gn"), "--version"])
    run("native-ninja", [str(SDK / "third_party/ninja/ninja"), "--version"])


def configure():
    patch = PROOF / "flutter-3.47.0-atk-name-expanded.patch"
    reverse = subprocess.run(["git", "apply", "--reverse", "--check", str(patch)],
                             cwd=SDK, env=ENV, capture_output=True)
    if reverse.returncode:
        run("patch-check", ["git", "apply", "--check", str(patch)], SDK)
        run("apply-sdk-patch", ["git", "apply", str(patch)], SDK)
    changed = output(["git", "diff", "--name-only", "HEAD"], SDK).splitlines()
    if changed != ["engine/src/flutter/shell/platform/linux/fl_accessible_node.cc"]:
        raise RuntimeError(f"Unexpected tracked SDK changes: {changed}")
    proof = json.loads((PROOF / "evidence/source-manifest.json").read_text())
    node = SDK / "engine/src/flutter/shell/platform/linux/fl_accessible_node.cc"
    if sha(node) != proof["patched_source_sha256"]:
        raise RuntimeError("Applied source differs from the verified SDK patch")
    run("gn-configure", ["python3", "flutter/tools/gn",
        "--target-dir=host_debug_unopt_arm64", "--target-os=linux", "--linux-cpu=arm64",
        "--runtime-mode=debug", "--unoptimized", "--no-lto", "--no-goma",
        "--no-enable-unittests", "--prebuilt-dart-sdk", "--gn-args=concurrent_toolchain_jobs=4"], SDK / "engine/src")
    write(WORK / "source-build-binding.json", {
        "sdk_revision": SDK_REVISION, "patch_sha256": sha(patch),
        "patched_node_sha256": sha(node), "gn_args_sha256": sha(OUTPUT / "args.gn"),
        "targets": TARGETS, "mode": "debug-unoptimized",
        "performance_acceptance": "not_applicable", "application_acceptance": "not_accepted",
    })
    run("build-plan", [str(SDK / "third_party/ninja/ninja"), "-C", str(OUTPUT), "-n", *TARGETS])


def build():
    run("engine-build", [str(SDK / "third_party/ninja/ninja"), "-C", str(OUTPUT), "-j4", "-l4", *TARGETS])
    library = OUTPUT / "libflutter_linux_gtk.so"
    if not library.is_file():
        raise RuntimeError("The actual GTK embedding library was not produced")
    run("embedding-dependencies", ["ldd", str(library)])
    run("embedding-symbols", ["nm", "-D", "--defined-only", str(library)])
    write(WORK / "engine-artifact.json", {
        "status": "built_not_runtime_accepted", "sdk_revision": SDK_REVISION,
        "library": str(library), "library_bytes": library.stat().st_size,
        "library_sha256": sha(library), "mode": "debug-unoptimized",
        "source_build_binding_sha256": sha(WORK / "source-build-binding.json"),
        "application_acceptance": "not_accepted", "screen_reader_acceptance": "not_accepted",
    })


ENV = os.environ.copy()
ENV["PATH"] = str(DEPOT) + os.pathsep + ENV.get("PATH", "")
ENV["DEPOT_TOOLS_UPDATE"] = "0"
ENV["DEPOT_TOOLS_METRICS"] = "0"
ENV["CIPD_CACHE_DIR"] = str(WORK / "cipd-cache")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["bootstrap", "sync", "configure", "build", "all"])
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in ("aarch64", "arm64"):
        raise SystemExit("This plan requires native Linux arm64; no disguised host architecture")
    if not Path("/.dockerenv").exists():
        raise SystemExit("Run only inside the explicitly owned disposable container")
    owner = WORK / "owner.json"
    identity = {"purpose": "beautiful-linux-sdk-runtime-build", "sdk_revision": SDK_REVISION}
    if owner.exists():
        if json.loads(owner.read_text()) != identity:
            raise SystemExit("The output directory belongs to a different build")
    else:
        if any(WORK.iterdir()):
            raise SystemExit("New builds require an empty output directory")
        write(owner, identity)
    (WORK / "logs").mkdir(exist_ok=True)
    stages = {"bootstrap": bootstrap, "sync": sync, "configure": configure, "build": build}
    for name in stages if args.stage == "all" else [args.stage]:
        stages[name]()


if __name__ == "__main__":
    main()
