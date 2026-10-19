#!/usr/bin/env python3
"""Build a deterministic Retail addon ZIP plus WowUp release metadata."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "Craftalot"


def build(root=ROOT, output=None, sha=None, ref=None, run=None):
    output = output or root / "dist"
    toc = (root / "Craftalot.toc").read_text()
    version = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc, re.M)
    if not version:
        raise ValueError("TOC needs a semantic version")
    base = version[1]
    if not re.search(r"^## Interface: 120105$", toc, re.M):
        raise ValueError("Unexpected interface version")
    ref = ref if ref is not None else os.environ.get("GITHUB_REF", "")
    sha = sha or os.environ.get("GITHUB_SHA") or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    if not re.fullmatch(r"[a-f0-9]{40,64}", sha):
        raise ValueError("Expected complete commit hash")
    if ref.startswith("refs/tags/"):
        tag = ref.removeprefix("refs/tags/")
        if tag != "v" + base:
            raise ValueError("Release tag must match TOC")
        packaged_version, prerelease = base, False
    else:
        run = run if run is not None else os.environ.get("GITHUB_RUN_NUMBER", "0")
        if not re.fullmatch(r"\d+", run):
            raise ValueError("Expected numeric run number")
        packaged_version = f"{base}-dev.{run}+{sha[:12]}"
        tag, prerelease = f"build-{run}-{sha[:12]}", True
    runtime = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    names = ["Craftalot.toc", *runtime, "README.md", "LICENSE", "Data/PROVENANCE.md", "licenses/ProfessionDB.txt"]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate runtime paths")
    for name in names:
        path = root / name
        if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Unsafe or missing runtime file: {name}")
    output.mkdir(parents=True, exist_ok=True)
    filename = f"Craftalot-{packaged_version}-retail.zip"
    with zipfile.ZipFile(output / filename, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name in names:
            data = (root / name).read_bytes()
            if name.endswith(".toc"):
                data = toc.replace(f"## Version: {base}", f"## Version: {packaged_version}").encode()
            info = zipfile.ZipInfo(f"Craftalot/{name}", date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    metadata = {"releases": [{"name": packaged_version, "filename": filename, "nolib": False,
                              "metadata": [{"flavor": "mainline", "interface": 120105}]}]}
    (output / "release.json").write_text(json.dumps(metadata, indent=2) + "\n")
    files = [filename, "release.json"]
    (output / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256((output / name).read_bytes()).hexdigest()}  {name}\n" for name in files))
    files.append("SHA256SUMS")
    state = dict(tag=tag, version=packaged_version, sha=sha, prerelease=prerelease, files=files)
    (output / "build.json").write_text(json.dumps(state, indent=2) + "\n")
    return state


if __name__ == "__main__":
    state = build()
    print("Built", state["version"])
