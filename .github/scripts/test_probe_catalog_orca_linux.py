"""Pure API-dispatch regressions; imports no GI and launches no GUI or AT."""

from types import SimpleNamespace
import unittest

from probe_catalog_orca_linux import read_interface_text


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


if __name__ == "__main__":
    unittest.main()
