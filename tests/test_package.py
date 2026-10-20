import hashlib
import importlib.util
import json
import struct
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package", ROOT / "scripts/package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class Packaging(unittest.TestCase):
    def test_release_is_deterministic_and_complete(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            state = package.build(ROOT, output, "a"*40, "refs/tags/v0.2.1")
            self.assertFalse(state["prerelease"])
            archive = output / state["files"][0]
            before = archive.read_bytes()
            package.build(ROOT, output, "a"*40, "refs/tags/v0.2.1")
            self.assertEqual(before, archive.read_bytes())
            with zipfile.ZipFile(archive) as z:
                names = z.namelist()
                self.assertTrue(all(n.startswith("Craftalot/") for n in names))
                self.assertFalse(any("tests/" in n or "scripts/" in n or ".git/" in n for n in names))
                self.assertIn("Craftalot/licenses/ProfessionDB.txt", names)
                for asset in ("Round", "Border"):
                    data=z.read(f"Craftalot/UI/Media/{asset}.tga")
                    width,height=struct.unpack_from("<HH",data,12)
                    self.assertEqual((width,height),(32,32))
                    self.assertEqual(len(data),18+32*32*4)
                toc = z.read("Craftalot/Craftalot.toc").decode()
                for line in toc.splitlines():
                    if line and not line.startswith("#"):
                        self.assertIn("Craftalot/" + line, names)
            meta = json.loads((output / "release.json").read_text())["releases"][0]
            self.assertEqual(meta["filename"], archive.name)
            self.assertEqual(meta["metadata"], [{"flavor":"mainline", "interface":120105}])
            for line in (output / "SHA256SUMS").read_text().splitlines():
                digest, name = line.split("  ")
                self.assertEqual(digest, hashlib.sha256((output / name).read_bytes()).hexdigest())

    def test_development_identity(self):
        with tempfile.TemporaryDirectory() as temp:
            state = package.build(ROOT, Path(temp), "b"*40, "refs/heads/main", "12")
            self.assertTrue(state["prerelease"])
            self.assertEqual(state["version"], "0.2.1-dev.12+bbbbbbbbbbbb")

    def test_wrong_tag_is_rejected(self):
        with self.assertRaises(ValueError):
            package.build(ROOT, Path("/unused"), "a"*40, "refs/tags/v9.0.0")

    def test_source_archive_matches_provenance(self):
        source = Path("/tmp/professiondb.zip")
        if not source.exists():
            self.skipTest("Original third-party archive is not available")
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),
                         "909cb41720cf6bf6920f1c25c644f89b39ad63087f589c07737e7da943c52379")


if __name__ == "__main__":
    unittest.main()
