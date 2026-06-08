// SmartMole Pro · 实验报告共用模板（对齐 Unveil INTERFACE.typ 蓝色学术风）
// 三份上机实验报告共用

#import "../common.typ": *

// ── 实验报告封面 ──
#let lab-cover(
  exp-no: "",
  exp-title: "",
  student: "张恒基",
  student-id: "2024210926",
  student-class: "2024211301",
) = {
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
          #text(size: 10.5pt, tracking: 0.35em, fill: muted)[OpenVela 工程实践 · 上机实验]
          #v(0.55cm)
          #text(size: 26pt, weight: "bold", fill: ink)[
            #exp-title
          ]
          #v(0.45cm)
          #text(size: 14pt, fill: primary)[手册章节 #exp-no]
          #v(0.35cm)
          #text(size: 13pt, fill: muted)[
            DshanPI openvela Devkit · T113S3
          ]
        ]
      ]

      #v(1.2cm)

      #box(
        width: 11cm,
        inset: (x: 1.2cm, y: 0.85cm),
        fill: surface,
        radius: 6pt,
        stroke: 0.75pt + border,
      )[
        #align(center)[
          #grid(
            columns: (4em, 1fr),
            row-gutter: 0.55cm,
            align: (right, left),
            [姓　名], [#student],
            [学　号], [#student-id],
            [班　级], [#student-class],
            [指导教师], [修佳鹏],
            [提交日期], [#datetime.today().display("[year] 年 [month] 月 [day] 日")],
          )
        ]
      ]

      #v(1.2cm)
      #text(size: 11pt, fill: muted)[参考：《openvela 快速入门与工程实践（基于 T113S3）》]
    ]
  ]
  pagebreak()
}

// ── 截图占位（将 PNG 放入 labs/images/ 后替换为 #image(...)）──
#let screenshot(path, caption, width: 100%) = {
  figure(
    block(
      width: width,
      height: 7.5cm,
      fill: surface,
      stroke: (paint: border, dash: "dashed"),
      radius: 4pt,
      inset: 12pt,
      breakable: false,
    )[
      #align(center + horizon)[
        #set text(size: hint-size, fill: muted)
        【请插入截图】\
        `#path`\
        #v(0.4em)
        #caption
      ]
    ],
    caption: caption,
  )
}

// ── 时序图（ASCII，对齐 INTERFACE.typ）──
#let seq-diagram(content, caption, roles: none) = figure(
  block(
    width: 100%,
    fill: surface,
    inset: 14pt,
    radius: 4pt,
    stroke: 0.5pt + border,
    breakable: true,
  )[
    #if roles != none [
      #align(center)[
        #text(size: hint-size, fill: ink-soft)[#roles]
      ]
      #v(8pt)
    ]
    #set text(font: mono-font, size: 10.5pt)
    #set par(leading: 0.75em, spacing: 0pt)
    #raw(block: true, lang: "text", content.trim())
  ],
  caption: caption,
)

// ── 实验步骤编号列表 ──
#let step(body) = block(above: 0.6em, below: 0.6em)[
  #set par(first-line-indent: 0em)
  #body
]
