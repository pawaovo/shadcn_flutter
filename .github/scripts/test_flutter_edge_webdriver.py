"""Protocol regressions for the pinned Flutter Edge session adapter; no browser."""

import http.client
import json
import tempfile
import threading
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
        self.send_response(self.server.status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(self.server.body)))
        self.end_headers()
        self.wfile.write(self.server.body)

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

    def request(self, method, path, body=b""):
        connection = http.client.HTTPConnection("127.0.0.1", self.adapter.server_port, timeout=3)
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

    def test_mismatched_installed_driver_is_rejected(self):
        with patch("subprocess.check_output", side_effect=[
            "Microsoft Edge 151.0.4129.101", "Microsoft Edge WebDriver 151.0.4000.1",
        ]):
            with self.assertRaisesRegex(ValueError, "builds do not match"):
                installed_versions("/edge", "/msedgedriver")


if __name__ == "__main__":
    unittest.main()
