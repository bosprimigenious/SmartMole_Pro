#!/usr/bin/env python3
"""Convert Markdown under docs/ to Typst wrappers in docs/_from_md/."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pypandoc

DOCS_ROOT = Path(__file__).resolve().parents[1]
OUT_ROOT = DOCS_ROOT / "_from_md"

SKIP_DIR_NAMES = {
    "_from_md",
    "node_modules",
    ".git",
    "_pptx_extract",
    "images",
}

# Slidev deck source — keep as Slidev, not Typst PDF
SKIP_REL = {
    "ppt-projects/smartmole-defense/slidev/slides.md",
}


def should_skip(md_path: Path) -> bool:
    rel = md_path.relative_to(DOCS_ROOT).as_posix()
    if rel in SKIP_REL:
        return True
    return any(part in SKIP_DIR_NAMES for part in md_path.relative_to(DOCS_ROOT).parts)


def md_to_typst_body(md_text: str) -> str:
    body = pypandoc.convert_text(md_text, "typst", format="md")
    # Pandoc may emit labels like <hello>; strip empty anchor lines
    body = re.sub(r"^<[^>]+>\s*$", "", body, flags=re.MULTILINE)
    return body.strip() + "\n"


def wrap_typst(title: str, body: str, source_rel: str) -> str:
    safe_title = title.replace('"', '\\"')
    return f"""// Auto-generated from {source_rel}
// Do not edit by hand — run docs/compile-all.ps1

#set page(paper: "a4", margin: 2.5cm)
#set text(font: ("SimSun", "Microsoft YaHei"), size: 11pt, lang: "zh")
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")

#align(center)[
  #text(size: 16pt, weight: "bold")[{safe_title}]
  #v(0.4em)
  #text(size: 9pt, fill: gray)[源文件: {source_rel}]
]
#v(1.2em)

{body}
"""


def title_from_md(path: Path, md_text: str) -> str:
    for line in md_text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem


def convert_all() -> list[Path]:
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    for md_path in sorted(DOCS_ROOT.rglob("*.md")):
        if should_skip(md_path):
            continue
        rel = md_path.relative_to(DOCS_ROOT).as_posix()

        md_text = md_path.read_text(encoding="utf-8")
        body = md_to_typst_body(md_text)
        title = title_from_md(md_path, md_text)
        typ_content = wrap_typst(title, body, rel)

        out_typ = OUT_ROOT / rel.replace(".md", ".typ")
        out_typ.parent.mkdir(parents=True, exist_ok=True)
        out_typ.write_text(typ_content, encoding="utf-8")
        written.append(out_typ)
        print(f"  MD -> TYP  {rel}")

    return written


def main() -> int:
    print(f"Converting Markdown under {DOCS_ROOT} ...")
    files = convert_all()
    print(f"Done: {len(files)} Typst file(s) in {OUT_ROOT.relative_to(DOCS_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
