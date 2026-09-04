"""Real adapter/HTTP protocol checks, with an explicitly synthetic upstream."""

import io
import hashlib
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

from flutter_edge_webdriver import EdgeAdapter
from probe_edge_cold_start import (Client, SESSION_REQUEST, WebDriverFailure,
                                  log_signals, preread_executable, run_cases, startup)


class SyntheticDriver(BaseHTTPRequestHandler):
    def handle_request(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        body = json.loads(raw) if raw else None
        self.server.commands.append((self.command, self.path, body))
        status = 200
        if self.path == "/status":
            value = {"ready": True}
        elif self.path == "/session":
            value = {"sessionId": "synthetic-session", "capabilities": {
                "browserName": "MicrosoftEdge", "browserVersion": "151.0.4129.101",
                "msedge": {"msedgedriverVersion": "151.0.4129.101 (synthetic)"},
                "pageLoadStrategy": "normal", "timeouts": {"pageLoad": self.server.page_load},
            }}
        elif self.path.endswith("/window"):
            value = "synthetic-window"
        elif body == {"x": 0, "y": 0} and self.server.fail_location:
            status = self.server.failure_status
            value = {"error": "timeout", "message": "Timed out receiving message from renderer: 300.000",
                     "stacktrace": "synthetic negative control"}
        else:
            value = {"x": 0, "y": 0, "width": 1440, "height": 900}
        encoded = json.dumps({"value": value}).encode()
        self.send_response(status)
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    do_GET = do_POST = handle_request

    def log_message(self, *_):
        pass


class EdgeColdStartTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.upstream = ThreadingHTTPServer(("127.0.0.1", 0), SyntheticDriver)
        self.upstream.commands = []
        self.upstream.fail_location = False
        self.upstream.failure_status = 500
        self.upstream.page_load = 300000
        self.start_server(self.upstream)
        self.adapter = EdgeAdapter(0, self.upstream.server_port, "/usr/bin/microsoft-edge",
                                   "151.0.4129.101", Path(self.directory.name) / "identity.json")
        self.start_server(self.adapter)
        self.trace = io.StringIO()
        self.client = Client(self.adapter.server_port, self.trace)

    def start_server(self, server):
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01})
        thread.start()
        def stop():
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
            self.assertFalse(thread.is_alive())
        self.addCleanup(stop)

    def test_exact_startup_order_and_adapter_capabilities(self):
        report = {}
        startup(self.client, report)
        requests = [json.loads(line) for line in self.trace.getvalue().splitlines()]
        base = "/session/synthetic-session"
        self.assertEqual([(r["method"], r["path"], r["body"]) for r in requests], [
            ("GET", "/status", None), ("POST", "/session", SESSION_REQUEST),
            ("GET", base + "/window", None),
            ("POST", base + "/window/rect", {"x": 0, "y": 0}),
            ("POST", base + "/window/rect", {"width": 1440, "height": 900}),
        ])
        caps = self.upstream.commands[1][2]
        self.assertEqual(caps["desiredCapabilities"], caps["capabilities"]["alwaysMatch"])
        self.assertEqual(caps["desiredCapabilities"], {
            "acceptInsecureCerts": True, "browserName": "MicrosoftEdge",
            "ms:edgeOptions": {"binary": "/usr/bin/microsoft-edge", "args": [
                "--headless=new", "--no-sandbox", "--no-first-run", "--no-default-browser-check",
                "--force-device-scale-factor=1", "--disable-background-timer-throttling"]},
        })
        self.assertEqual(report["phase"], "startup_complete")
        self.assertTrue(all(r["transport_seconds"] == 900 for r in requests))

    def test_original_location_failure_stops_before_size_and_keeps_response(self):
        self.upstream.fail_location = True
        report = {}
        with self.assertRaises(WebDriverFailure) as failure:
            startup(self.client, report)
        record = failure.exception.record
        self.assertEqual(record["status"], 500)
        self.assertEqual(record["response"]["value"]["message"],
                         "Timed out receiving message from renderer: 300.000")
        self.assertEqual(report["phase"], "set_location")
        self.assertEqual(len(self.upstream.commands), 4)
        self.assertEqual(json.loads(self.trace.getvalue().splitlines()[-1])["response_text"],
                         record["response_text"])

    def test_error_payload_cannot_pass_even_under_http_200(self):
        self.upstream.fail_location = True
        self.upstream.failure_status = 200
        with self.assertRaises(WebDriverFailure):
            startup(self.client, {})

    def test_changed_page_load_deadline_cannot_pass(self):
        self.upstream.page_load = 600000
        with self.assertRaisesRegex(AssertionError, "300000"):
            startup(self.client, {})
        self.assertEqual(len(self.upstream.commands), 2)

    def test_fixed_three_cases_keep_first_failure_when_later_cases_pass(self):
        calls = []
        def execute(index, *_):
            calls.append(index)
            return {"index": index, "status": "failed" if index == 1 else "passed",
                    "cleanup_status": "verified", "original_failure": "sentinel" if index == 1 else None}
        report = run_cases(Path(self.directory.name), "/edge", "/driver", execute)
        self.assertEqual(calls, [1, 2, 3])
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["sessions"][0]["original_failure"], "sentinel")
        self.assertEqual(json.loads((Path(self.directory.name) / "summary.json").read_text()), report)

    def test_unverified_cleanup_stops_remaining_cases_without_passing_them(self):
        calls = []
        def execute(index, *_):
            calls.append(index)
            return {"index": index, "status": "failed", "cleanup_status": "unverified"}
        report = run_cases(Path(self.directory.name), "/edge", "/driver", execute)
        self.assertEqual(calls, [1])
        self.assertEqual(report["status"], "failed")
        self.assertEqual([case["status"] for case in report["sessions"]], ["failed", "not_run", "not_run"])

    def test_log_summary_distinguishes_pending_wait_from_window_operation(self):
        path = Path(self.directory.name) / "driver.log"
        path.write_text("\n".join([
            "Terminating current process after 15 seconds with no connection.",
            "Network service crashed or was terminated, restarting service.",
            "COMMAND SetWindowRect", "Waiting for pending navigations...",
            "DevTools WebSocket Command: Runtime.evaluate",
            "DevTools WebSocket Response: Runtime.evaluate",
            "RESPONSE SetWindowRect ERROR timeout",
            # Later observations must not be misreported as the original command.
            "Browser.setWindowBounds", "Page.loadEventFired",
        ]))
        signals = log_signals(path)
        self.assertEqual(len(signals["startup_child_errors"]), 2)
        self.assertEqual(signals["pre_rectangle_load_events"], [])
        counts = signals["initial_rectangle_cdp_counts"]
        self.assertEqual(counts["DevTools WebSocket Response: Runtime.evaluate"], 1)
        self.assertEqual(counts["Browser.setWindowBounds"], 0)


class EdgePrereadTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name).resolve()
        self.executable = self.output / "synthetic-browser-elf"
        self.payload = b"\x7fELF" + b"synthetic fixture, never executed\n" * 40000
        self.executable.write_bytes(self.payload)
        self.executable.chmod(0o755)

    def make_case(self, index, *_):
        directory = self.output / f"session-{index}"
        directory.mkdir()
        (directory / "post-startup-processes.json").write_text(json.dumps({"processes": [
            {"pid": index + 100, "exe": str(self.executable), "start_ticks": index},
        ]}))
        return {"index": index, "status": "passed", "cleanup_status": "verified",
                "session": {"capabilities": {"goog:processID": index + 100}}}

    def test_preread_is_one_sequential_pass_before_all_three_sessions(self):
        opened = []
        bytes_read = []
        real_open = Path.open
        class CountedReader:
            def __init__(self, source):
                self.source = source
            def __enter__(self):
                return self
            def __exit__(self, *_):
                self.source.close()
            def fileno(self):
                return self.source.fileno()
            def read(self, count):
                data = self.source.read(count)
                bytes_read.append(len(data))
                return data
        def open_path(path, *args, **kwargs):
            source = real_open(path, *args, **kwargs)
            if path == self.executable:
                opened.append(str(path))
                return CountedReader(source)
            return source
        calls = []
        def execute(index, *args):
            calls.append(index)
            self.assertEqual(sum(bytes_read), len(self.payload))
            preread = json.loads((self.output / "preread.json").read_text())
            self.assertLessEqual(preread["completed_epoch"], time.time())
            return self.make_case(index, *args)
        with patch.object(Path, "open", open_path):
            report = run_cases(self.output, "/edge", "/driver", execute,
                               preread_path=self.executable)
        self.assertEqual(calls, [1, 2, 3])
        self.assertEqual(opened, [str(self.executable)])
        self.assertEqual(sum(bytes_read), len(self.payload))
        self.assertEqual(report["preread"]["sha256"], hashlib.sha256(self.payload).hexdigest())
        self.assertEqual(report["status"], "passed")
        self.assertTrue(all(r["preread_identity"]["status"] == "verified" for r in report["sessions"]))

    def test_shell_launcher_is_not_accepted_as_actual_browser(self):
        self.executable.write_text("#!/bin/sh\nexec /actual/edge\n")
        with self.assertRaisesRegex(ValueError, "ELF browser"):
            preread_executable(self.executable, self.output)
        self.assertEqual(json.loads((self.output / "preread.json").read_text())["status"], "failed")

    def test_other_process_matching_preread_cannot_substitute_for_browser_pid(self):
        def execute(index, *args):
            report = self.make_case(index, *args)
            report["session"]["capabilities"]["goog:processID"] = 999
            return report
        report = run_cases(self.output, "/edge", "/driver", execute,
                           preread_path=self.executable)
        self.assertEqual(report["status"], "failed")
        self.assertTrue(all("preread_identity_error" in r for r in report["sessions"]))

    def test_baseline_does_not_preread(self):
        with patch("probe_edge_cold_start.preread_executable", side_effect=AssertionError("must not preread")):
            report = run_cases(self.output, "/edge", "/driver", self.make_case)
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["startup_condition"], "baseline_no_preread")
        self.assertFalse((self.output / "preread.json").exists())


if __name__ == "__main__":
    unittest.main()
