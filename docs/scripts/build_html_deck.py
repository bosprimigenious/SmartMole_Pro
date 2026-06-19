#!/usr/bin/env python3
"""Build standalone HTML slide deck from SVG slides."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

DOCS = Path(__file__).resolve().parents[1]
ROOT = DOCS / "ppt-projects" / "smartmole-defense"
SVG_DIR = ROOT / "svg"
HTML_DIR = ROOT / "html"

CSS = """
:root {
  --primary: #006BB7;
  --dark: #003D6B;
  --gold: #D4A84B;
  --ink: #1A2E44;
  --muted: #6B7B8C;
  --bg: #0a1628;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; overflow: hidden; font-family: "Microsoft YaHei", "PingFang SC", sans-serif; background: var(--bg); color: #fff; }
#app { display: flex; flex-direction: column; height: 100vh; }
.toolbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 20px; background: linear-gradient(90deg, var(--dark), var(--primary));
  border-bottom: 2px solid var(--gold); flex-shrink: 0; z-index: 10;
}
.toolbar h1 { font-size: 15px; font-weight: 600; letter-spacing: 0.02em; }
.toolbar .meta { font-size: 12px; color: rgba(255,255,255,0.75); }
.toolbar .btns { display: flex; gap: 8px; }
.toolbar button {
  background: rgba(255,255,255,0.12); border: 1px solid rgba(255,255,255,0.25);
  color: #fff; padding: 6px 14px; border-radius: 8px; cursor: pointer; font-size: 13px;
  transition: background 0.15s;
}
.toolbar button:hover { background: rgba(255,255,255,0.22); }
#stage {
  flex: 1; display: flex; align-items: center; justify-content: center;
  padding: 16px 24px 8px; position: relative;
}
.slide-wrap {
  width: min(96vw, calc(96vh * 16 / 9)); aspect-ratio: 16/9;
  border-radius: 12px; overflow: hidden;
  box-shadow: 0 24px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.08);
  background: #FAFCFF;
}
.slide-wrap object, .slide-wrap img { width: 100%; height: 100%; display: block; }
#footer {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 24px 14px; flex-shrink: 0;
}
#progress { flex: 1; max-width: 400px; height: 4px; background: rgba(255,255,255,0.15); border-radius: 2px; margin: 0 20px; }
#progress-fill { height: 100%; background: linear-gradient(90deg, var(--gold), var(--primary)); border-radius: 2px; transition: width 0.25s; }
.thumbs {
  position: fixed; right: 0; top: 52px; bottom: 48px; width: 140px;
  overflow-y: auto; background: rgba(0,30,60,0.92); border-left: 1px solid rgba(255,255,255,0.1);
  padding: 8px; transform: translateX(100%); transition: transform 0.25s; z-index: 20;
}
.thumbs.open { transform: translateX(0); }
.thumbs button {
  display: block; width: 100%; margin-bottom: 6px; padding: 0; border: 2px solid transparent;
  border-radius: 6px; overflow: hidden; cursor: pointer; background: none;
}
.thumbs button.active { border-color: var(--gold); }
.thumbs object { width: 100%; pointer-events: none; }
#hint { font-size: 11px; color: var(--muted); }
@media (max-width: 768px) {
  .thumbs { display: none; }
  #stage { padding: 8px; }
}
"""

JS = """
const slides = SLIDES_JSON;
let idx = 0;
const obj = document.getElementById('slide-obj');
const label = document.getElementById('slide-label');
const fill = document.getElementById('progress-fill');
const thumbBox = document.getElementById('thumbs');

function show(i) {
  idx = Math.max(0, Math.min(slides.length - 1, i));
  const s = slides[idx];
  obj.data = '../svg/' + s.file + '?t=' + Date.now();
  label.textContent = (idx + 1) + ' / ' + slides.length + ' · ' + s.title;
  fill.style.width = ((idx + 1) / slides.length * 100) + '%';
  document.querySelectorAll('.thumbs button').forEach((b, j) => b.classList.toggle('active', j === idx));
  history.replaceState(null, '', '#' + (idx + 1));
}

function nav(d) { show(idx + d); }

