// SmartMole Pro · 结题报告

#import "common.typ": *

#set document(
  title: "SmartMole Pro 结题报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init
#cover-page("结 题 报 告")

#front-matter[
  #abstract-block(
    [本报告从#strong[结题视角]总结 SmartMole Pro 项目的实际交付：以 `src/MyWhackMole/MyWhackMole.c` 为唯一事实来源，对照开题 17 项功能目标逐一标注完成、降级或未完成状态，并详述音效框架、GPIO LED 降级、Wi-Fi 双板联机（含 IP 锁定分析）、WiFi 图形连接及未实现模块的技术原因。根目录 `res.zip` 含 8 个 wav 音频资源。整体完成度约 #strong[60%]，核心玩法（五级闯关 + 双板联机）可稳定演示。],
    keywords: [结题报告；MyWhackMole；实现分析；Wi-Fi 联机；音效],
  )

  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、项目概述

SmartMole Pro 在 OpenVela/NuttX 平台上将基础 WhackMole 实验扩展为具备#strong[五级闯关]与#strong[Wi-Fi 双板联机]的嵌入式娱乐系统。开题方案见 `report.typ`；本文档聚焦#strong[实际做了什么、遇到什么问题、如何解决或降级]。

= 二、完成情况总览

#table(
  columns: (0.6cm, 2.8cm, 1cm, 1fr),
  inset: 5pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*序号*], [*功能*], [*状态*], [*说明*]),
  [1], [音效系统], [⚠], [sound\_task 线程 + hit.wav；7 wav 资源就位未挂钩],
  [2], [LED 反馈], [⚠], [GPIO 单次闪烁 120ms；WS2812B 降级],
  [3], [Wi-Fi 双板联机], [✓], [START/SCORE/FINISH；versus 模块],
  [4], [五级闯关], [✓], [L52–58 参数表，LEVEL 按钮],
  [5], [黄金/炸弹地鼠], [✓], [L106–119 随机，L1006–1032 计分],
  [6], [COMBO 连击], [✓], [L159–174 奖励公式 3→+1, 5→+2, 10→+5],
  [7], [MODE 切换], [✓], [L186–200 SINGLE/VERSUS],
  [8], [物理按键 K1], [⚠], [key\_task L385–414 触发 START；K2 无],
  [9], [游戏 UI], [✓], [草地+锤子+9洞+5按钮 L461–680],
  [10], [versus 协议], [✓], [versus/ 目录 4 文件],
  [11], [音频资源 8 wav], [✓], [根目录 res.zip 已打包],
  [12], [HC-SR04], [×], [源码无引用],
  [13], [WS2812B], [×], [降级 GPIO LED],
  [14], [数据持久化], [⚠], [storage.c 文件方案，非 littlefs],
  [15], [排行榜/成就 UI], [×], [STATS 弹窗代替 Tab 榜],
  [16], [AI 动态难度], [×], [固定五关参数],
  [17], [反转模式], [×], [未开发],
  [18], [WiFi 图形连接], [✓], [wifi\_ui.c + wapi],
)

= 三、核心模块实现

== 3.1 音效系统

*资源：* 根目录 `res.zip` 含 hit/gold/bomb/combo/countdown/gameover/start/bgm 共 8 个 wav。

*实现：* 独立 `sound_task` 线程（L334–350），请求-消费模型（`play_sound_request`），当前仅播放 `hit.wav`（L343），在击中地鼠时触发（L1071）。

*待扩展：* 在 `mole_click_event` 中根据 `mole_types[i]` 分发 gold/bomb 音效；在 `update_game_timer` 倒计时 ≤5 播放 countdown；结算时播放 gameover。

== 3.2 LED 反馈与降级决策

*实现：* `led_task`（L354–381）通过 `/dev/gpio0` ioctl 控制板载 LED，击中亮 120ms。

*降级：* WS2812B SPI ±150ns 时序在并行开发周期内未调通；GPIO 方案稳定且已在基础实验验证，满足答辩「声光联动」最低要求。

== 3.3 Wi-Fi 双板联机

*协议：* UDP + 自定义 versus 报文（`versus_protocol.c`，24 字节包，CRC 校验，序列号去重）。

*线程：* `versus_rx_task`（L899–943）非阻塞收包；`versus_ui_timer_cb`（L945–963）50ms 刷新 UI。

