"""Manifest/authority protocol tests only: no engine, GUI, reader or acceptance run."""

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import isolated_sdk_runtime as runtime


class IsolatedSDKManifestTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.work = Path(directory.name).resolve()
        self.root = self.work / "catalog"
        self.sdk = self.work / "flutter"
        self.root.mkdir()
        self.sources = {".github/scripts/probe_catalog_orca_linux.py": "fixture-source-hash"}
        self.patch_file = self.work / "proof/flutter-3.47.0-atk-name-expanded.patch"
        self.node = self.sdk / "engine/src/flutter/shell/platform/linux/fl_accessible_node.cc"
        self.library = self.sdk / "engine/src/out" / runtime.ENGINE_NAME / "libflutter_linux_gtk.so"
        for path, content in ((self.patch_file, b"unit-only patch"),
                              (self.node, b"unit-only source"),
                              (self.library, b"unit-only library, never executed")):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        self.identity = self.work / "container-identity.json"
        self.write(self.identity, {"id": "a" * 64, "name": "beautiful-flutter-gtk-build-fixture",
            "platform": "linux", "architecture": "arm64",
            "labels": {"beautiful.owner": "linux-sdk-runtime-build"},
            "cpus": 4, "memory_bytes": 8 * 1024 ** 3,
            "mounts": {"/work": True, "/plan": False, "/proof": False}})
        self.write(self.work / "owner.json", {"purpose": "beautiful-linux-sdk-runtime-build",
            "sdk_revision": runtime.SDK_REVISION})
        binding = self.work / "source-build-binding.json"
        self.write(binding, {"sdk_revision": runtime.SDK_REVISION,
            "patch_sha256": runtime.digest(self.patch_file), "patched_node_sha256": runtime.digest(self.node),
            "mode": "debug-unoptimized"})
        artifact = self.work / "engine-artifact.json"
        self.write(artifact, {"status": "built_not_runtime_accepted", "sdk_revision": runtime.SDK_REVISION,
            "source_build_binding_sha256": runtime.digest(binding), "library": str(self.library),
            "library_sha256": runtime.digest(self.library)})
        self.data = {"scope": "isolated_sdk_runtime_diagnostic", "build_mode": "debug",
            "sdk_revision": runtime.SDK_REVISION, "sdk_root": str(self.sdk),
            "catalog_root": str(self.root), "catalog_git_head": "b" * 40,
            "fixture_source_sha256": self.sources, "container_identity": runtime.record(self.identity),
            "patch": runtime.record(self.patch_file), "source_build_binding": runtime.record(binding),
            "engine_artifact": runtime.record(artifact), "engine_library": runtime.record(self.library)}
        self.data["expected_build_command"] = runtime.build_command(self.data)
        self.manifest = self.work / "manifest.json"
        self.write(self.manifest, self.data)
        original_is_file = Path.is_file
        contexts = [patch.object(runtime, "WORK", self.work),
            patch.object(runtime, "PATCH_SHA256", runtime.digest(self.patch_file)),
            patch.object(runtime, "NODE_SHA256", runtime.digest(self.node)),
            patch.object(runtime.sys, "platform", "linux"),
            patch.object(runtime.platform, "machine", return_value="aarch64"),
            patch.object(runtime.socket, "gethostname", return_value="a" * 12),
            patch.object(Path, "is_file", lambda p: True if str(p) == "/.dockerenv" else original_is_file(p)),
            patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}),
            patch.object(runtime.subprocess, "check_output", side_effect=self.git_revision)]
        for context in contexts:
            context.start()
            self.addCleanup(context.stop)

    def write(self, path, data):
        path.write_text(json.dumps(data))

    def git_revision(self, command, *, cwd, text):
        self.assertEqual(command, ["git", "rev-parse", "HEAD"])
        self.assertTrue(text)
        self.assertIn(Path(cwd), (self.sdk, self.root))
        return (runtime.SDK_REVISION if Path(cwd) == self.sdk else "b" * 40) + "\n"

    def validate(self):
        return runtime.validate_manifest(self.manifest, self.root, current_sources=self.sources)

    def test_consistent_owned_manifest_validates_without_accepting_an_application(self):
        self.assertEqual(self.validate()["scope"], "isolated_sdk_runtime_diagnostic")
        self.assertIn("--debug", runtime.build_command(self.data))
        self.assertNotIn("--release", runtime.build_command(self.data))

    def test_local_mode_cannot_impersonate_github_actions(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
            with self.assertRaisesRegex(RuntimeError, "impersonate"):
                self.validate()

    def test_wrong_actual_container_identity_is_rejected(self):
        with patch.object(runtime.socket, "gethostname", return_value="another-container"):
            with self.assertRaisesRegex(RuntimeError, "owned container"):
                self.validate()

    def test_unexpected_host_mount_is_rejected_even_with_matching_manifest_hash(self):
        identity = json.loads(self.identity.read_text())
        identity["mounts"]["/var/run/docker.sock"] = True
        self.write(self.identity, identity)
        self.data["container_identity"] = runtime.record(self.identity)
        self.write(self.manifest, self.data)
        with self.assertRaisesRegex(RuntimeError, "host mounts"):
            self.validate()

    def test_changed_engine_bytes_are_rejected(self):
        self.library.write_bytes(b"different engine")
        with self.assertRaisesRegex(RuntimeError, "hash differs"):
            self.validate()

    def test_changed_fixture_or_changed_build_command_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "Fixture sources"):
            runtime.validate_manifest(self.manifest, self.root, current_sources={"other": "input"})
        self.data["expected_build_command"].remove("--debug")
        self.write(self.manifest, self.data)
        with self.assertRaisesRegex(RuntimeError, "local debug engine"):
            self.validate()

    def test_readonly_inspection_checks_authority_without_rehashing_large_engine(self):
        # The parent requires full checks before launch and after tasks. A child
        # only reads AT-SPI; repeated binary hashing must not consume its 8s bound.
        self.library.unlink()
        self.assertEqual(runtime.validate_manifest(self.manifest, self.root, verify_files=False)["scope"],
                         "isolated_sdk_runtime_diagnostic")
        with patch.object(runtime.socket, "gethostname", return_value="another-container"):
            with self.assertRaisesRegex(RuntimeError, "owned container"):
                runtime.validate_manifest(self.manifest, self.root, verify_files=False)


if __name__ == "__main__":
    unittest.main()
