// SmartMole Pro · 任务进度总报告

#import "common.typ": *

#set document(
  title: "SmartMole Pro 任务进度报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init
#cover-page("任 务 进 度 报 告")

#front-matter[
  #abstract-block(
    [本报告对照开题方案，汇总 SmartMole Pro 项目截至 2026 年 6 月 8 日的实施进度。核心模块 `src/MyWhackMole/MyWhackMole.c` 已完成#strong[五级闯关]、#strong[双板 Wi-Fi 联机]、#strong[游戏 UI 与 WiFi 图形连接]、#strong[音效/LED 基础框架]及#strong[统计数据持久化]；根目录 `res.zip` 中 8 个 wav 资源已就位，当前代码仅对击中事件播放 `hit.wav`。整体进度约 #strong[≈60%]。详细实现分析见《结题报告》（`conclusion.typ`）。],
    keywords: [进度报告；MyWhackMole；闯关；Wi-Fi 联机；音效；WiFi UI],
  )

  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、报告说明

本报告为项目实施过程中的#strong[进度总报告]，与《开题报告》（`report.typ`）、《分工报告》（`division.typ`）及《结题报告》（`conclusion.typ`）配套使用：

+ *开题报告* — 方案论证与设计依据；
+ *任务进度报告*（本文档）— 已完成 / 进行中 / 待办对照；
+ *分工报告* — 成员任务与执行偏差；
+ *结题报告* — 实际实现、问题与解决方案。

= 二、总体进度概览

#table(
  columns: (2.5cm, 1.2cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*维度*], [*完成度*], [*说明*]),
  [基础目标], [100%], [WhackMole 可运行，演示镜像 `地鼠_WIFI图形联网版.img` 可用],
  [扩展目标], [30%], [K1 可触发 START；K2 / 超声波 / 统一事件队列未做],
  [进阶目标], [70%], [五关闯关 + WiFi 双板联机已完成；IP 仍硬编码],
  [亮点目标], [50%], [特殊地鼠 + 音效框架 + GPIO LED + 统计存储；WS2812B / 排行榜页未做],
  [工程目标], [40%], [游戏 UI + WiFi 弹窗 + 结算页可用；外壳 / 主题重构未做],
  [*综合估算*], [*≈60%*], [核心玩法 + 联机 + 基础体验层已通，加分项待补],
)

#callout(type: "warning")[
  双人联机对端 IP 硬编码为 `192.168.137.91`（`MyWhackMole.c` L1103），换板需改源码重编译。详见《开题报告》§十六与《结题报告》§3.3。
]

= 三、已完成功能（MyWhackMole.c）

== 3.1 交付物

#table(
  columns: (4.8cm, 1fr),
  inset: (x: 10pt, y: 9pt),
  stroke: 0.5pt + gray-200,
  fill: tbl-fill,
  align: (left + horizon, left + horizon),
  table.header([*交付物*], [*说明*]),
  [#text(hyphenate: false)[`src/MyWhackMole/`]], [主源码，集成路径 `apps/examples/MyWhackMole/`],
  [#text(hyphenate: false)[`MyWhackMole_Final_20260607.tar.gz`]], [完整源码包（2026-06-07，仓库根目录）],
  [#text(hyphenate: false)[`res.zip`]], [8 个 wav + 字体 + 图标，解压部署至 `/data/res/`],
  [#text(hyphenate: false)[`地鼠_WIFI图形联网版.img`]], [含 WiFi 图形菜单的演示镜像],
)

== 3.2 功能清单

#table(
  columns: (0.8cm, 3cm, 2.4cm, 1fr),
  inset: 6pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*序号*], [*功能*], [*负责人*], [*状态*]),
  [1], [双板 Wi-Fi 联机对战], [张耀辉/张恒基], [✓ 已验证],
  [2], [START 同步], [张耀辉/张恒基], [✓ 已验证],
  [3], [SCORE 同步], [张耀辉/张恒基], [✓ 已验证],
  [4], [FINISH 同步], [张耀辉/张恒基], [✓ 已验证],
  [5], [MODE 单机/联机切换], [张耀辉/张恒基], [✓ 已实现],
  [6], [LEVEL 1–5 闯关], [郭志罡/张恒基], [✓ 每关固定难度],
  [7], [黄金地鼠 +5 分], [郭志罡], [✓ 已实现],
  [8], [炸弹地鼠 -2 分], [郭志罡], [✓ 已实现],
  [9], [COMBO 连击奖励], [郭志罡], [✓ 已实现],
  [10], [联机联调与双板测试], [张恒基/张耀辉], [✓ 双板实机验证],
  [11], [音效框架 + hit.wav], [缪钰/张恒基], [⚠ 部分（仅 hit 已挂钩）],
  [12], [GPIO LED 击中闪烁], [缪钰/张恒基], [⚠ 部分（单次 120ms，非 WS2812B）],
  [13], [物理按键 K1], [曹佳轩/张恒基], [⚠ 部分（触发 START，无 K2）],
  [14], [游戏 UI], [缪钰/张恒基], [✓ 草地+锤子+9 洞+记分+按钮],
  [15], [WiFi 图形连接], [张恒基], [✓ `wifi_ui.c` + wapi],
  [16], [统计数据持久化], [朱辰骏/张恒基], [⚠ 部分（文件存储 + STATS 弹窗）],
)

