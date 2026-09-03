import copy
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

import profile_source_snapshot as snapshot


class SourceSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                        "commit", "-q", "--allow-empty", "-m", "fixture"],
                       cwd=self.root, check=True)
        self.write("lib/main.dart", "main() {}\n")
        self.write("packages/beautiful_ai_ui_catalog/macos/Runner/AppDelegate.swift", "first")
        self.write("packages/beautiful_ai_ui_catalog/macos/Runner.xcodeproj/project.pbxproj", "second")

    def write(self, path, content):
        output = self.root / path
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(content)

    def test_manifest_preserves_bytes_and_explicit_lexical_path_order(self):
        result = snapshot.capture(self.root)
        snapshot.validate(result)
        paths = [row["path"] for row in result["files"]]
        self.assertEqual(paths, sorted(paths))
        expected = "\n".join(row["path"] + "\0" + row["sha256"] for row in result["files"])
        self.assertEqual(result["manifest_sha256"], hashlib.sha256(expected.encode()).hexdigest())
        self.assertEqual(snapshot.comparison(result, snapshot.capture(self.root))["status"],
                         "verified_unchanged")

    def test_runtime_edit_is_invalid_even_when_git_status_shape_is_unchanged(self):
        before = snapshot.capture(self.root)
        self.write("lib/main.dart", "main() { print(1); }\n")
        after = snapshot.capture(self.root)
        result = snapshot.comparison(before, after)
        self.assertEqual(result["status"], "invalid_source_changed")
        self.assertEqual(result["changed_paths"], ["lib/main.dart"])

    def test_added_and_removed_inputs_are_detected(self):
        before = snapshot.capture(self.root)
        (self.root / "lib/main.dart").unlink()
        self.write("assets/new.json", "{}")
        result = snapshot.comparison(before, snapshot.capture(self.root))
        self.assertEqual(result["changed_paths"], ["assets/new.json", "lib/main.dart"])

    def test_native_generated_registrant_is_a_build_input(self):
        before = snapshot.capture(self.root)
        path = "packages/beautiful_ai_ui_catalog/macos/Flutter/GeneratedPluginRegistrant.swift"
        self.write(path, "new plugin")
        self.assertEqual(snapshot.comparison(before, snapshot.capture(self.root))["changed_paths"],
                         [path])

    def test_out_of_scope_docs_do_not_change_runtime_digest(self):
        before = snapshot.capture(self.root)
        self.write("docs/unrelated.md", "changed")
        result = snapshot.comparison(before, snapshot.capture(self.root))
        self.assertEqual(result["status"], "verified_unchanged")
        self.assertFalse(result["source_worktree_status_unchanged"])

    def test_tampered_manifest_or_duplicate_path_is_rejected(self):
        before = snapshot.capture(self.root)
        modified = copy.deepcopy(before)
        modified["files"][0]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            snapshot.comparison(modified, before)
        modified = copy.deepcopy(before)
        modified["files"].append(modified["files"][0])
        modified["manifest_sha256"] = snapshot.manifest_digest(modified["files"])
        with self.assertRaises(ValueError):
            snapshot.comparison(modified, before)


if __name__ == "__main__":
    unittest.main()
