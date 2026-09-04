"""AT supervisor regressions using Python process fixtures; never launches AT/GUI."""

import json
import os
from pathlib import Path
import signal
import sys
import tempfile
import unittest
from unittest.mock import patch

import probe_real_at_linux as probe_module
from run_ios_catalog_journey import live_group_members


@unittest.skipIf(os.name == "nt", "The AT probe owns POSIX process groups")
class LinuxATSupervisorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name)
        self.probe = probe_module.Probe(self.output, 30)
        self.addCleanup(self.probe.finish)

    def test_live_orca_file_output_is_visible_before_process_exit(self):
        debug = self.output / "orca-debug.log"
        ready = self.output / "writer-ready"
        expected = "SPEECH OUTPUT: 'Orca capability beta 中文'\n".encode()
        # Orca 46.1 opens its --debug-file with open(path, 'w') and uses
        # writelines without flush. A regular file hides this idle tail.
        script = (
            "import sys,time\nfrom pathlib import Path\n"
            "destination = next(a.split('=', 1)[1] for a in sys.argv if a.startswith('--debug-file='))\n"
            "with open(destination, 'w', encoding='utf-8') as log:\n"
            " log.writelines([\"SPEECH OUTPUT: 'Orca capability beta 中文'\", '\\n'])\n"
            " Path(sys.argv[1]).touch()\n"
            " time.sleep(60)\n"
        )
        process = self.probe.spawn(
            [sys.executable, "-c", script, str(ready), "--debug-file=" + str(debug)], "orca")
        self.probe.wait_for(ready.exists, 3)
        self.assertIsNone(process.poll())
        self.probe.wait_for(lambda: debug.exists() and expected in debug.read_bytes(), 0.5)
        self.assertEqual(debug.read_bytes(), expected)
        self.assertIsNone(process.poll(), "Live evidence must not depend on process shutdown")
        self.probe.stop(process)
        self.assertEqual(live_group_members(process.pid), [])

    def test_exited_at_leader_does_not_hide_live_backend(self):
        ready = self.output / "backend.pid"
        script = (
            "import os,signal,time,sys\n"
            "if os.fork() == 0:\n"
            " signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            " open(sys.argv[1],'w').write(str(os.getpid()))\n"
            " time.sleep(60)\n"
            "else:\n"
            " while not os.path.exists(sys.argv[1]): time.sleep(.01)\n"
            " os._exit(0)\n"
        )
        process = self.probe.spawn([sys.executable, "-c", script, str(ready)], "fixture")
        try:
            self.assertEqual(process.wait(timeout=3), 0)
            self.assertIn(int(ready.read_text()), live_group_members(process.pid))
            self.probe.stop(process)
            self.assertEqual(live_group_members(process.pid), [])
        finally:
            if live_group_members(process.pid):
                os.killpg(process.pid, signal.SIGKILL)

    def test_cleanup_failure_rejects_capability_and_preserves_report(self):
        first, second = object(), object()
        self.probe.children.extend([first, second])
        self.probe.report["status"] = "capability_observed"
        with patch.object(self.probe, "stop", side_effect=[RuntimeError("backend survived"), None]) as stop:
            self.assertEqual(self.probe.finish(), 2)
        self.assertEqual([call.args[0] for call in stop.call_args_list], [second, first])
        report = json.loads((self.output / "report.json").read_text())
        self.assertEqual(report["status"], "not_accepted")
        self.assertEqual(report["application_acceptance"], "not_accepted")
        self.assertIn("Owned process cleanup: backend survived", report["errors"])
        self.probe.children.clear()


if __name__ == "__main__":
    unittest.main()
