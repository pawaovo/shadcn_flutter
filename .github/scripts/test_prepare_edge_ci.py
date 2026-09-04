"""Synthetic setup and post-run evidence boundaries; never starts a browser."""

import hashlib
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

import prepare_edge_ci as setup


class EdgeCiSetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.output = self.root / "startup-condition"
        self.elf = self.root / "browser-elf"
        self.payload = b"\x7fELFsynthetic fixture, never executed"
        self.elf.write_bytes(self.payload)
        self.elf.chmod(0o755)
        self.platform = patch.object(setup.sys, "platform", "linux")
        self.platform.start()
        self.addCleanup(self.platform.stop)

    def prepare(self):
        return setup.preread(self.output, self.elf)

    def fixture(self, name="journey", pid=10):
        directory = self.root / name
        resources = directory / "resources"
        resources.mkdir(parents=True)
        setup.write_json(directory / "browser-identity.json", {"sessionId": name, "capabilities": {
            "browserName": "MicrosoftEdge", "goog:processID": pid,
            "pageLoadStrategy": "normal", "timeouts": {"pageLoad": 300000}}})
        rows = [{"pid": pid, "start_ticks": pid * 10, "exe": str(self.elf)},
                {"pid": pid + 1, "start_ticks": pid * 10 + 1, "exe": "/synthetic/driver"}]
        setup.write_json(resources / "observation.json", {
            "status": "recorded", "root_pid": pid + 1, "root_start_ticks": pid * 10 + 1,
            "observed_process_identities": [[row["pid"], row["start_ticks"]] for row in rows]})
        (resources / "resources.jsonl").write_text(json.dumps({"processes": rows}) + "\n")
        return directory

    def hash(self, path):
        return {"path": path, "resolved": path, "bytes": len(self.payload),
                "sha256": hashlib.sha256(self.payload).hexdigest()}

    def test_preread_once_records_exact_bytes_and_rejects_reuse(self):
        with patch.object(setup, "preread_executable", wraps=setup.preread_executable) as read:
            report = self.prepare()
        read.assert_called_once()
        self.assertEqual(report["status"], "ready")
        self.assertEqual(report["upstream_status"], "not_started")
        self.assertEqual(report["preread"]["bytes_read"], len(self.payload))
        original = (self.output / "setup.json").read_bytes()
        with self.assertRaises(FileExistsError):
            self.prepare()
        self.assertEqual((self.output / "setup.json").read_bytes(), original)

    def test_failed_read_preserves_setup_and_preread_failure(self):
        self.elf.write_text("#!/bin/sh\n")
        report = self.prepare()
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["upstream_status"], "not_started")
        self.assertEqual(setup.read_json(self.output / "preread.json")["status"], "failed")
        verification = setup.verify(self.output, [self.root / "missing"], "skipped")
        self.assertEqual(verification["upstream_status"], "not_started")
        self.assertEqual(verification["status"], "failed")

    def test_setup_deadline_interrupts_one_read_and_records_failure(self):
        with patch.object(setup, "preread_executable", side_effect=lambda *_: time.sleep(1)) as read:
            report = setup.preread(self.output, self.elf, 0.01)
        read.assert_called_once()
        self.assertEqual(report["status"], "failed")
        self.assertIn("TimeoutError", report["error"])
        self.assertEqual(setup.read_json(self.output / "setup.json")["status"], "failed")

    def test_actual_pid_binding_and_original_failure_are_separate(self):
        self.prepare()
        directory = self.fixture()
        with patch.object(setup, "proc_row", side_effect=FileNotFoundError), \
                patch.object(setup, "file_identity", side_effect=self.hash):
            result = setup.verify(self.output, [directory], "failure")
        self.assertEqual(result["status"], "verified")
        self.assertEqual(result["upstream_status"], "failed")
        self.assertEqual(result["cleanup_scope"], "observed_identity_no_live_processes")
        self.assertFalse(result["unobserved_descendant_absence_claimed"])
        self.assertEqual(result["suites"][0]["browser"]["pid"], 10)

    def test_live_identity_or_permission_uncertainty_prevents_hashing(self):
        self.prepare()
        directory = self.fixture()
        for observation in ({"start_ticks": 100, "state": "S"}, PermissionError("denied")):
            with self.subTest(observation=observation), \
                    patch.object(setup, "proc_row", side_effect=observation if isinstance(observation, Exception) else None,
                                 return_value=observation), patch.object(setup, "file_identity") as hashed:
                result = setup.verify(self.output, [directory], "success")
                self.assertEqual(result["status"], "failed")
                self.assertEqual(result["upstream_status"], "passed")
                hashed.assert_not_called()

    def test_reused_pid_and_zombie_do_not_count_as_live_original(self):
        self.prepare()
        directory = self.fixture()
        with patch.object(setup, "proc_row", side_effect=[{"start_ticks": 999, "state": "S"},
                                                        {"start_ticks": 101, "state": "Z"}]), \
                patch.object(setup, "file_identity", side_effect=self.hash):
            result = setup.verify(self.output, [directory], "success")
        self.assertEqual(result["status"], "verified")
        self.assertEqual([row["state"] for row in result["suites"][0]["no_live_observed_identities"]],
                         ["pid_reused", "zombie"])

    def test_other_process_cannot_substitute_for_actual_session_browser(self):
        self.prepare()
        directory = self.fixture()
        identity = setup.read_json(directory / "browser-identity.json")
        identity["capabilities"]["goog:processID"] = 99
        setup.write_json(directory / "browser-identity.json", identity)
        with patch.object(setup, "file_identity") as hashed:
            self.assertEqual(setup.verify(self.output, [directory], "success")["status"], "failed")
            hashed.assert_not_called()

    def test_changed_browser_hash_fails_without_replacing_suite_success(self):
        self.prepare()
        directory = self.fixture()
        with patch.object(setup, "proc_row", side_effect=FileNotFoundError), \
                patch.object(setup, "file_identity", side_effect=lambda path: dict(self.hash(path), sha256="changed")):
            result = setup.verify(self.output, [directory], "success")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["upstream_status"], "passed")
        self.assertIn("post-run hash", result["evidence_error"])

    def test_changed_original_browser_deadline_fails_before_hash(self):
        self.prepare()
        directory = self.fixture()
        identity = setup.read_json(directory / "browser-identity.json")
        identity["capabilities"]["timeouts"]["pageLoad"] = 600000
        setup.write_json(directory / "browser-identity.json", identity)
        with patch.object(setup, "file_identity") as hashed:
            result = setup.verify(self.output, [directory], "success")
            self.assertEqual(result["status"], "failed")
            hashed.assert_not_called()

    def test_input_requires_all_owned_cleanup_before_any_hash(self):
        self.prepare()
        suites = [self.fixture("framework", 10), self.fixture("browser", 20)]
        summary = self.root / "input-acceptance-summary.json"
        upstream = {"platform": "edge", "status": "failed", "suites": [
            {"suite": name, "status": "failed", "error": "original assertion", "cleanup_status": "verified"}
            for name in ("framework", "browser")]}
        setup.write_json(summary, upstream)
        with patch.object(setup, "proc_row", side_effect=FileNotFoundError), \
                patch.object(setup, "file_identity", side_effect=self.hash) as hashed:
            result = setup.verify(self.output, suites, "failure", summary)
        self.assertEqual(result["status"], "verified")
        self.assertEqual(result["upstream"], upstream)
        self.assertEqual(result["cleanup_scope"], "owned_group_cleanup_verified")
        self.assertEqual(hashed.call_count, 2)  # Shared browser and driver each hashed once, after both suites.
        upstream["suites"][1]["cleanup_status"] = "unverified"
        setup.write_json(summary, upstream)
        with patch.object(setup, "file_identity") as hashed:
            self.assertEqual(setup.verify(self.output, suites, "failure", summary)["status"], "failed")
            hashed.assert_not_called()

    def test_missing_resource_evidence_fails_with_original_result_retained(self):
        self.prepare()
        directory = self.fixture()
        (directory / "resources/observation.json").unlink()
        result = setup.verify(self.output, [directory], "failure")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["upstream_status"], "failed")
        self.assertIn("FileNotFoundError", result["evidence_error"])


if __name__ == "__main__":
    unittest.main()
