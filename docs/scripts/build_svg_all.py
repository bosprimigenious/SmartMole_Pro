#!/usr/bin/env python3
"""Full SVG pipeline: generate SVG → HTML deck → PPTX."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

DOCS = Path(__file__).resolve().parents[1]
SCRIPTS = DOCS / "scripts"


def run(name: str):
    path = SCRIPTS / name
    print(f"\n=== {name} ===")
    subprocess.run([sys.executable, str(path)], check=True)


def main():
    run("generate_svg_slides.py")
    run("build_html_deck.py")
    run("build_from_svg.py")
    print("\n完成:")
    print("  SVG:  ppt-projects/smartmole-defense/svg/")
    print("  HTML: ppt-projects/smartmole-defense/html/index.html")
    print("  PPT:  SmartMolePro_答辩PPT_SVG版.pptx")


if __name__ == "__main__":
    main()
