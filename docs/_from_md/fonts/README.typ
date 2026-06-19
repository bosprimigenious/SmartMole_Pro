// Auto-generated from fonts/README.md
// Do not edit by hand — run docs/compile-all.ps1

#set page(paper: "a4", margin: 2.5cm)
#set text(font: ("SimSun", "Microsoft YaHei"), size: 11pt, lang: "zh")
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")

#align(center)[
  #text(size: 16pt, weight: "bold")[报告字体]
  #v(0.4em)
  #text(size: 9pt, fill: gray)[源文件: fonts/README.md]
]
#v(1.2em)

= 报告字体

模板 v3 对齐 `INTERFACE.typ`：#strong[SimSun（宋体）] 优先，Consolas
等宽字体用于代码。

== 编译

```powershell
cd docs
.\compile.ps1
```

直接使用系统字体，无需 `--font-path`。

== fonts/ 目录

`NotoSerifSC-*.otf` 与 `Inter_18pt-*.ttf` 为旧版模板遗留，当前 v3
不再使用，可手动删除。

