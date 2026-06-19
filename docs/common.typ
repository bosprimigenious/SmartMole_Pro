// ─────────────────────────────────────────────
// SmartMole Pro · 通用报告模板 v3
// 样式对齐揭棋 INTERFACE.typ（蓝色学术风）
// 三份报告共用：report / progress / division
// ─────────────────────────────────────────────

// ── 字体（衬线体，宋体优先）──
#let main-font = ("SimSun", "SimHei", "Microsoft YaHei")
#let mono-font = ("Consolas", "Courier New", "DejaVu Sans Mono")

// ── 色板（取自 report_test.pdf 采样）──
#let primary = rgb("#2460e8")
#let primary-dark = rgb("#1e52d0")
#let primary-light = rgb("#dce8f8")
#let primary-line = rgb("#b4c8f8")
#let ink = rgb("#182838")
#let ink-soft = rgb("#445468")
#let muted = rgb("#8c98a8")
#let border = rgb("#dce0e4")
#let surface = rgb("#f4f8f8")
#let surface-2 = rgb("#ecf0f4")
#let success = rgb("#15803d")
#let warning = rgb("#c2410c")
#let error = rgb("#b91c1c")

// 兼容旧报告中的色名引用
#let accent = primary
#let accent-deep = primary-dark
#let accent-light = primary-light
#let gray-50 = surface
#let gray-100 = surface-2
#let gray-200 = border
#let gray-600 = muted
#let gray-800 = ink-soft
#let ok = success
#let ok-bg = rgb("#ecfdf5")
#let warn = warning
#let warn-bg = rgb("#fffbeb")
#let err = error
#let err-bg = rgb("#fef2f2")

#let tbl-header-bg = rgb("#ecf2fc")
#let tbl-fill = (x, y) => {
  if y == 0 { tbl-header-bg } else if calc.rem(y, 2) == 0 { surface } else { white }
}
#let tbl-text-fill = (x, y) => if y == 0 { primary-dark } else { ink-soft }

// ── 字号 ──
#let h1-size = 20pt
#let h2-size = 15pt
#let h3-size = 13pt
#let code-size = 10.5pt
#let caption-size = 11pt
#let hint-size = 11pt

// ── 页脚 ──
#let page-footer = context [
  #align(center)[
    #text(size: 10.5pt, fill: rgb(148, 163, 184))[#counter(page).display()]
  ]
]

// ── 卡片 ──
#let card(inset: 14pt, content) = {
  block(
    width: 100%, breakable: true,
    inset: inset, radius: 4pt,
    fill: surface, stroke: 0.5pt + border,
  )[#content]
}

// ── 提示框 ──
#let callout(type: "info", content) = {
  let (fg, bg, label) = if type == "success" {
    (success, ok-bg, "提示")
  } else if type == "warning" {
    (warning, warn-bg, "注意")
  } else if type == "error" {
    (error, err-bg, "警告")
  } else {
    (primary-dark, primary-light, "说明")
  }
  block(width: 100%, breakable: true, inset: 0pt)[
    #block(
      width: 100%, inset: (left: 14pt, right: 12pt, y: 10pt),
      radius: 4pt, fill: bg,
      stroke: (left: 3.5pt + fg),
    )[
      #text(size: hint-size, weight: "bold", fill: fg)[#label]
      #v(0.4em)
      #set par(first-line-indent: 0em)
      #content
    ]
  ]
}

// ── 代码块 ──
#let code-block(body) = block(
  width: 100%, breakable: true,
  fill: surface, inset: 10pt, radius: 3pt,
  stroke: 0.5pt + border,
)[
  #set text(font: mono-font, size: code-size)
  #set par(leading: 0.65em)
  #body
]

// ── Q&A ──
#let qa(q, a) = {
  block(above: 1em, below: 1em, breakable: true)[
    #block(inset: (left: 12pt), stroke: (left: 2pt + primary))[
      #set par(first-line-indent: 0em)
      #text(weight: "bold", fill: primary-dark)[问]
      #h(0.4em)
      #q
      #v(0.55em)
      #text(weight: "bold", fill: ink-soft)[答]
      #h(0.4em)
      #a
    ]
  ]
}

// ── 摘要 ──
#let abstract-block(body, title: "摘要", keywords: none) = {
  block(above: 0.5em, below: 1.4em, breakable: true)[
    #text(size: h2-size, weight: "bold", fill: primary-dark)[#title]
    #v(0.45em)
    #line(length: 2.4em, stroke: 1.5pt + primary)
    #v(0.65em)
    #set par(first-line-indent: 0em, justify: true, leading: 1.05em, spacing: 0.85em)
    #body
    #if keywords != none [
      #v(0.75em)
      #text(size: hint-size, fill: ink-soft)[关键词：#keywords]
    ]
  ]
}

// ── 目录标题 ──
#let outline-title = [目录]

// ── 封面成员信息 ──
#let cover-members = (
  (name: "张恒基", id: "2024210926", class: "2024211301"),
  (name: "曹佳轩", id: "2024210994", class: "2024211312"),
  (name: "缪钰", id: "2024210996", class: "2024211303"),
  (name: "郭志罡", id: "2024210937", class: "2024211302"),
  (name: "张耀辉", id: "2024211045", class: "2024211302"),
  (name: "朱辰骏", id: "2024211039", class: "2024211301"),
)
#let roster-dash = "—"

