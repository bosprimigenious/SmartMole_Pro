"""SVG → PNG converters (cairo / svglib / playwright fallbacks)."""

from __future__ import annotations

from pathlib import Path

OUT_W, OUT_H = 1920, 1080


def svg_to_png(svg: Path, png: Path) -> bool:
    png.parent.mkdir(parents=True, exist_ok=True)
    for fn in (_cairo, _svglib, _playwright):
        if fn(svg, png):
            return True
    return False


def _cairo(svg: Path, png: Path) -> bool:
    try:
        import cairosvg

        cairosvg.svg2png(url=str(svg), write_to=str(png), output_width=OUT_W, output_height=OUT_H)
        return png.stat().st_size > 1000
    except Exception:
        return False


def _svglib(svg: Path, png: Path) -> bool:
    try:
        from reportlab.graphics import renderPM
        from svglib.svglib import svg2rlg

        drawing = svg2rlg(str(svg))
        if not drawing:
            return False
        renderPM.drawToFile(drawing, str(png), fmt="PNG", dpi=144)
        return png.stat().st_size > 1000
    except Exception:
        return False


def _playwright(svg: Path, png: Path) -> bool:
    try:
        from playwright.sync_api import sync_playwright

        uri = svg.resolve().as_uri()
        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            page = browser.new_page(viewport={"width": OUT_W, "height": OUT_H}, device_scale_factor=1)
            page.goto(uri, wait_until="networkidle")
            page.screenshot(path=str(png), type="png")
            browser.close()
        return png.stat().st_size > 1000
    except Exception as err:
        print(f"  playwright fail {svg.name}: {err}")
        return False
