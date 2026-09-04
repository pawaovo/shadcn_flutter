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

from run_android_candidate_diagnostic import Runner, TEXT, STAGES, STAGE_SPECS, checked_vm_url, validate_stage, start_owned_process


SHA = "a" * 40


STAGE_NONCE = "c" * 32


def state(nonce, *, claimed=False, stage_id="chat_send", stage_nonce=STAGE_NONCE):
    text, _candidate, start, end, selection = STAGE_SPECS[stage_id]
    return {"protocol_version": 2, "nonce": nonce, "run_nonce": nonce, "source_sha": SHA,
            "stage_id": stage_id, "stage_nonce": stage_nonce, "journey_status": "running",
            "completed_stage_ids": [], "stage_results": [],
            "stage": "action_claimed" if claimed else "awaiting_candidate",
            "candidate_id": "candidate", "lease_id": "lease", "lease_remaining_ms": 4500,
            "can_click": claimed,
            "snapshot": {"input": {"text": text, "selectionBase": selection, "selectionExtent": selection,
                                    "composingBase": start, "composingExtent": end},
                         "editor_primary_focus": True, "send_count": 1,
                         "send_enabled_semantics": "isFalse", "view_insets_bottom_physical": 901,
                         "selected_model_id": "precise", "inventory_attachment_count": 1}}


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
            return {"ok": True, "source_sha": SHA, "protocol_version": 2,
                    "nonce": runner.nonce, "run_nonce": runner.nonce,
                    "stage_id": "chat_send", "stage_nonce": STAGE_NONCE,
                    "injected_down": True, "injected_up": True, "cancelled": False,
                    "used_candidate_id": "candidate"}
        helper = Peer(native)
        self.addCleanup(vm.close)
        self.addCleanup(helper.close)
        runner.vm_url = vm.url + "/"
        runner.isolate = "isolates/42"
        runner.current_native = {"stage_id": "chat_send", "stage_nonce": STAGE_NONCE,
                                 "prepared_by_driver": True}
        runner.native_stages.append(runner.current_native)
        runner.native_url = helper.url
        runner.inspection = {"candidate_id": "candidate"}
        runner.inspected_at = time.monotonic()
        return {"nonce": runner.nonce, "source_sha": SHA,
                "stage_id": "chat_send", "stage_nonce": STAGE_NONCE,
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
        reply = self.runner.abort({"nonce": self.runner.nonce, "source_sha": SHA, "stage_id": "chat_send",
                                   "stage_nonce": STAGE_NONCE, "error": "timeout"})
        self.assertGreater(time.monotonic() - started, .08)
        self.assertTrue(reply["native_drained"])
        self.assertFalse(self.runner.active)
        self.assertEqual(self.native_calls, ["/tap", "/stop"])

    def test_failed_stop_never_manufactures_native_drain(self):
        self.prepare_click()
        with patch.object(self.runner, "native", side_effect=TimeoutError("still in native API")):
            reply = self.runner.abort({"nonce": self.runner.nonce, "source_sha": SHA,
                                           "stage_id": "chat_send", "stage_nonce": STAGE_NONCE})
        self.assertFalse(reply["native_drained"])
        self.assertIn("unverified", reply["drain_scope"])
        self.assertTrue(self.runner.report["cleanup_errors"])

    def test_late_stage_nonce_cannot_tap_or_abort_current_instance(self):
        body = self.prepare_click()
        old = {**body, "stage_nonce": "d" * 32}
        with self.assertRaisesRegex(RuntimeError, "old or different"):
            self.runner.click_native(old)
        with self.assertRaisesRegex(RuntimeError, "owned native stage"):
            self.runner.abort(old)
        self.assertEqual(self.native_calls, [])
        self.assertTrue(self.runner.active)

    def test_old_retired_abort_does_not_stop_a_new_helper(self):
        self.prepare_click()
        old_body = {"nonce": self.runner.nonce, "source_sha": SHA,
                    "stage_id": "chat_send", "stage_nonce": STAGE_NONCE}
        self.runner.current_native["cleanup_verified"] = True
        current = {"stage_id": "prompt_command", "stage_nonce": "d" * 32}
        self.runner.native_stages.append(current)
        self.runner.current_native = current
        result = self.runner.abort(old_body)
        self.assertTrue(result["native_drained"])
        self.assertEqual(result["stage_id"], "chat_send")
        self.assertTrue(self.runner.active)
        self.assertIs(self.runner.current_native, current)
        self.assertEqual(self.native_calls, [])

    def test_original_action_must_pass_before_helper_retirement(self):
        self.prepare_click()
        with self.assertRaisesRegex(RuntimeError, "Original action must pass"):
            self.runner.finish_native({"nonce": self.runner.nonce, "source_sha": SHA,
                                       "stage_id": "chat_send", "stage_nonce": STAGE_NONCE})
        self.assertEqual(self.native_calls, [])

    def test_next_prepare_requires_complete_original_ledger_and_old_cleanup(self):
        self.prepare_click()
        next_nonce = "d" * 32
        self.vm_state.clear()
        self.vm_state.update(state(self.runner.nonce, stage_id="prompt_command", stage_nonce=next_nonce))
        body = {"nonce": self.runner.nonce, "source_sha": SHA,
                "stage_id": "prompt_command", "stage_nonce": next_nonce}
        self.runner.app_identity = {"pid": 99}
        with patch.object(self.runner, "process_identity", return_value={"pid": 99}), \
                patch.object(self.runner, "start_native_helper") as spawn:
            with self.assertRaisesRegex(RuntimeError, "fixed order"):
                self.runner.prepare_native(body)
            self.vm_state["completed_stage_ids"] = ["chat_send"]
            self.vm_state["stage_results"] = [{"protocol_version": 2, "nonce": self.runner.nonce,
                                               "run_nonce": self.runner.nonce, "source_sha": SHA,
                                               "stage_id": "chat_send", "stage_nonce": STAGE_NONCE,
                                               "stage": "stage_done", "original_action_passed": True,
                                               "native_click_acknowledged": True, "native_drained": True,
                                               "send_activation_checked": True}]
            with self.assertRaisesRegex(RuntimeError, "completely cleaned"):
                self.runner.prepare_native(body)
            spawn.assert_not_called()
        self.assertEqual(self.native_calls, [])

    def test_initial_prepared_helper_is_verified_without_starting_again(self):
        self.prepare_click()
        self.runner.current_native.pop("prepared_by_driver")
        self.runner.current_native["helper_process"] = {"pid": 23}
        self.runner.app_identity = {"pid": 24}
        self.vm_state.clear()
        self.vm_state.update(state(self.runner.nonce))
        body = {"nonce": self.runner.nonce, "source_sha": SHA,
                "stage_id": "chat_send", "stage_nonce": STAGE_NONCE}
        with patch.object(self.runner, "process_identity", side_effect=[{"pid": 24}, {"pid": 23}]), \
                patch.object(self.runner, "start_native_helper") as start:
            self.assertTrue(self.runner.prepare_native(body)["prepared"])
            start.assert_not_called()
        self.assertEqual(self.native_calls, [])

    def test_real_child_reader_and_stage_log_are_retired_before_next_instance(self):
        self.prepare_click()
        self.runner.current_native["event_log"] = f"files/probe-events-chat_send-{STAGE_NONCE}.jsonl"
        child = start_owned_process(
            [sys.executable, "-u", "-c", "import time; print('helper-ready'); time.sleep(30)"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        captured = []
        self.runner.helper_reader = threading.Thread(
            target=lambda: captured.extend(iter(child.stdout.readline, b"")), daemon=True)
        self.runner.helper_reader.start()
        self.runner.children.append(child)
        self.runner.native_child = child
        self.runner.forward = "tcp:23456"
        operations = []
        def adb(*arguments, **kwargs):
            operations.append(arguments)
            if arguments[:3] == ("shell", "pidof", "dev.beautifulai.androidcandidateprobe"):
                return ""
            if arguments[:3] == ("exec-out", "run-as", "dev.beautifulai.androidcandidateprobe"):
                return '{"operation":"stop"}\n'
            return ""
        with patch.object(self.runner, "adb", side_effect=adb):
            self.runner.retire_native()
        self.assertEqual(self.native_calls, ["/stop"])
        self.assertIsNotNone(child.poll())
        self.assertTrue(child._input_cleanup_complete)
        self.assertFalse(self.runner.helper_reader.is_alive())
        self.assertTrue(child.stdout.closed)
        self.assertTrue(self.runner.current_native["cleanup_verified"])
        self.assertIsNone(self.runner.forward)
        self.assertIsNone(self.runner.native_url)
        saved = self.runner.stage_file("native-helper-events.jsonl").read_text()
        self.assertEqual(saved, '{"operation":"stop"}\n')
        self.assertIn(("forward", "--remove", "tcp:23456"), operations)
        self.assertIn(("forward", "--list"), operations)
        for handle in self.runner.handles:
            handle.close()

    def test_failed_retirement_cannot_authorize_a_new_instance(self):
        self.prepare_click()
        self.runner.current_native["event_log"] = f"files/probe-events-chat_send-{STAGE_NONCE}.jsonl"
        with patch.object(self.runner, "adb", return_value="still-alive"):
            with self.assertRaisesRegex(RuntimeError, "remains alive"):
                self.runner.retire_native()
        self.assertIsNot(self.runner.current_native.get("cleanup_verified"), True)
        self.assertTrue(self.runner.current_native["cleanup_errors"])

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

    def test_all_three_fixed_specs_and_cross_stage_replays(self):
        for stage_id in STAGES:
            value = state("b" * 32, stage_id=stage_id)
            validate_stage(value, "b" * 32, SHA, stage_id=stage_id, stage_nonce=STAGE_NONCE)
            for update in ({"stage_id": "unknown"}, {"stage_nonce": "e" * 32},
                           {"run_nonce": "f" * 32}, {"journey_status": "passed"}):
                with self.assertRaises(ValueError):
                    validate_stage({**value, **update}, "b" * 32, SHA,
                                   stage_id=stage_id, stage_nonce=STAGE_NONCE)
            value["snapshot"]["input"]["text"] += " "
            with self.assertRaises(ValueError):
                validate_stage(value, "b" * 32, SHA, stage_id=stage_id, stage_nonce=STAGE_NONCE)

    def test_prompt_send_preserves_original_model_and_attachment(self):
        for key, value in (("selected_model_id", "fast"), ("inventory_attachment_count", 0)):
            data = state("b" * 32, stage_id="prompt_send")
            data["snapshot"][key] = value
            with self.assertRaisesRegex(ValueError, "model or attachment"):
                validate_stage(data, "b" * 32, SHA, stage_id="prompt_send", stage_nonce=STAGE_NONCE)

    def test_whitespace_focus_and_keyboard_changes_are_not_tolerated(self):
        for field, value in (("text", TEXT + " "), ("selectionExtent", 19), ("composingExtent", 19)):
            data = state("b" * 32)
            data["snapshot"]["input"][field] = value
            with self.assertRaises(ValueError):
                validate_stage(data, "b" * 32, SHA, stage_id="chat_send", stage_nonce=STAGE_NONCE)
        for field, value in (("editor_primary_focus", False), ("view_insets_bottom_physical", 0),
                             ("send_enabled_semantics", "isTrue")):
            data = state("b" * 32)
            data["snapshot"][field] = value
            with self.assertRaises(ValueError):
                validate_stage(data, "b" * 32, SHA, stage_id="chat_send", stage_nonce=STAGE_NONCE)


if __name__ == "__main__":
    unittest.main()
