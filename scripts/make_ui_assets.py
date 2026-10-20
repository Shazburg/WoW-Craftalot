"""Original antialiased rounded UI masks; no third-party artwork."""
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1] / "UI/Media"


def inside(x, y, inset=0):
    radius = 8 - inset
    if not inset <= x < 32-inset or not inset <= y < 32-inset:
        return False
    cx = min(max(x, 8), 24)
    cy = min(max(y, 8), 24)
    return (x-cx)**2 + (y-cy)**2 <= radius**2


def generate():
    ROOT.mkdir(exist_ok=True)
    for border in (False, True):
        pixels = bytearray()
        for y in range(32):
            for x in range(32):
                coverage = 0
                for sy in range(4):
                    for sx in range(4):
                        px, py = x+(sx+.5)/4, y+(sy+.5)/4
                        coverage += inside(px, py) and (not border or not inside(px, py, 1))
                pixels.extend((255,255,255,round(255*coverage/16)))
        header = struct.pack("<BBBHHBHHHHBB", 0,0,2,0,0,0,0,0,32,32,32,0x28)
        (ROOT / ("Border.tga" if border else "Round.tga")).write_bytes(header + pixels)


if __name__ == "__main__":
    generate()
