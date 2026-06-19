#!/usr/bin/env python3
"""Full docs build: MD -> Typst -> PDF for SmartMole Pro."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

DOCS = Path(__file__).resolve().parent
LABS = DOCS / "labs"
FROM_MD = DOCS / "_from_md"

PROJECT_REPORTS = [
    ("report.typ", "SmartMolePro_开题报告.pdf"),
    ("progress.typ", "SmartMolePro_任务进度报告.pdf"),
    ("division.typ", "SmartMolePro_分工报告.pdf"),
    ("conclusion.typ", "SmartMolePro_结题报告.pdf"),
]

LAB_REPORTS = [
    ("lab32_threads.typ", LABS / "实验1 初探实验" / "实验报告_3.2任务与线程.pdf"),
    ("lab_whackmole.typ", LABS / "实验2 基础实验" / "实验报告_MyWhackMole打地鼠.pdf"),
    ("lab_xiaozhi.typ", LABS / "实验3 综合实验" / "实验报告_小智AI语音助手.pdf"),
]


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(">", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd or DOCS, check=True)


def main() -> int:
    print("=== [1/5] Markdown -> Typst ===")
    run([sys.executable, str(DOCS / "scripts" / "md_to_typ.py")])

    print("\n=== [2/5] Project reports ===")
    for src, out in PROJECT_REPORTS:
        run(["typst", "compile", src, out])

    # Remove stale ASCII / mojibake duplicates from older builds
    keep = {name for _, name in PROJECT_REPORTS} | {"SmartMolePro_Final_全集.pdf"}
    for pdf in DOCS.glob("SmartMolePro_*.pdf"):
        if pdf.name not in keep:
            pdf.unlink(missing_ok=True)

    print("\n=== [3/5] Lab reports ===")
    for src, out in LAB_REPORTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        run(["typst", "compile", "--root", str(DOCS), src, str(out)], cwd=LABS)

    print("\n=== [4/5] Markdown-derived PDF ===")
    if FROM_MD.is_dir():
        for typ in sorted(FROM_MD.rglob("*.typ")):
            pdf = typ.with_suffix(".pdf")
            run(["typst", "compile", str(typ), str(pdf)])

    print("\n=== [5/5] Merge final PDF ===")
    run([sys.executable, str(DOCS / "merge_final.py")])

    print("\n=== Done ===")
    final = DOCS / "SmartMolePro_Final_全集.pdf"
    if final.is_file():
        print(f"  >>> {final.name}  ({final.stat().st_size / 1024 / 1024:.1f} MB)")
    for p in sorted(DOCS.glob("SmartMolePro_*.pdf")):
        if p.name == final.name:
            continue
        print(f"  {p.name}")
    for p in sorted(LABS.rglob("实验报告_*.pdf")):
        print(f"  labs/{p.relative_to(LABS)}")
    for p in sorted(FROM_MD.rglob("*.pdf")) if FROM_MD.is_dir() else []:
        print(f"  _from_md/{p.relative_to(FROM_MD)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as e:
        print(f"Build failed (exit {e.returncode})", file=sys.stderr)
        raise SystemExit(e.returncode)
