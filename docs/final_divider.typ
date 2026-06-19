#set page(paper: "a4", margin: 3cm)
#set text(font: ("SimSun", "Microsoft YaHei"), lang: "zh")

#let part = sys.inputs.at("part", default: "")
#let title = sys.inputs.at("title", default: "")
#let subtitle = sys.inputs.at("subtitle", default: "")

#align(center + horizon)[
  #text(13pt, fill: rgb("#2460e8"))[#part]
  #v(1.2em)
  #text(26pt, weight: "bold")[#title]
  #if subtitle != "" [
    #v(0.8em)
    #text(13pt, fill: gray)[#subtitle]
  ]
]
