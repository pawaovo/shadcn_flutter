"""Explicit, fail-closed authority and artifact binding for owned SDK diagnostics.

This mode is distinct from GitHub Actions. It never sets or impersonates CI
environment variables and never accepts a stock release as a patched engine.
"""

import hashlib
import json
import os
from pathlib import Path
import platform
import re
import socket
import subprocess
import sys

WORK = Path("/work")
SDK_REVISION = "4cf24164269a5ebf0c16a028a00727d0e77bbb05"
PATCH_SHA256 = "edff45421907b259cd3b31330816e5f5c35d3ec83e31847d41aaacab773d4394"
NODE_SHA256 = "dbb1e3bf353dd6ec2b8f85866854cc09c6befe2e3990f213a97ca79c48426ded"
ENGINE_NAME = "host_debug_unopt_arm64"


def digest(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def record(path):
    path = Path(path).resolve()
    return {"path": str(path), "sha256": digest(path)}


def checked_record(value):
    path = Path(value["path"]).resolve()
    if not re.fullmatch(r"[0-9a-f]{64}", value["sha256"]) or digest(path) != value["sha256"]:
        raise RuntimeError(f"Bound file hash differs: {path}")
    return path


def build_command(context):
    sdk = Path(context["sdk_root"]).resolve()
    return [str(sdk / "bin/flutter"), f"--local-engine-src-path={sdk / 'engine/src'}",
            f"--local-engine={ENGINE_NAME}", f"--local-engine-host={ENGINE_NAME}",
            "build", "linux", "--debug", "--no-pub", "--target=lib/main.dart"]


def validate_manifest(path, catalog_root, *, current_sources=None, verify_files=True):
    if (sys.platform != "linux" or platform.machine() not in ("aarch64", "arm64")
            or not Path("/.dockerenv").is_file()):
        raise RuntimeError("Isolated SDK mode requires an actual disposable Linux container")
    if os.environ.get("GITHUB_ACTIONS") == "true":
        raise RuntimeError("Isolated SDK mode must not impersonate GitHub Actions")
    data = json.loads(Path(path).read_text())
    if data.get("scope") != "isolated_sdk_runtime_diagnostic" or data.get("build_mode") != "debug":
        raise RuntimeError("Expected an explicit isolated debug SDK manifest")
    if data.get("sdk_revision") != SDK_REVISION:
        raise RuntimeError("Unexpected SDK revision")
    root = Path(catalog_root).resolve()
    if root != Path(data["catalog_root"]).resolve() or WORK not in root.parents:
        raise RuntimeError("The fixture root is not this owned container checkout")
    identity_path = checked_record(data["container_identity"])
    if identity_path != WORK / "container-identity.json":
        raise RuntimeError("Unexpected container identity location")
    identity = json.loads(identity_path.read_text())
    container_id = identity.get("id", "")
    if (not re.fullmatch(r"[0-9a-f]{64}", container_id)
            or socket.gethostname() != container_id[:12]
            or identity.get("platform") != "linux" or identity.get("architecture") != "arm64"
            or not identity.get("name", "").startswith("beautiful-flutter-gtk-build-")
            or identity.get("labels", {}).get("beautiful.owner") != "linux-sdk-runtime-build"):
        raise RuntimeError("Manifest does not identify this explicitly owned container")
    if identity.get("cpus") != 4 or identity.get("memory_bytes") != 8 * 1024 ** 3:
        raise RuntimeError("Owned container resource bounds differ")
    expected_mounts = {"/work": True, "/plan": False, "/proof": False}
    if identity.get("mounts") != expected_mounts:
        raise RuntimeError("Unexpected host mounts in the isolated diagnostic container")
    owner = json.loads((WORK / "owner.json").read_text())
    if owner != {"purpose": "beautiful-linux-sdk-runtime-build", "sdk_revision": SDK_REVISION}:
        raise RuntimeError("The work directory is not owned by this SDK build")
    sdk = Path(data["sdk_root"]).resolve()
    if sdk != WORK / "flutter":
        raise RuntimeError("Only the isolated SDK checkout can supply the engine")
    library = sdk / "engine/src/out" / ENGINE_NAME / "libflutter_linux_gtk.so"
    if Path(data["engine_library"]["path"]).resolve() != library:
        raise RuntimeError("Unexpected generated GTK engine path")
    if data.get("expected_build_command") != build_command(data):
        raise RuntimeError("The manifest does not request the explicit local debug engine")
    if not isinstance(data.get("fixture_source_sha256"), dict) or not data["fixture_source_sha256"]:
        raise RuntimeError("Fixture source binding is missing")
    if verify_files:
        if current_sources != data["fixture_source_sha256"]:
            raise RuntimeError("Fixture sources differ from the runtime manifest")
        if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=sdk, text=True).strip() != SDK_REVISION:
            raise RuntimeError("SDK checkout moved after compilation")
        if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip() != data["catalog_git_head"]:
            raise RuntimeError("Catalog checkout moved after manifest creation")
        if checked_record(data["patch"]).name != "flutter-3.47.0-atk-name-expanded.patch" or data["patch"]["sha256"] != PATCH_SHA256:
            raise RuntimeError("Patch differs from the reviewed native source proof")
        if digest(sdk / "engine/src/flutter/shell/platform/linux/fl_accessible_node.cc") != NODE_SHA256:
            raise RuntimeError("SDK source differs from the verified patch")
        binding = json.loads(checked_record(data["source_build_binding"]).read_text())
        artifact = json.loads(checked_record(data["engine_artifact"]).read_text())
        if (binding.get("sdk_revision") != SDK_REVISION or binding.get("patch_sha256") != PATCH_SHA256
                or binding.get("patched_node_sha256") != NODE_SHA256 or binding.get("mode") != "debug-unoptimized"):
            raise RuntimeError("Full engine source/build binding differs")
        if (artifact.get("status") != "built_not_runtime_accepted" or artifact.get("sdk_revision") != SDK_REVISION
                or artifact.get("source_build_binding_sha256") != data["source_build_binding"]["sha256"]
                or artifact.get("library") != str(library)
                or artifact.get("library_sha256") != data["engine_library"]["sha256"]):
            raise RuntimeError("Generated engine artifact is not bound to the source build")
        checked_record(data["engine_library"])
    return data


def verify_loaded_engine(pid, expected_sha256):
    # Actual mappings prove which library this process loaded; a copied bundle
    # file alone cannot establish that the dynamic loader selected it.
    paths = set()
    for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) == 6 and fields[5].endswith("/libflutter_linux_gtk.so"):
            paths.add(Path(fields[5]).resolve())
    if len(paths) != 1:
        raise RuntimeError(f"Expected exactly one actual mapped GTK engine, found {paths}")
    library = paths.pop()
    if digest(library) != expected_sha256:
        raise RuntimeError("The running Catalog loaded a different engine library")
    return {"pid": pid, "path": str(library), "sha256": expected_sha256,
            "source": "actual /proc/PID/maps and mapped-file hash"}
