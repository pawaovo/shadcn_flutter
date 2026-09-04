"""Pure API-dispatch regressions; imports no GI and launches no GUI or AT."""

from types import SimpleNamespace
import unittest

from probe_catalog_orca_linux import parent_chain_evidence, read_interface_text


class TextDispatchTests(unittest.TestCase):
    def test_text_interface_wins_over_accessible_getter_with_same_name(self):
        calls = []

        class Accessible:
            # GI returns an Accessible implementing Text. This zero-argument
            # interface getter shadows Text.get_text(start, end) on that object.
            def get_text(self):
                return self

            def get_character_count(self):
                return 7

        class Text:
            @staticmethod
            def get_character_count(interface):
                calls.append(("count", interface))
                return 7

            @staticmethod
            def get_text(interface, start, end):
                calls.append(("text", interface, start, end))
                return "cone 中文"

        interface = Accessible()
        value = read_interface_text(SimpleNamespace(Text=Text), interface)
        self.assertEqual(value, "cone 中文")
        self.assertEqual(calls, [("count", interface), ("text", interface, 0, 7)])

    def test_read_is_bounded_to_the_existing_1024_character_limit(self):
        calls = []

        class Text:
            @staticmethod
            def get_character_count(interface):
                return 10000

            @staticmethod
            def get_text(interface, start, end):
                calls.append((start, end))
                return "x" * (end - start)

        self.assertEqual(len(read_interface_text(SimpleNamespace(Text=Text), object())), 1024)
        self.assertEqual(calls, [(0, 1024)])


class ParentChainTests(unittest.TestCase):
    class Node:
        def __init__(self, name, role, path):
            self.record = {"name": name, "role": role, "path": path, "pid": 73}
            self.parent = None
            self.children = []

        def get_parent(self):
            return self.parent

        def get_index_in_parent(self):
            return self.parent.children.index(self)

        def get_child_count(self):
            return len(self.children)

        def get_child_at_index(self, index):
            return self.children[index]

    def tree(self):
        frame = self.Node("Catalog", "frame", [0])
        wrapper = self.Node("", "panel", [0, 0])
        socket = self.Node("", "filler", [0, 0, 0])
        theme = self.Node("Theme: light", "push button", [0, 0, 0, 0])
        frame.children, wrapper.children, socket.children = [wrapper], [socket], [theme]
        wrapper.parent, theme.parent = frame, socket
        # The same one-way edge observed in the real FlView bridge: wrapper
        # exposes socket as child, while socket reports no parent.
        known = {node: node.record for node in (frame, wrapper, socket, theme)}
        return frame, wrapper, socket, theme, known

    def test_downward_reachability_does_not_invent_missing_parent(self):
        frame, wrapper, socket, theme, known = self.tree()
        result = parent_chain_evidence(theme, known, {frame})
        self.assertFalse(result["frame_reached"])
        self.assertTrue(result["parent_ended_before_frame"])
        self.assertEqual([n["role"] for n in result["chain"]], ["push button", "filler"])
        self.assertTrue(result["links"][0]["parent_child_getter_matches"])
        self.assertIsNone(socket.parent)  # Observation must never repair/mutate.
        self.assertEqual(wrapper.children, [socket])

    def test_valid_upward_chain_and_reciprocal_edges_are_recorded(self):
        frame, wrapper, socket, theme, known = self.tree()
        socket.parent = wrapper
        result = parent_chain_evidence(theme, known, {frame})
        self.assertTrue(result["frame_reached"])
        self.assertFalse(result["errors"])
        self.assertTrue(all(link["parent_child_getter_matches"] and link["bfs_parent_matches"]
                            for link in result["links"]))

    def test_wrong_parent_child_getter_is_preserved_as_mismatch(self):
        frame, wrapper, socket, theme, known = self.tree()
        socket.parent = wrapper
        socket.get_child_at_index = lambda index: wrapper
        result = parent_chain_evidence(theme, known, {frame})
        self.assertTrue(result["frame_reached"])
        self.assertFalse(result["links"][0]["parent_child_getter_matches"])

    def test_unsupported_index_is_not_faked_or_confused_with_a_broken_parent(self):
        frame, wrapper, socket, theme, known = self.tree()
        socket.parent = wrapper
        socket.get_index_in_parent = lambda: -1
        result = parent_chain_evidence(theme, known, {frame})
        link = result["links"][1]
        self.assertTrue(result["frame_reached"])
        self.assertEqual(link["index_reported_by_child"], -1)
        self.assertIsNone(link["reported_index_child_matches"])
        self.assertEqual(link["index_observed_in_parent"], 0)
        self.assertTrue(link["parent_child_getter_matches"])
        self.assertFalse(link["parent_child_scan_truncated"])
        self.assertEqual(socket.get_index_in_parent(), -1)

    def test_cycle_and_query_error_are_bounded_diagnostics(self):
        frame, wrapper, socket, theme, known = self.tree()
        socket.parent, theme.children = theme, [socket]
        result = parent_chain_evidence(theme, known, {frame})
        self.assertTrue(result["cycle"])
        self.assertFalse(result["frame_reached"])

        def fail():
            raise RuntimeError("native parent getter failed")

        theme.get_parent = fail
        result = parent_chain_evidence(theme, known, {frame})
        self.assertIn("native parent getter failed", result["errors"][0])
        self.assertFalse(result["frame_reached"])


if __name__ == "__main__":
    unittest.main()
