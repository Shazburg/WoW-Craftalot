import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("package_for_github", ROOT / "scripts/package_for_github.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseIdentity(unittest.TestCase):
    def test_first_push_of_version_is_stable(self):
        opener=MagicMock(side_effect=HTTPError("https://api.github.com",404,"Not found",None,None))
        ref=module.release_ref(ROOT,"refs/heads/main","Shazburg/WoW-Craftalot","fixture",opener)
        self.assertEqual(ref,"refs/tags/v0.1.0")

    def test_existing_version_stays_development(self):
        opener=MagicMock()
        ref=module.release_ref(ROOT,"refs/heads/main","Shazburg/WoW-Craftalot","fixture",opener)
        self.assertEqual(ref,"refs/heads/main")

    def test_authentication_failures_never_look_like_missing_release(self):
        opener=MagicMock(side_effect=HTTPError("https://api.github.com",403,"Forbidden",None,None))
        with self.assertRaises(RuntimeError):
            module.release_ref(ROOT,"refs/heads/main","Shazburg/WoW-Craftalot","fixture",opener)

    def test_explicit_tag_does_not_query_network(self):
        opener=MagicMock()
        self.assertEqual(module.release_ref(ROOT,"refs/tags/v0.1.0","repo","fixture",opener),"refs/tags/v0.1.0")
        opener.assert_not_called()