document.addEventListener('keydown', e => {
  if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') { e.preventDefault(); nav(1); }
  if (e.key === 'ArrowLeft' || e.key === 'PageUp') { e.preventDefault(); nav(-1); }
  if (e.key === 'Home') show(0);
  if (e.key === 'End') show(slides.length - 1);
  if (e.key === 'f' || e.key === 'F') toggleFs();
});

document.getElementById('btn-prev').onclick = () => nav(-1);
document.getElementById('btn-next').onclick = () => nav(1);
document.getElementById('btn-fs').onclick = toggleFs;
document.getElementById('btn-thumbs').onclick = () => thumbBox.classList.toggle('open');

function toggleFs() {
  if (!document.fullscreenElement) document.documentElement.requestFullscreen();
  else document.exitFullscreen();
}

slides.forEach((s, i) => {
  const b = document.createElement('button');
  b.innerHTML = '<object data="../svg/' + s.file + '" type="image/svg+xml"></object>';
  b.onclick = () => show(i);
  thumbBox.appendChild(b);
});

const hash = parseInt(location.hash.replace('#', ''), 10);
show(isNaN(hash) ? 0 : hash - 1);
"""

TITLES = {
    "01-cover.svg": "封面",
    "02-motivation.svg": "背景与动机",
    "03-levels.svg": "五层目标",
    "04-highlights.svg": "技术亮点",
    "05-architecture.svg": "三层架构",
    "06-threads.svg": "多线程模型",
    "07-event-flow.svg": "事件流",
    "08-levels-game.svg": "五级闯关",
    "09-multimodal.svg": "多模态输入",
    "10-versus.svg": "Wi-Fi 联机",
    "11-ip-lock.svg": "IP 锁定",
    "12-sound-led.svg": "声光反馈",
    "13-storage.svg": "数据存储",
    "14-wifi-ui.svg": "WiFi 图形连接",
    "15-combo.svg": "COMBO",
    "16-hardware.svg": "硬件矩阵",
    "17-team.svg": "团队分工",
    "18-collab.svg": "协作机制",
    "19-timeline.svg": "里程碑",
    "20-completion.svg": "完成度对照",
    "21-innovation.svg": "创新对比",
    "22-closing.svg": "总结与展望",
}


def main():
    if not (SVG_DIR / "manifest.json").is_file():
        subprocess.run([sys.executable, str(DOCS / "scripts" / "generate_svg_slides.py")], check=True)

    manifest = json.loads((SVG_DIR / "manifest.json").read_text(encoding="utf-8"))
    slides_meta = [{"file": f, "title": TITLES.get(f, f)} for f in manifest]

    HTML_DIR.mkdir(parents=True, exist_ok=True)
    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>SmartMole Pro 答辩幻灯片</title>
  <style>{CSS}</style>
</head>
<body>
  <div id="app">
    <div class="toolbar">
      <div>
        <h1>SmartMole Pro · 多模态感知智能打地鼠竞技系统</h1>
        <div class="meta">第六组 · 结题答辩 · SVG 精排版</div>
      </div>
      <div class="btns">
        <button id="btn-prev">← 上一页</button>
        <button id="btn-next">下一页 →</button>
        <button id="btn-thumbs">缩略图</button>
        <button id="btn-fs">全屏 (F)</button>
      </div>
    </div>
    <div id="stage">
      <div class="slide-wrap">
        <object id="slide-obj" type="image/svg+xml" data="../svg/{manifest[0]}"></object>
      </div>
    </div>
    <div id="footer">
      <span id="hint">← → 翻页 · Space 下一页 · F 全屏</span>
      <div id="progress"><div id="progress-fill"></div></div>
      <span id="slide-label">1 / {len(manifest)} · {TITLES.get(manifest[0], "")}</span>
    </div>
  </div>
  <div id="thumbs" class="thumbs"></div>
  <script>
  const SLIDES_JSON = {json.dumps(slides_meta, ensure_ascii=False)};
  {JS}
  </script>
</body>
</html>
"""
    out = HTML_DIR / "index.html"
    out.write_text(html, encoding="utf-8")
    print(f"HTML deck → {out}")
    print(f"Open: file:///{out.as_posix()}")


if __name__ == "__main__":
    main()
