#!/usr/bin/env python3
"""打包 SmartMole Pro 结题交付物为 zip（排除 .typ 等源文档）。"""

from __future__ import annotations

import zipfile
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_NAME = f"SmartMolePro_第六组_交付包_{date.today():%Y%m%d}.zip"
OUT_PATH = ROOT / OUT_NAME

# 用户点名的文档（相对仓库根目录）
DOC_FILES = [
    "docs/SmartMolePro_开题报告.pdf",
    "docs/SmartMolePro_结题报告.pdf",
    "docs/SmartMole Pro 多模态感知智能打地鼠竞技系统结题报告.pdf",
    "docs/第六组-SmartMole Pro：多模态感知智能打地鼠竞技系统.pptx",
]

# 代码目录（递归加入，仍受排除规则约束）
CODE_DIRS = [
    "src/MyWhackMole",
    "docs/labs/snippets",
]

# 可选：报告插图、编译脚本
EXTRA_PATHS = [
    "docs/images",
    "docs/compile_all.py",
    "docs/merge_final.py",
    "docs/compile.ps1",
    "docs/compile-all.ps1",
]

SKIP_DIR_NAMES = {
    ".git",
    ".cursor",
    "node_modules",
    "_pptx_extract",
    "_from_md",
    "__pycache__",
    ".idea",
    ".vscode",
}

SKIP_SUFFIXES = {
    ".typ",
    ".md",
    ".o",
    ".a",
    ".so",
    ".dep",
    ".swp",
    ".img",
}


def should_skip(path: Path) -> bool:
    if any(part in SKIP_DIR_NAMES for part in path.parts):
        return True
    if path.suffix.lower() in SKIP_SUFFIXES:
        return True
    return False


def add_file(zf: zipfile.ZipFile, src: Path, arcname: str) -> None:
    if not src.is_file():
        print(f"  [跳过-不存在] {src}")
        return
    zf.write(src, arcname)
    print(f"  + {arcname}")


def add_tree(zf: zipfile.ZipFile, dir_path: Path, arc_prefix: str) -> None:
    if not dir_path.is_dir():
        print(f"  [跳过-目录不存在] {dir_path}")
        return
    for p in sorted(dir_path.rglob("*")):
        if p.is_dir():
            continue
        rel = p.relative_to(ROOT)
        if should_skip(rel):
            continue
        arc = f"{arc_prefix}/{rel.as_posix()}"
        zf.write(p, arc)
    print(f"  + {arc_prefix}/... ({dir_path})")


README = """SmartMole Pro · 第六组结题交付包
================================

文档/
  SmartMolePro_开题报告.pdf
  SmartMolePro_结题报告.pdf
  SmartMole Pro 多模态感知智能打地鼠竞技系统结题报告.pdf
  第六组-SmartMole Pro：多模态感知智能打地鼠竞技系统.pptx

源码/
  src/MyWhackMole/          主工程 C 源码与 versus 联机模块
  docs/labs/snippets/       实验/报告用代码片段

其他/
  docs/images/              演示与采购实物图
  docs/compile*.py|ps1      文档编译脚本（可选）

说明：本 zip 不含 .typ / .md 源稿；镜像 .img 体积较大未打入包内。
"""


def main() -> None:
    if OUT_PATH.exists():
        OUT_PATH.unlink()

    print(f"输出: {OUT_PATH}")
    with zipfile.ZipFile(
        OUT_PATH, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6
    ) as zf:
        zf.writestr("README_交付说明.txt", README)

        print("\n[文档]")
        for rel in DOC_FILES:
            src = ROOT / rel
            name = Path(rel).name
            add_file(zf, src, f"文档/{name}")

        print("\n[源码目录]")
        for rel in CODE_DIRS:
            add_tree(zf, ROOT / rel, "源码")

        print("\n[附加]")
        for rel in EXTRA_PATHS:
            p = ROOT / rel
            if p.is_file() and not should_skip(p.relative_to(ROOT)):
                add_file(zf, p, f"其他/{p.name}")
            elif p.is_dir():
                add_tree(zf, p, "其他")

    size_mb = OUT_PATH.stat().st_size / (1024 * 1024)
    print(f"\n完成: {OUT_PATH.name} ({size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
