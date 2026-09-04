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
ATK_SOURCE_REVISION = "46c8de80022d28eef2da58f1054b5bff745ed7e0"
ATK_PATCH_SHA256 = "2315f3fbb206a85af9baefedca8030751e26f01c629e9d20d003bfcf3941da7d"


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


def linked_library_inventory(library):
    """Record the actual loader dependency closure for one private bridge ELF."""
    library = Path(library).resolve()
    output = subprocess.check_output(["ldd", str(library)], text=True,
                                    env={**os.environ, "LC_ALL": "C",
                                         "LD_LIBRARY_PATH": str(library.parent)})
    if "not found" in output:
        raise RuntimeError("Private native dependency has an unresolved linked library")
    paths = {library}
    for line in output.splitlines():
        match = re.search(r"(?:=>\s+)?(/\S+)\s+\(", line)
        if match:
            paths.add(Path(match.group(1)).resolve())
    if len(paths) < 2:
        raise RuntimeError("Native dependency closure was not observed")
    return {str(path): digest(path) for path in sorted(paths)}


def validate_native_dependency(value, *, verify_files=True):
    library = Path(value["library"]["path"]).resolve()
    if (library.parent.parent != WORK / "atspi-geometry"
            or not library.parent.name.startswith("runtime-patched")
            or library.name != "libatk-bridge-2.0.so.0.0.0"):
        raise RuntimeError("Unexpected private ATK bridge library location")
    if not isinstance(value.get("linked_libraries"), dict) or not value["linked_libraries"]:
        raise RuntimeError("Native dependency closure binding is missing")
    if not verify_files:
        return
    checked_record(value["library"])
    if checked_record(value["patch"]).name != "at-spi2-core-2.52-same-process-geometry.patch" or value["patch"]["sha256"] != ATK_PATCH_SHA256:
        raise RuntimeError("Native dependency patch differs from the reviewed source")
    artifact = json.loads(checked_record(value["build_artifact"]).read_text())
    source = WORK / "atspi-geometry/patched"
    if (artifact.get("source_pin") != ATK_SOURCE_REVISION or artifact.get("variant") != "patched"
            or artifact.get("source") != str(source) or artifact.get("patch_sha256") != ATK_PATCH_SHA256
            or artifact.get("source_diff_sha256") != ATK_PATCH_SHA256
            or artifact.get("library") != str(library)
            or artifact.get("sha256") != value["library"]["sha256"]):
        raise RuntimeError("Private ATK bridge does not match its source/build artifact")
    if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip() != ATK_SOURCE_REVISION:
        raise RuntimeError("Native dependency source revision changed")
    diff = subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=source)
    if hashlib.sha256(diff).hexdigest() != ATK_PATCH_SHA256:
        raise RuntimeError("Native dependency source patch changed")
    selected = library.parent
    if set(path.name for path in selected.iterdir()) != {
            library.name, "libatk-bridge-2.0.so.0", "libatk-bridge-2.0.so"}:
        raise RuntimeError("Private loader directory contains an unbound dependency")
    if any(path.resolve() != library for path in selected.iterdir()):
        raise RuntimeError("Private loader alias does not select the bound bridge")
    if linked_library_inventory(library) != value["linked_libraries"]:
        raise RuntimeError("Native linked dependency closure changed")


def native_dependency_environment(context):
    dependency = context.get("native_atk_bridge") if context else None
    return ({"LD_LIBRARY_PATH": str(Path(dependency["library"]["path"]).resolve().parent)}
            if dependency else {})


def verify_loaded_native_dependencies(pid, context):
    dependency = context.get("native_atk_bridge")
    if dependency is None:
        return None
    mapped = set()
    for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) == 6 and fields[5].startswith("/"):
            mapped.add(Path(fields[5]).resolve())
    expected = dependency["linked_libraries"]
    bridge = Path(dependency["library"]["path"]).resolve()
    bridges = {path for path in mapped if path.name.startswith("libatk-bridge-2.0.so")}
    if bridges != {bridge}:
        raise RuntimeError(f"Process loaded a different ATK bridge: {bridges}")
    for path, expected_hash in expected.items():
        actual = Path(path).resolve()
        if actual not in mapped or digest(actual) != expected_hash:
            raise RuntimeError(f"Process native dependency mapping differs: {actual}")
    return {"pid": pid, "libraries": expected,
            "source": "actual /proc/PID/maps and hashes of all selected bridge dependencies"}


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
    if data.get("native_atk_bridge") is not None:
        validate_native_dependency(data["native_atk_bridge"], verify_files=verify_files)
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
