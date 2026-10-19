#!/usr/bin/env python3
"""First push of a new TOC version is stable; subsequent pushes are previews."""
import os
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from package import ROOT, build


def release_ref(root, ref, repository, token, opener=urlopen):
    if ref != "refs/heads/main":
        return ref
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid GitHub repository")
    version = re.search(r"^## Version: (\d+\.\d+\.\d+)$", (root / "Craftalot.toc").read_text(), re.M)
    if not version:
        raise ValueError("Missing TOC version")
    tag = "v" + version[1]
    request = Request(f"https://api.github.com/repos/{repository}/releases/tags/{tag}",
                      headers={"Authorization": "Bearer " + token,
                               "Accept": "application/vnd.github+json"})
    try:
        with opener(request, timeout=30):
            return ref
    except HTTPError as error:
        if error.code == 404:
            return "refs/tags/" + tag
        raise RuntimeError(f"GitHub release lookup failed (HTTP {error.code})") from None


if __name__ == "__main__":
    ref = release_ref(ROOT, os.environ["GITHUB_REF"], os.environ["GH_REPO"], os.environ["GH_TOKEN"])
    state = build(ref=ref)
    print("Built", state["version"], "(prerelease)" if state["prerelease"] else "(stable)")
