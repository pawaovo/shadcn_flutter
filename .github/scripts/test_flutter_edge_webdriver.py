"""Protocol regressions for the pinned Flutter Edge session adapter; no browser."""

import http.client
import base64
import json
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

from flutter_edge_webdriver import EdgeAdapter, installed_versions, normalize_session


LEGACY = {"acceptInsecureCerts": True, "browserName": "edge"}
FLUTTER_REQUEST = json.dumps({
    "desiredCapabilities": LEGACY, "capabilities": {"alwaysMatch": LEGACY},
}).encode()
REAL_RESPONSE = json.dumps({"value": {
    "sessionId": "actual-session", "capabilities": {
        "browserName": "MicrosoftEdge", "browserVersion": "151.0.4129.101",
        "msedge": {"msedgedriverVersion": "151.0.4129.99 (driver-build)"},
    },
}}).encode()


class StubDriver(BaseHTTPRequestHandler):
    def handle_request(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.server.requests.append((self.command, self.path, body))
        if self.path in self.server.slow_modes:
            self.slow_response(self.server.slow_modes[self.path])
            return
        status, response_body = self.server.responses.get(
            (self.command, self.path), (self.server.status, self.server.body),
        )
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response_body)))
        self.end_headers()
        self.wfile.write(response_body)

    def slow_response(self, mode):
        try:
            if mode == "headers":
                self.wfile.write(b"HTTP/1.1 200 OK\r\nX-Slow: ")
                piece = b"a"
            else:
                self.wfile.write(
                    b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n",
                )
                piece = b"1\r\n \r\n"
            # Continuously deliver bytes, so an idle socket timeout never fires.
            # The cap also bounds the fixture if the implementation regresses.
            for _ in range(120):
                self.wfile.write(piece)
                self.wfile.flush()
                time.sleep(0.05)
        except (BrokenPipeError, ConnectionResetError):
            self.server.closed_connections[self.path].set()

    do_GET = do_POST = do_DELETE = handle_request

    def log_message(self, *_):
        pass


class EdgeProtocolTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.evidence = Path(self.directory.name, "identity.json")
        self.upstream = ThreadingHTTPServer(("127.0.0.1", 0), StubDriver)
        self.upstream.status = 200
        self.upstream.body = REAL_RESPONSE
        self.upstream.requests = []
        self.upstream.responses = {}
        self.upstream.slow_modes = {}
        self.upstream.closed_connections = {}
        self.start(self.upstream)
        self.adapter = EdgeAdapter(
            0, self.upstream.server_port, "/usr/bin/microsoft-edge",
            "151.0.4129.101", self.evidence,
        )
        self.start(self.adapter)

    def start(self, server):
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)

    def request(self, method, path, body=b"", timeout=3):
        connection = http.client.HTTPConnection("127.0.0.1", self.adapter.server_port, timeout=timeout)
        try:
            connection.request(method, path, body=body, headers={"Content-Type": "application/json"})
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()

    def test_flutter_session_uses_real_edge_and_preserves_real_response(self):
        status, response = self.request("POST", "/session", FLUTTER_REQUEST)
        self.assertEqual((status, response), (200, REAL_RESPONSE))
        sent = json.loads(self.upstream.requests[0][2])
        actual = sent["capabilities"]["alwaysMatch"]
        self.assertEqual(actual["browserName"], "MicrosoftEdge")
        self.assertEqual(actual["ms:edgeOptions"]["binary"], "/usr/bin/microsoft-edge")
        self.assertIn("--headless=new", actual["ms:edgeOptions"]["args"])
        self.assertEqual(sent["desiredCapabilities"], actual)
        self.assertEqual(json.loads(self.evidence.read_text())["sessionId"], "actual-session")
        self.assertEqual(self.adapter.server_address[0], "127.0.0.1")

    def test_commands_and_upstream_errors_keep_status_and_body(self):
        self.upstream.status = 404
        self.upstream.body = b'{"value":{"error":"no such element","message":"edge text is absent"}}'
        command = b'{"script":"return window.edge;","args":[]}'
        self.assertEqual(self.request("POST", "/session/actual-session/execute/sync", command),
                         (404, self.upstream.body))
        self.assertEqual(self.upstream.requests[-1],
                         ("POST", "/session/actual-session/execute/sync", command))
        self.assertEqual(self.request("DELETE", "/session/actual-session"), (404, self.upstream.body))
        self.assertFalse(self.evidence.exists())

    def test_failed_new_session_is_not_reinterpreted_as_success(self):
        self.upstream.status = 500
        self.upstream.body = b'{"value":{"error":"session not created","message":"browser crashed"}}'
        self.assertEqual(self.request("POST", "/session", FLUTTER_REQUEST), (500, self.upstream.body))
        self.assertFalse(self.evidence.exists())

    def test_wrong_browser_and_version_are_rejected(self):
        for browser, version in (("chrome", "151.0.4129.101"), ("MicrosoftEdge", "150.0.4000.1")):
            with self.subTest(browser=browser, version=version):
                response = json.loads(REAL_RESPONSE)
                response["value"]["capabilities"].update(browserName=browser, browserVersion=version)
                self.upstream.body = json.dumps(response).encode()
                status, body = self.request("POST", "/session", FLUTTER_REQUEST)
                self.assertEqual(status, 502)
                self.assertEqual(json.loads(body)["value"]["error"], "session not created")
                self.assertFalse(self.evidence.exists())

    def test_only_exact_legacy_session_shapes_are_normalized(self):
        for request in (
            {"capabilities": {"alwaysMatch": LEGACY}},
            {"desiredCapabilities": LEGACY},
        ):
            _, changed = normalize_session(json.dumps(request).encode(), "/edge")
            self.assertTrue(changed)
        for body in (
            b'not JSON', b'{"capabilities":{"alwaysMatch":{"browserName":"MicrosoftEdge"}}}',
            b'{"desiredCapabilities":{"browserName":"chrome"}}',
            b'{"desiredCapabilities":{"acceptInsecureCerts":true,"browserName":"edge","unexpected":true}}',
        ):
            self.assertEqual(normalize_session(body, "/edge"), (body, False))

    def test_driver_connection_failure_remains_failure(self):
        self.upstream.shutdown()
        self.upstream.server_close()
        status, body = self.request("GET", "/status")
        self.assertEqual(status, 502)
        self.assertIn("unavailable", json.loads(body)["value"]["message"])

    def test_window_timeout_retains_failure_and_captures_real_diagnostics(self):
        diagnostic_dir = Path(self.directory.name, "diagnostics")
        self.adapter.diagnostics = diagnostic_dir
        error = b'{"value":{"error":"timeout","message":"renderer timed out"}}'
        png = b'\x89PNG\r\n\x1a\nactual screenshot bytes'
        self.upstream.responses.update({
            ("POST", "/session/actual-session/window/rect"): (500, error),
            ("GET", "/session/actual-session/url"): (
                200, b'{"value":"data:,"}',
            ),
            ("GET", "/session/actual-session/screenshot"): (
                200, json.dumps({"value": base64.b64encode(png).decode()}).encode(),
            ),
        })
        position = b'{"x":0,"y":0}'
        with patch("builtins.print") as output:
            self.assertEqual(
                self.request("POST", "/session/actual-session/window/rect", position),
                (500, error),
            )
        events = [json.loads(call.args[0]) for call in output.call_args_list]
        self.assertEqual(events[0]["event"], "webdriver_request")
        self.assertEqual(events[0]["parameters"], position.decode())
        self.assertEqual(events[1]["event"], "webdriver_response")
        self.assertEqual(events[1]["status"], 500)
        self.assertEqual(events[1]["response"], error.decode())
        self.assertGreaterEqual(events[1]["elapsed_seconds"], 0)
        self.assertEqual(self.upstream.requests[0], (
            "POST", "/session/actual-session/window/rect", position,
        ))
        self.assertEqual(len(self.upstream.requests), 3)
        report = json.loads(next(diagnostic_dir.glob("failure-*.json")).read_text())
        self.assertEqual(report["failed_command"]["status"], 500)
        self.assertEqual(report["url"]["response"], {"value": "data:,"})
        self.assertEqual(next(diagnostic_dir.glob("*.png")).read_bytes(), png)

    def test_failed_diagnostic_does_not_replace_original_window_error(self):
        self.adapter.diagnostics = Path(self.directory.name, "diagnostics")
        self.upstream.status = 500
        self.upstream.body = b'{"value":{"error":"timeout","message":"original renderer error"}}'
        status, response = self.request(
            "POST", "/session/actual-session/window/rect", b'{"x":0,"y":0}',
        )
        self.assertEqual((status, response), (500, self.upstream.body))
        self.assertFalse(list(self.adapter.diagnostics.glob("*.png")))
        report = json.loads(next(self.adapter.diagnostics.glob("failure-*.json")).read_text())
        self.assertEqual(report["screenshot"]["status"], 500)

    def test_diagnostic_transport_timeouts_are_recorded(self):
        self.adapter.diagnostics = Path(self.directory.name, "diagnostics")
        with patch("flutter_edge_webdriver.diagnostic_response") as probe:
            probe.side_effect = TimeoutError("renderer unavailable")
            self.adapter.capture_failure(1, "actual-session", {"status": 500})
        self.assertEqual(probe.call_count, 2)
        report = json.loads((self.adapter.diagnostics / "failure-1.json").read_text())
        self.assertIn("unavailable", report["url"]["diagnostic_error"])
        self.assertIn("unavailable", report["screenshot"]["diagnostic_error"])

    def test_slow_headers_and_chunked_bodies_obey_total_deadlines_and_close_sockets(self):
        self.adapter.diagnostics = Path(self.directory.name, "diagnostics")
        error = b'{"value":{"error":"timeout","message":"original renderer error"}}'
        path = "/session/actual-session/window/rect"
        self.upstream.responses[("POST", path)] = (500, error)
        for endpoint, mode in (("url", "headers"), ("screenshot", "chunked")):
            probe_path = f"/session/actual-session/{endpoint}"
            self.upstream.slow_modes[probe_path] = mode
            self.upstream.closed_connections[probe_path] = threading.Event()
        started = time.monotonic()
        self.assertEqual(
            self.request("POST", path, b'{"x":0,"y":0}', timeout=6),
            (500, error),
        )
        elapsed = time.monotonic() - started
        # Two real 2-second deadlines, with scheduler allowance; dribbling
        # headers/body for six seconds each must not extend the failed request.
        self.assertGreaterEqual(elapsed, 3.8)
        self.assertLess(elapsed, 4.8)
        for closed in self.upstream.closed_connections.values():
            self.assertTrue(closed.wait(timeout=0.5), "diagnostic socket stayed open")
        self.assertEqual(sum(method == "POST" for method, _, _ in self.upstream.requests), 1)
        report = json.loads(next(self.adapter.diagnostics.glob("failure-*.json")).read_text())
        self.assertIn("diagnostic_error", report["url"])
        self.assertIn("diagnostic_error", report["screenshot"])
        self.assertFalse(list(self.adapter.diagnostics.glob("*.png")))

    def test_mismatched_installed_driver_is_rejected(self):
        with patch("subprocess.check_output", side_effect=[
            "Microsoft Edge 151.0.4129.101", "Microsoft Edge WebDriver 151.0.4000.1",
        ]):
            with self.assertRaisesRegex(ValueError, "builds do not match"):
                installed_versions("/edge", "/msedgedriver")


if __name__ == "__main__":
    unittest.main()
