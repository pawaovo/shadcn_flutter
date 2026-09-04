import ast
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from trace_catalog_inspector import InstrumentReads, ReadTrace


class TraceTests(unittest.TestCase):
    def test_one_call_same_result_and_no_object_stringification(self):
        class Opaque:
            def __repr__(self):
                raise AssertionError("must not stringify native objects")
        value = Opaque()
        calls = []
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.jsonl"
            trace = ReadTrace(path)
            try:
                result = trace.call("get_parent", 10, "parent_chain", {"path": (1, 2)},
                                    lambda: calls.append(1) or value)
                self.assertIs(result, value)
                self.assertEqual(calls, [1])
                rows = [json.loads(line) for line in path.read_text().splitlines()]
                self.assertEqual([row["phase"] for row in rows], ["before", "after"])
                self.assertEqual(rows[1]["result_type"], "Opaque")
            finally:
                trace.stream.close()

    def test_ast_preserves_one_getter_invocation_and_rethrows_same_error(self):
        error = ValueError("actual getter failure")
        calls = []
        class Node:
            def get_name(self):
                calls.append(1)
                raise error
        with tempfile.TemporaryDirectory() as directory:
            trace = ReadTrace(Path(directory) / "trace.jsonl")
            try:
                tree = ast.parse("def read(node):\n    path = (1, 2)\n    return node.get_name()\n")
                transform = InstrumentReads("read", 50)
                tree = transform.visit(tree)
                ast.fix_missing_locations(tree)
                namespace = {"_read_trace": trace}
                exec(compile(tree, "fixture", "exec"), namespace)
                with self.assertRaises(ValueError) as result:
                    namespace["read"](Node())
                self.assertIs(result.exception, error)
                self.assertEqual(calls, [1])
                self.assertEqual(transform.count, 1)
            finally:
                trace.stream.close()

    def test_before_record_is_visible_while_real_child_getter_is_blocked(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.jsonl"
            script = ("import time; from trace_catalog_inspector import ReadTrace; "
                      f"trace=ReadTrace({str(path)!r}); "
                      "trace.call('get_text', 12, 'read', {'path':(1,2)}, time.sleep, 30)")
            child = subprocess.Popen([sys.executable, "-c", script], cwd=Path(__file__).parent,
                                     stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    if path.exists() and path.stat().st_size:
                        break
                    time.sleep(.01)
                self.assertIsNone(child.poll())
                rows = [json.loads(line) for line in path.read_text().splitlines()]
                self.assertEqual([row["phase"] for row in rows], ["before"])
                self.assertEqual(rows[0]["method"], "get_text")
            finally:
                child.terminate()
                child.communicate(timeout=3)


if __name__ == "__main__":
    unittest.main()
