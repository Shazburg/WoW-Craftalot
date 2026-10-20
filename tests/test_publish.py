import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f"scripts/{name}.py")
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class Publisher(unittest.TestCase):
    def test_only_allowlisted_assets_and_notes_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            module("package").build(ROOT, root / "dist", "c"*40, "refs/tags/v0.2.0")
            calls = []
            def invoke(args, **kwargs):
                self.assertTrue(kwargs["check"])
                self.assertEqual(Path(args[args.index("--notes-file")+1]).read_text().splitlines()[0], "Craftalot 0.2.0")
                calls.append(args)
            module("publish_github").publish(root, invoke)
            self.assertEqual(len(calls), 1)
            self.assertNotIn("--prerelease", calls[0])
            self.assertEqual(calls[0][-1], str(root / "dist/SHA256SUMS"))

    def test_tampered_zip_is_rejected_before_network(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            state = module("package").build(ROOT, root / "dist", "d"*40, "refs/heads/main", "3")
            (root / "dist" / state["files"][0]).write_bytes(b"tampered")
            runner = Mock()
            with self.assertRaises(ValueError):
                module("publish_github").publish(root, runner)
            runner.assert_not_called()
