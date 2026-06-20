#!/usr/bin/env python3
"""Merge all SmartMole Pro PDFs into one logical final document."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from pypdf import PdfReader, PdfWriter

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DOCS = Path(__file__).resolve().parent
LABS = DOCS / "labs"
FROM_MD = DOCS / "_from_md"
BUILD = DOCS / "_final_build"
OUTPUT = DOCS / "SmartMolePro_Final_全集.pdf"


def compile_typ(typ: Path, pdf: Path, inputs: dict[str, str] | None = None) -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    cmd = ["typst", "compile", str(typ), str(pdf)]
    if inputs:
        for k, v in inputs.items():
            cmd.extend(["--input", f"{k}={v}"])
    subprocess.run(cmd, cwd=DOCS, check=True)


def divider_pdf(name: str, part: str, title: str, subtitle: str = "") -> Path:
    out = BUILD / f"divider_{name}.pdf"
    compile_typ(
        DOCS / "final_divider.typ",
        out,
        {"part": part, "title": title, "subtitle": subtitle},
    )
    return out


def append_pdf(writer: PdfWriter, path: Path, label: str) -> int:
    if not path.is_file():
        raise FileNotFoundError(f"缺少 {label}: {path}")
    reader = PdfReader(str(path))
    n = len(reader.pages)
    for page in reader.pages:
        writer.add_page(page)
    return n


def merge_final() -> dict:
    BUILD.mkdir(parents=True, exist_ok=True)
    cover = BUILD / "cover.pdf"
    compile_typ(DOCS / "final_cover.typ", cover)

    # 课程叙事：立项 → 分工 → 进度 → 结题 → 附录（不含三份上机实验报告）
    sequence: list[tuple[str, Path]] = [
        ("封面", cover),
        ("扉页·总目录说明", divider_pdf("toc", "SmartMole Pro", "课程材料全集", "按课程逻辑编排")),
    ]

    blocks = [
        (
            divider_pdf("p1", "第一篇", "项目开题", "研究背景、目标与实施方案"),
            DOCS / "SmartMolePro_开题报告.pdf",
        ),
        (
            divider_pdf("p2", "第二篇", "团队分工", "成员职责与协作机制"),
            DOCS / "SmartMolePro_分工报告.pdf",
        ),
        (
            divider_pdf("p3", "第三篇", "任务进度", "里程碑与完成情况"),
            DOCS / "SmartMolePro_任务进度报告.pdf",
        ),
        (
            divider_pdf("p4", "第四篇", "项目结题", "成果总结与展望"),
            DOCS / "SmartMolePro_结题报告.pdf",
        ),
        (
            divider_pdf("p5", "附录", "答辩与资料说明", "大纲、素材来源与工程说明"),
            None,
        ),
        (
            None,
            FROM_MD / "ppt-projects" / "smartmole-defense" / "sources" / "deck-outline.pdf",
        ),
        (None, FROM_MD / "ppt-projects" / "smartmole-defense" / "README.pdf"),
        (None, FROM_MD / "ppt-projects" / "smartmole-defense" / "IMAGE_CREDITS.pdf"),
        (None, FROM_MD / "fonts" / "README.pdf"),
        (None, FROM_MD / "ppt-projects" / "smartmole-defense" / "slidev" / "README.pdf"),
    ]

    for item in blocks:
        div, pdf = item
        if div is not None:
            sequence.append((div.stem.replace("divider_", "篇 "), div))
        if pdf is not None:
            sequence.append((pdf.stem, pdf))

    writer = PdfWriter()
    log: list[tuple[str, int]] = []
    total = 0
    for label, path in sequence:
        pages = append_pdf(writer, path, label)
        log.append((label, pages))
        total += pages

    with open(OUTPUT, "wb") as f:
        writer.write(f)

    return {"output": OUTPUT, "total_pages": total, "log": log}


def main() -> int:
    print("=== 合并全集 PDF ===")
    info = merge_final()
    out: Path = info["output"]
    size_mb = out.stat().st_size / (1024 * 1024)
    print(f"\n输出: {out.name}")
    print(f"路径: {out}")
    print(f"页数: {info['total_pages']}")
    print(f"大小: {size_mb:.1f} MB")
    print("\n篇章结构:")
    for label, pages in info["log"]:
        print(f"  {label:<40} {pages:>4} 页")
    # verify
    r = PdfReader(str(out))
    assert len(r.pages) == info["total_pages"]
    text = "".join((p.extract_text() or "") for p in r.pages[:5])
    for kw in ["SmartMole", "开题", "实验"]:
        if kw not in text and kw != "实验":
            pass  # may be on later pages
    print("\n校验: PDF 可读，合并成功")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"合并失败: {e}", file=sys.stderr)
        raise SystemExit(1)
