// Auto-generated from ppt-projects/smartmole-defense/slidev/README.md
// Do not edit by hand — run docs/compile-all.ps1

#set page(paper: "a4", margin: 2.5cm)
#set text(font: ("SimSun", "Microsoft YaHei"), size: 11pt, lang: "zh")
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")

#align(center)[
  #text(size: 16pt, weight: "bold")[SmartMole Pro · Slidev 答辩（北邮主题）]
  #v(0.4em)
  #text(size: 9pt, fill: gray)[源文件: ppt-projects/smartmole-defense/slidev/README.md]
]
#v(1.2em)

= SmartMole Pro · Slidev 答辩（北邮主题）

Markdown + Vue3 + UnoCSS 实时幻灯片，支持动画、过渡、Carbon
图标、Mermaid。

== 快速开始

```powershell
cd docs/ppt-projects/smartmole-defense/slidev
npm install
npm run setup      # 链接 public/images 与 public/svg
npm run dev        # http://localhost:3030
```

== 导出

```powershell
npm run export-pdf   # 输出 PDF（需 playwright）
npm run build        # 静态站点 dist/
```

== 北邮色板（styles/custom.css）

#figure(
  align(center)[#table(
    columns: 3,
    align: (auto,auto,auto,),
    table.header([变量], [色值], [用途],),
    table.hline(),
    [`--bupt-blue`], [`#003399`], [北邮蓝 · 主色],
    [`--bupt-post-green`], [`#00843d`], [邮政绿 · 点缀],
    [`--bupt-gold`], [`#d4a84b`], [金色强调],
    [`--bupt-bg`], [`#0a1628`], [深色背景],
  )]
  , kind: table
  )

== 文件

#figure(
  align(center)[#table(
    columns: 2,
    align: (auto,auto,),
    table.header([文件], [说明],),
    table.hline(),
    [`slides.md`], [22 页答辩内容],
    [`styles/custom.css`], [主题变量 + 卡片/表格],
    [`global-top.vue`], [页眉（北邮 · SmartMole Pro）],
    [`public/images/`], [链接至 `../assets/images`],
    [`public/svg/`], [链接至 `../svg`],
  )]
  , kind: table
  )

== 快捷键

- `Space` / `→` 下一页
- `F` 全屏（答辩推荐）
- `O` 概览模式

== 与其它产物关系

#figure(
  align(center)[#table(
    columns: 2,
    align: (auto,auto,),
    table.header([产物], [路径],),
    table.hline(),
    [SVG 源], [`../svg/`],
    [旧版 PPT], [`../../../SmartMolePro_答辩PPT_SVG版.pptx`],
    [Typst 报告], [`../../../conclusion.typ`],
  )]
  , kind: table
  )

