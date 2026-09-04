"""Ownership checks and an actual Linux child-process observation."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from edge_resource_observation import ResourceSampler, owned_pids


class ResourceOwnershipTests(unittest.TestCase):
    def test_pid_scope_excludes_same_group_siblings_and_reused_root(self):
        rows = [
            dict(pid=10, ppid=1, pgrp=5, start_ticks=100),
            dict(pid=11, ppid=10, pgrp=7, start_ticks=101),
            dict(pid=12, ppid=11, pgrp=8, start_ticks=102),
            dict(pid=13, ppid=1, pgrp=5, start_ticks=103),
        ]
        self.assertEqual(owned_pids(rows, 5), {10, 11, 12, 13})
        self.assertEqual(owned_pids(rows, None, (10, 100)), {10, 11, 12})
        self.assertEqual(owned_pids(rows, None, (10, 999)), set())

    @unittest.skipUnless(sys.platform == "linux", "Requires actual Linux /proc")
    def test_live_child_is_observed_without_owning_or_stopping_it(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "resources.jsonl"
            child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(20)"])
            observer = None
            try:
                observer = ResourceSampler(None, output, root_pid=child.pid)
                deadline = time.monotonic() + 3
                samples = []
                while time.monotonic() < deadline:
                    if output.exists():
                        try:
                            samples = [json.loads(line) for line in output.read_text().splitlines()]
                        except json.JSONDecodeError:
                            samples = []
                    if samples:
                        break
                    time.sleep(0.01)
                self.assertTrue(samples, "The running process must produce resource evidence")
                pids = {row["pid"] for sample in samples for row in sample["processes"]}
                self.assertIn(child.pid, pids)
                self.assertNotIn(os.getpid(), pids, "A parent in the same group must not be observed")
                observer.stop_observing()
                self.assertIsNone(child.poll(), "Read-only observer must not stop its subject")
            finally:
                child.terminate()
                child.wait(timeout=3)
                if observer is not None:
                    observer.close()


if __name__ == "__main__":
    unittest.main()
