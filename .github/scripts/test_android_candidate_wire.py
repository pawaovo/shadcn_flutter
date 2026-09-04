"""Real Dart/Python HTTP compatibility; VM/native peers are fixtures, never UI proof."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from types import SimpleNamespace
import unittest

from run_android_candidate_diagnostic import (
    APP, HELPER, ROOT, Runner, start_owned_process, stop_owned_process,
)
from test_android_candidate_diagnostic import Peer, SHA, STAGE_NONCE, state


class FixtureRunner(Runner):
    """Replace only Android process/device access; retain production HTTP routes."""

    def process_identity(self, package):
        return {"package": package, "pid": 42 if package == APP else 43,
                "start_ticks": 100}

    def adb(self, *arguments, **_kwargs):
        self.device_calls.append(arguments)
        if arguments[:3] == ("exec-out", "run-as", HELPER):
            return '{"scope":"native HTTP fixture only","operation":"stop"}\n'
        return ""


class DartPythonWireTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        args = SimpleNamespace(output=self.directory / "fresh", source_sha=SHA,
                               adb="unused-fixture", flutter="unused-fixture", device="emulator-5554")
        self.runner = FixtureRunner(args)
        self.runner.device_calls = []
        self.native_calls = []
        self.vm_state = state(self.runner.nonce)
        vm = Peer(lambda _path, _body: {"result": self.vm_state})
        native = Peer(self.native_response)
        self.addCleanup(vm.close)
        self.addCleanup(native.close)
        self.runner.vm_url = vm.url + "/"
        self.runner.isolate = "isolates/fixture"
        self.runner.app_identity = self.runner.process_identity(APP)
        self.runner.native_url = native.url
        record = {"stage_id": "chat_send", "stage_nonce": STAGE_NONCE,
                  "helper_process": self.runner.process_identity(HELPER),
                  "event_log": f"files/probe-events-chat_send-{STAGE_NONCE}.jsonl"}
        self.runner.current_native = record
        self.runner.native_stages.append(record)
        self.host_url = self.runner.serve()
        self.addCleanup(self.close_server)

    def close_server(self):
        self.runner.server.shutdown()
        self.runner.server.server_close()
        self.runner.server_thread.join(3)

    def native_response(self, route, body):
        self.native_calls.append(route)
        identity = {"nonce": self.runner.nonce, "source_sha": SHA,
                    "stage_id": "chat_send", "stage_nonce": STAGE_NONCE}
        self.assertEqual({key: body.get(key) for key in identity}, identity)
        response = {"ok": True, "protocol_version": 2, "run_nonce": self.runner.nonce,
                    **identity, "expected_text": "Check cone inventory", "candidate_text": "inventory",
                    "composing_base": 11, "composing_extent": 20, "selection_offset": 20}
        if route == "/inspect":
            now = int(time.monotonic() * 1000)
            response.update(candidate_id="fixture-candidate", focused_app_package=APP,
                            ime_package="fixture.ime", ime_component="fixture.ime/.Keyboard",
                            expires_at_device_ms=now + 2000, device_elapsed_ms=now)
            self.vm_state.update(stage="action_claimed", candidate_id="fixture-candidate",
                                 lease_id="fixture-lease", lease_remaining_ms=4500, can_click=True)
        elif route == "/tap":
            self.assertEqual(body["candidate_id"], "fixture-candidate")
            response.update(injected_down=True, injected_up=True, cancelled=False,
                            used_candidate_id="fixture-candidate")
            # This is a declared protocol peer response, not an application action.
            done = {**self.vm_state, "stage": "stage_done", "original_action_passed": True,
                    "native_click_acknowledged": True, "native_drained": True,
                    "send_activation_checked": True}
            self.vm_state.update(stage="stage_done", completed_stage_ids=["chat_send"],
                                 stage_results=[done], original_action_passed=True)
        elif route != "/stop":
            raise AssertionError("Unexpected fixture native operation: " + route)
        return response

    def run_dart(self, mode):
        config = self.directory / "wire.json"
        config.write_text(json.dumps({"host_url": self.host_url, "token": self.runner.token,
                                      "nonce": self.runner.nonce, "source_sha": SHA,
                                      "stage_id": "chat_send", "stage_nonce": STAGE_NONCE,
                                      "candidate_id": "fixture-candidate", "lease_id": "fixture-lease",
                                      "mode": mode}))
        dart = os.environ.get("ANDROID_CANDIDATE_DART") or shutil.which("dart")
        self.assertIsNotNone(dart, "The real Dart runtime is required for the cross-language wire fixture")
        fixture = ROOT / "packages/beautiful_ai_ui_catalog/test_driver/android_candidate_python_wire_fixture.dart"
        process = start_owned_process([dart, "run", str(fixture), str(config)], cwd=ROOT,
                                      stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            stdout, stderr = process.communicate(timeout=60)
        finally:
            stop_owned_process(process, grace=1, kill_timeout=2)
            process.stdout.close()
            process.stderr.close()
        self.assertEqual(process.returncode, 0, (stdout + stderr).decode(errors="replace"))
        return json.loads(stdout.decode().strip().splitlines()[-1])

    def test_production_dart_bodies_complete_real_prepare_inspect_click_finish_routes(self):
        result = self.run_dart("success")
        self.assertEqual(result["status"], "passed")
        self.assertEqual(self.native_calls, ["/inspect", "/tap", "/stop"])
        self.assertEqual(self.runner.current_native["native_tap_attempts"], 1)
        self.assertTrue(self.runner.current_native["cleanup_verified"])
        self.assertEqual(self.runner.http_errors, [])

    def test_old_nested_click_body_is_rejected_before_native_touch(self):
        result = self.run_dart("old_nested")
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["expected_rejection"])
        self.assertEqual(self.native_calls, ["/inspect"])
        self.assertFalse(self.runner.click_attempted)

    def test_wrong_stage_click_body_is_rejected_before_native_touch(self):
        result = self.run_dart("wrong_stage")
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["expected_rejection"])
        self.assertEqual(self.native_calls, ["/inspect"])
        self.assertFalse(self.runner.click_attempted)


if __name__ == "__main__":
    unittest.main()