#let cover-member-cell(m) = [
  #text(size: 13pt, weight: "bold")[#m.name] \
  #v(0.25cm)
  #text(size: 12pt, fill: muted)[
    #if m.class != none { m.class } else { roster-dash } \
    #if m.id != none { m.id } else { roster-dash }
  ]
]

// ── 正文初始化（show 规则，确保页码/页脚作用于全文）──
#let report-init = doc => {
  set text(font: main-font, size: 12pt, fill: ink-soft)
  set par(first-line-indent: 0pt, spacing: 0.85em, justify: true, leading: 1.05em)
  set table(inset: (x: 10pt, y: 8pt))

  show strong: set text(weight: "bold", fill: ink-soft)
  show heading: set text(font: main-font)
  show raw.where(block: false): set text(font: mono-font, size: code-size)
  show raw.where(block: true): it => block(
    width: 100%, breakable: true,
    fill: surface, inset: 10pt, radius: 3pt,
    stroke: 0.5pt + border,
  )[
    #set text(font: mono-font, size: code-size)
    #set par(leading: 0.65em)
    #it
  ]

  set page(
    paper: "a4",
    margin: (left: 2.5cm, right: 2.5cm, top: 2.2cm, bottom: 2.2cm),
    numbering: "1",
    header: none,
    footer: page-footer,
  )

  set heading(numbering: none)

  show heading.where(level: 1): it => {
    block(breakable: false, above: 2em, below: 1em)[
      #block(
        width: 100%,
        inset: (left: 10pt, top: 10pt, bottom: 10pt),
        fill: primary-light,
        radius: 4pt,
        stroke: (left: 4pt + primary),
      )[
        #text(size: h1-size, weight: "bold", fill: primary-dark)[#it]
      ]
    ]
  }

  show heading.where(level: 2): it => {
    block(above: 1.4em, below: 0.7em)[
      #text(size: h2-size, weight: "bold", fill: primary)[#it]
      #v(0.15em)
      #line(length: 100%, stroke: 0.5pt + primary-line)
    ]
  }

  show heading.where(level: 3): it => {
    block(above: 1.1em, below: 0.55em)[
      #text(size: h3-size, weight: "bold", fill: ink-soft)[#it]
    ]
  }

  show outline.entry: it => {
    set par(first-line-indent: 0em)
    block(above: 0.28em, below: 0.28em)[
      #link(it.element.location(), it)
    ]
  }

  show figure: set align(center)
  show figure.caption: set text(size: caption-size)

  show table.cell.where(y: 0): set text(fill: primary-dark, weight: "bold", size: hint-size)

  doc
}

// ── 封面（INTERFACE 风格）──
#let cover-page(doc-type, submit-date: datetime.today()) = {
  page(
    margin: (top: 2.2cm, bottom: 2.2cm, x: 2.8cm),
    numbering: none, header: none, footer: none,
    fill: white,
  )[
    #set text(font: main-font)
    #align(center + horizon)[
      #block(
        width: 15cm,
        inset: (y: 1.1cm),
        stroke: (top: 2.5pt + rgb("#1a365d"), bottom: 0.75pt + border),
      )[
        #align(center)[
          #text(size: 10.5pt, tracking: 0.35em, fill: muted)[OpenVela 工程实践]
          #v(0.55cm)
          #text(size: 26pt, weight: "bold", fill: ink)[
            多模态感知智能打地鼠竞技系统
          ]
          #v(0.65cm)
          #text(size: 19pt, weight: "medium", fill: primary)[#doc-type]
          #v(0.35cm)
          #text(size: 13pt, fill: muted)[
            SmartMole Pro · OpenVela / NuttX
          ]
        ]
      ]

      #v(1.0cm)

      #align(center)[
        #set text(size: 11pt, fill: muted)
        开发平台　DshanPI openvela Devkit · T113S3 \
        指导教师　修佳鹏 \
        提交日期　#submit-date.display("[year] 年 [month] 月 [day] 日")
      ]

      #v(1.0cm)

      #box(
        width: 13cm,
        inset: (x: 1.2cm, y: 0.95cm),
        fill: surface,
        radius: 6pt,
        stroke: 0.75pt + border,
      )[
        #align(center)[
          #text(size: 11pt, weight: "bold", fill: ink-soft)[项目成员]
          #v(0.55cm)
          #grid(
            columns: (1fr, 1fr, 1fr),
            column-gutter: 1.2cm,
            row-gutter: 0.65cm,
            align: center + horizon,
            ..cover-members.map(cover-member-cell),
          )
        ]
      ]

      #v(1.2cm)

      #align(center)[
        #text(size: 11pt, fill: muted)[OpenVela 嵌入式工程实践]
      ]
    ]
  ]

  pagebreak()
}

// ── 前置部分（摘要、目录无页码）──
#let front-matter(body) = {
  set page(numbering: none, footer: none)
  body
}

// ── 正文起始（页码从 1 起）──
#let body-start = [
  #set page(
    paper: "a4",
    margin: (left: 2.5cm, right: 2.5cm, top: 2.2cm, bottom: 2.2cm),
    numbering: "1",
    header: none,
    footer: page-footer,
  )
  #counter(page).update(1)
]
