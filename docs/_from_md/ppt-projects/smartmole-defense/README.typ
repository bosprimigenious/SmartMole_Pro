// Auto-generated from ppt-projects/smartmole-defense/README.md
// Do not edit by hand — run docs/compile-all.ps1

#set page(paper: "a4", margin: 2.5cm)
#set text(font: ("SimSun", "Microsoft YaHei"), size: 11pt, lang: "zh")
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")

#align(center)[
  #text(size: 16pt, weight: "bold")[SmartMole Pro 答辩 · Slidev / SVG / PPT]
  #v(0.4em)
  #text(size: 9pt, fill: gray)[源文件: ppt-projects/smartmole-defense/README.md]
]
#v(1.2em)

= SmartMole Pro 答辩 · Slidev / SVG / PPT

#quote(block: true)[
答辩推荐：#strong[Slidev（北邮主题）] · 备选：SVG/PPTX
]

== Slidev 答辩（推荐 · 北京邮电大学）

```powershell
cd docs/ppt-projects/smartmole-defense/slidev
npm install
npm run setup
npm run dev        # http://localhost:3030
npm run export-pdf # 导出 PDF
```

#figure(
  align(center)[#table(
    columns: 2,
    align: (auto,auto,),
    table.header([特性], [说明],),
    table.hline(),
    [实时预览], [改 `slides.md` 自动刷新],
    [动画], [`<v-clicks>` 逐步展示],
    [图标], [`<carbon-wifi />` 等 Iconify],
    [图表], [Mermaid mindmap],
    [主题], [北邮蓝 `#003399` + 邮政绿 + 深色背景],
  )]
  , kind: table
  )

详见 #link("slidev/README.md")[`slidev/README.md`]

== SVG / PPT 一键生成

```powershell
cd docs
python scripts/build_svg_all.py
```

输出：

#figure(
  align(center)[#table(
    columns: 2,
    align: (auto,auto,),
    table.header([产物], [路径],),
    table.hline(),
    [#strong[22 页精美 SVG 源文件]], [`svg/01-cover.svg` …
    `svg/22-closing.svg`],
    [#strong[HTML 幻灯片（浏览器演示）]], [`html/index.html`],
    [#strong[PPT（SVG
    栅格化插入）]], [`docs/SmartMolePro_答辩PPT_SVG版.pptx`],
  )]
  , kind: table
  )

== 分步命令

```powershell
python scripts/generate_svg_slides.py   # 仅生成 SVG
python scripts/build_html_deck.py       # 仅生成 HTML
python scripts/build_from_svg.py        # SVG → PNG → PPTX
```

== HTML 演示

用浏览器打开：

`file:///…/docs/ppt-projects/smartmole-defense/html/index.html`

- `←` `→` / `Space` 翻页
- `F` 全屏
- 右侧「缩略图」面板快速跳转

== SVG 设计要素

- 山城层叠斜切 + 两江波浪底纹
- 渐变页眉 / 金色强调条
- 卡片阴影、进度条、架构图、联机拓扑、9 洞 UI 等矢量插图
- 结题视角 ✓ / ⚠ / × 状态色

== PPT 栅格化

Windows 无 Cairo 时使用 #strong[Playwright Chromium] 将 SVG 转为
1920×1080 PNG 再写入 PPTX。

首次需：`python -m playwright install chromium`

== 与旧版（python-pptx 拼图）关系

#figure(
  align(center)[#table(
    columns: 2,
    align: (auto,auto,),
    table.header([脚本], [说明],),
    table.hline(),
    [`fetch_ppt_assets.py` + `build_defense_ppt.py`], [照片 + PIL
    示意图版],
    [`build_svg_all.py`], [#strong[SVG 精排版版（本目录）]],
  )]
  , kind: table
  )

答辩建议优先使用 #strong[SVG 版 PPT] 或 #strong[HTML 全屏演示]；SVG
源文件可继续在 Figma / Inkscape 中微调。

