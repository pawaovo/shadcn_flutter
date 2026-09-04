"""Host protocol/ownership regressions; simulated HTTP peers are not IME proof."""

import copy
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from run_android_candidate_diagnostic import Runner, TEXT, checked_vm_url, validate_stage


SHA = "a" * 40


def state(nonce, *, claimed=False):
    return {"protocol_version": 1, "nonce": nonce, "source_sha": SHA,
            "stage": "action_claimed" if claimed else "awaiting_candidate",
            "candidate_id": "candidate", "lease_id": "lease", "lease_remaining_ms": 4500,
            "can_click": claimed,
            "snapshot": {"input": {"text": TEXT, "selectionBase": 20, "selectionExtent": 20,
                                    "composingBase": 11, "composingExtent": 20},
                         "editor_primary_focus": True, "send_count": 1,
                         "send_enabled_semantics": "isFalse", "view_insets_bottom_physical": 901}}


class Peer:
    def __init__(self, handler):
        class Request(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                self.answer(None)
            def do_POST(self):
                self.answer(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
            def answer(self, body):
                value = handler(self.path, body)
                raw = json.dumps(value).encode()
                try:
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(raw)))
                    self.end_headers()
                    self.wfile.write(raw)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # The timeout test deliberately closes an in-flight request.
        self.server = HTTPServer(("127.0.0.1", 0), Request)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(2)


class HostProtocolTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        args = SimpleNamespace(output=Path(temp.name) / "fresh", source_sha=SHA,
                               adb="adb", flutter="flutter", device="emulator-5554")
        self.runner = Runner(args)

    def prepare_click(self, vm_state=None, native_delay=0):
        runner = self.runner
        self.vm_state = vm_state or state(runner.nonce, claimed=True)
        self.native_calls = []
        vm = Peer(lambda path, body: {"result": self.vm_state})
        def native(path, body):
            self.native_calls.append(path)
            if path == "/tap":
                time.sleep(native_delay)
            return {"ok": True, "source_sha": SHA, "protocol_version": 1,
                    "injected_down": True, "injected_up": True, "cancelled": False,
                    "used_candidate_id": "candidate"}
        helper = Peer(native)
        self.addCleanup(vm.close)
        self.addCleanup(helper.close)
        runner.vm_url = vm.url + "/"
        runner.isolate = "isolates/42"
        runner.native_url = helper.url
        runner.inspection = {"candidate_id": "candidate"}
        runner.inspected_at = time.monotonic()
        return {"nonce": runner.nonce, "source_sha": SHA,
                "candidate": {"candidate_id": "candidate"}, "claim": {"lease_id": "lease"}}

    def test_exact_live_vm_state_is_rechecked_before_one_native_request(self):
        body = self.prepare_click()
        reply = self.runner.click_native(body)
        self.assertTrue(reply["clicked"])
        self.assertTrue(reply["native_drained"])
        self.assertEqual(self.native_calls, ["/tap"])
        with self.assertRaisesRegex(RuntimeError, "never retried"):
            self.runner.click_native(body)
        self.assertEqual(self.native_calls, ["/tap"])

    def test_changed_value_after_claim_prevents_any_native_request(self):
        body = self.prepare_click()
        self.vm_state["snapshot"]["input"]["composingBase"] = -1
        with self.assertRaisesRegex(ValueError, "state changed"):
            self.runner.click_native(body)
        self.assertEqual(self.native_calls, [])

    def test_expired_terminal_or_wrong_lease_prevents_any_native_request(self):
        body = self.prepare_click()
        original = copy.deepcopy(self.vm_state)
        for update in ({"lease_remaining_ms": 1499}, {"stage": "failed"}, {"lease_id": "other"}):
            self.vm_state.clear()
            self.vm_state.update(copy.deepcopy(original))
            self.vm_state.update(update)
            with self.assertRaises(ValueError):
                self.runner.click_native(body)
        self.assertEqual(self.native_calls, [])

    def test_inspection_timeout_is_not_a_second_action_opportunity(self):
        body = self.prepare_click()
        self.runner.inspected_at -= 2
        with self.assertRaisesRegex(RuntimeError, "stale"):
            self.runner.click_native(body)
        self.assertEqual(self.native_calls, [])

    def test_real_serial_stop_response_is_required_to_acknowledge_drain(self):
        self.prepare_click(native_delay=.15)
        with self.assertRaises(TimeoutError):
            self.runner.native("/tap", {"candidate_id": "candidate"}, timeout=.025)
        started = time.monotonic()
        reply = self.runner.abort({"nonce": self.runner.nonce, "source_sha": SHA, "error": "timeout"})
        self.assertGreater(time.monotonic() - started, .08)
        self.assertTrue(reply["native_drained"])
        self.assertFalse(self.runner.active)
        self.assertEqual(self.native_calls, ["/tap", "/stop"])

    def test_failed_stop_never_manufactures_native_drain(self):
        self.prepare_click()
        with patch.object(self.runner, "native", side_effect=TimeoutError("still in native API")):
            reply = self.runner.abort({"nonce": self.runner.nonce, "source_sha": SHA})
        self.assertFalse(reply["native_drained"])
        self.assertIn("unverified", reply["drain_scope"])
        self.assertTrue(self.runner.report["cleanup_errors"])

    def test_real_process_timeout_reaps_owned_group_and_preserves_failure(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.runner.command([sys.executable, "-c", "import time; time.sleep(30)"],
                                "blocked-command", timeout=.025)
        self.assertTrue(self.runner.children[-1]._input_cleanup_complete)
        self.assertIsNotNone(self.runner.children[-1].poll())
        self.assertEqual(self.runner.report["cleanup_errors"], [])

    def test_fresh_evidence_path_is_required(self):
        with self.assertRaises(FileExistsError):
            Runner(self.runner.args)


class ValidationTests(unittest.TestCase):
    def test_vm_endpoint_must_be_uncredentialed_observed_loopback(self):
        self.assertEqual(checked_vm_url("ws://127.0.0.1:1234/token/ws"),
                         "http://127.0.0.1:1234/token/")
        for value in ("https://example.com:1234/", "http://user@127.0.0.1:1234/",
                      "http://127.0.0.1:1234/?other=target", "http://127.0.0.1:80/"):
            with self.assertRaises(ValueError):
                checked_vm_url(value)

    def test_whitespace_focus_and_keyboard_changes_are_not_tolerated(self):
        for field, value in (("text", TEXT + " "), ("selectionExtent", 19), ("composingExtent", 19)):
            data = state("b" * 32)
            data["snapshot"]["input"][field] = value
            with self.assertRaises(ValueError):
                validate_stage(data, "b" * 32, SHA)
        for field, value in (("editor_primary_focus", False), ("view_insets_bottom_physical", 0),
                             ("send_enabled_semantics", "isTrue")):
            data = state("b" * 32)
            data["snapshot"][field] = value
            with self.assertRaises(ValueError):
                validate_stage(data, "b" * 32, SHA)


if __name__ == "__main__":
    unittest.main()
