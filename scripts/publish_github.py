#!/usr/bin/env python3
"""Publish only the package allowlist. gh handles authentication via GH_TOKEN."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def publish(root=ROOT, runner=subprocess.run):
    output = root / "dist"
    state = json.loads((output / "build.json").read_text())
    expected = [f"Craftalot-{state['version']}-retail.zip", "release.json", "SHA256SUMS"]
    if state["files"] != expected:
        raise ValueError("Unexpected release assets")
    for filename in expected:
        path = output / filename
        if path.name != filename or path.is_symlink() or not path.is_file():
            raise ValueError("Unsafe release asset")
    for line in (output / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ")
        if name not in expected or hashlib.sha256((output / name).read_bytes()).hexdigest() != digest:
            raise ValueError("Release checksum mismatch")
    body = ("Craftalot " + state["version"] + "\n\n"
            "Retail Azeroth Tailoring, Enchanting and Cooking.\n"
            "Install the packaged ZIP; release.json supplies WowUp flavor metadata.\n"
            "Run /craftalot in game. Auctionator is optional.\n\n"
            "Automated model, API-fixture and packaging tests pass before publication.\n"
            "Runtime in-game smoke testing remains required.\n"
            "See README for the expected-cost model and its limitations.\n\n"
            "Source commit: " + state["sha"] + "\n")
    with tempfile.TemporaryDirectory() as temp:
        notes = Path(temp) / "notes.md"
        notes.write_text(body)
        command = ["gh", "release", "create", state["tag"], "--target", state["sha"],
                   "--title", "Craftalot " + state["version"], "--notes-file", str(notes)]
        if state["prerelease"]:
            command.append("--prerelease")
        command.extend(str(output / name) for name in expected)
        runner(command, cwd=root, check=True)


if __name__ == "__main__":
    publish()