#callout(type: "info")[
  联机对战由张耀辉与张恒基#strong[共同完成]：张耀辉负责 versus 核心实现，张恒基参与协议联调、双板实机测试与 WiFi UI 集成；测试采用各一块 DshanPI 开发板，在同一局域网下完成 START/SCORE/FINISH 全链路验证。
]

#callout(type: "success")[
  合并代码以 `src/MyWhackMole/MyWhackMole.c` 为准。versus 相关代码已验证通过，后续模块通过现有 API（`storage.h`、`wifi_ui.h`）接入，不重构 versus 内部逻辑。
]

= 四、与开题目标对照

#table(
  columns: (2cm, 2.3cm, 1cm, 2.2cm, 1fr),
  inset: 5pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*层级*], [*子项*], [*状态*], [*负责人*], [*备注*]),
  [基础], [基础游戏], [✓], [全员], [完成],
  [基础], [驱动稳定], [✓], [—], [触摸/LCD/Wi-Fi OK],
  [扩展], [物理按键 K1/K2], [⚠], [曹佳轩], [K1 可用触发 START；K2 未接],
  [扩展], [HC-SR04 挥击], [×], [曹佳轩], [代码无引用],
  [扩展], [统一事件队列], [×], [曹佳轩], [待开发],
  [进阶], [Wi-Fi 双板联机], [✓], [张耀辉/张恒基], [双板实机联调，无分屏],
  [进阶], [联机联调与调试], [✓], [张恒基/张耀辉], [各一块板，问题排查与验证],
  [进阶], [五级闯关], [✓], [郭志罡/张恒基], [LEVEL 1–5 参数表 L52–58],
  [进阶], [AI 微调难度], [×], [郭志罡/张恒基], [固定参数表，无 AI 引擎],
  [亮点], [黄金/炸弹/COMBO], [✓], [郭志罡], [已完成],
  [亮点], [WS2812B 声光], [⚠], [缪钰], [降级为 GPIO LED；音效框架已有],
  [亮点], [排行榜持久化], [⚠], [朱辰骏], [`storage.c` 统计文件，无 Top-N 榜],
  [亮点], [排行榜单页面], [×], [缪钰], [STATS 弹窗代替，无 Tab 榜],
  [工程], [LVGL GUI 全面重构], [⚠], [缪钰], [功能 UI 可用，视觉主题未统一],
  [工程], [选关 + 联机菜单], [✓], [张恒基/缪钰], [LEVEL/MODE/WIFI 按钮],
  [工程], [反转模式], [×], [曹佳轩], [未实现],
  [工程], [外壳集成], [×], [缪钰/全员], [答辩前],
  [联机], [IP 可配置], [×], [张恒基], [硬编码，见 L1103–1105],
)

= 五、里程碑进度

#table(
  columns: (2.8cm, 1.2cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*里程碑*], [*状态*], [*说明*]),
  [4/27 基础 WhackMole 稳定], [✓], [演示镜像可用，外设验证通过],
  [4/27 各外设独立验证], [✓], [触摸/LCD/Wi-Fi 基础 OK],
  [5/11 全模块联调], [✓], [闯关+联机+UI+WiFi 菜单已集成],
  [5/11 闯关+联机可演示], [✓], [五关 + WiFi 联机已验证；IP 仍锁定],
  [6/8 文档与结题材料], [进行中], [Typst 四份报告更新中],
  [6/15 答辩就绪], [进行中], [外壳 / 加分项 / IP 外置待补],
)

= 六、风险与阻塞项

#table(
  columns: (2.5cm, 1fr, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*风险*], [*影响*], [*应对*]),
  [versus IP 锁定], [换板无法联机测试], [改 L1103 IP 宏或配置文件外置],
  [音效未全挂钩], [7 个 wav 无触发], [扩展 sound\_task 分发逻辑],
  [WS2812B 时序], [灯条驱动失败], [已降级 GPIO LED；答辩演示 GPIO 方案],
  [littlefs 未接入], [无正式排行榜], [当前 `storage.c` 文件方案可答辩 STATS],
)