*IP 锁定：*
#code-block[
#raw(block: true, lang: "c", "config.peer_ip = \"192.168.137.91\";  // L1103\nconfig.local_port = 43046;\nconfig.peer_port = 43045;")
]

- *原因：* 联调阶段优先保证固定双板对战稳定，未实现配置文件外置；
- *换板：* 改 IP/端口 → 编译 → 烧录；A/B 板端口互补；
- *方案：* `/data/versus.conf` 或 WiFi 弹窗增加对端 IP 输入。

== 3.4 WiFi 图形连接

`wifi_ui.c` 提供 LVGL 弹窗：SSID/密码输入、SCAN（结果存 `/data/wifi_scan.txt`）、CONNECT（`wapi` + `ifup wlan0`）。游戏界面 WIFI 按钮（L663）一键打开。

== 3.5 闯关与特殊地鼠

五级参数表（L52–58）控制刷新间隔、停留时长、同屏数量；黄金 +5、炸弹 -2、COMBO 加成已在单机模式完整实现（L1005–1048）。

== 3.6 数据存储

`storage.c` 将统计写入 `/data/whackmole_stats.dat`（最佳分、连击、联机场次/胜率）；结算自动更新（L850–854）；STATS 按钮弹窗只读展示（L286–322）。未实现 littlefs 与 Top-N 排行榜页。

= 四、未实现功能与原因分析

详见《开题报告》第十七章。摘要：

+ *超声波：* 无驱动代码，优先级低于联机/UI；
+ *WS2812B：* 时序精度未达标，GPIO 降级；
+ *littlefs 排行榜：* 文件 storage 已满足基本统计，Top-N UI 未做；
+ *AI 难度：* 固定五关已可答辩；
+ *音效全挂钩：* 框架就绪，增量工作量小；
+ *反转模式：* 依赖挥击输入，独立模块。

= 五、测试与演示

== 5.1 演示流程

+ 单机：选 LEVEL → START → 触摸打地鼠 → 观察 COMBO/黄金/炸弹 → Game Over 弹窗；
+ 联机：双板同网段 → MODE=VERSUS → 一方 START → 观察 P1/P2 分数同步 → 30s 后 FINISH 判定胜负；
+ WiFi：点 WIFI 按钮 → 输入 SSID/密码 → CONNECT → 串口确认 IP；
+ 统计：点 STATS 查看历史最佳与联机胜率。

== 5.2 已知问题

#table(
  columns: (2.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*问题*], [*说明*]),
  [IP 硬编码], [换板需改源码重编译],
  [音效不全], [仅 hit.wav 有声音],
  [联机特殊地鼠], [versus 模式简化计分，无黄金/炸弹],
  [K2 未接], [仅 K1 触发 START],
)

= 六、项目总结

== 6.1 技术收获

+ NuttX 多线程（pthread）+ LVGL 定时器协同；
+ UDP 应用层协议设计与双板联调经验；
+ `wapi` WiFi 配置与 LVGL 弹窗集成；
+ 嵌入式项目中的功能降级决策（WS2812B → GPIO LED）。

== 6.2 团队协作反思

versus 模块由张耀辉与张恒基结对验收后冻结，避免集成冲突；缪钰 UI 与音效框架、朱辰骏 storage 通过明确 API（`storage.h`、`wifi_ui.h`）接入。超声波与 AI 因人力集中于联机演示而延后，符合「核心玩法优先」策略。

== 6.3 后续改进方向

+ 音效类型枚举 + 7 wav 场景挂钩；
+ `/data/versus.conf` IP 外置；
+ storage 扩展 Top-N + 排行榜 LVGL Tab；
+ HC-SR04 驱动 + 统一事件队列；
+ WS2812B 替换 `led_task` 后端。

= 七、参考文献

[1] 百问网. openvela 快速入门与工程实践（基于 T113S3）[M]. Rev. 1.0, 2025.

[2] SmartMole Pro 开题报告. `docs/report.typ`, 2026.

[3] SmartMole Pro 任务进度报告. `docs/progress.typ`, 2026.

[4] SmartMole Pro 分工报告. `docs/division.typ`, 2026.

[5] LVGL Documentation[EB/OL]. https://docs.lvgl.io/, 2024.
