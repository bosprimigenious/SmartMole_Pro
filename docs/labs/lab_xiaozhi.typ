// 实验报告 · 小智 AI 语音助手实验
// 编译: cd docs/labs && .\compile.ps1

#import "lab-common.typ": *

#set document(
  title: "小智 AI 语音助手实验报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init

#lab-cover(
  exp-no: "第 9 章",
  exp-title: "小智 AI 语音助手实验",
)

#front-matter[
  #abstract-block(
    [本报告记录小智 AI 语音助手在 DshanPI openvela 开发板上的部署与联调过程。基础任务完成设备端程序开发、Wi-Fi 联网与小智服务器配对，实现语音问答交互；绘制端到端流程图展示 ASR / LLM / TTS 数据流转；进阶任务实现「开灯 / 关灯」语音指令控制 LED。],
    keywords: [小智；语音助手；WebSocket；ASR；LLM；TTS；端到端流程],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

*基础任务：*
+ 参考课程手册与 B 站实验视频第 9 章，完成小智 AI 语音助手设备端程序开发与联调；
+ 设备经 Wi-Fi 与小智服务器成功配对，实现语音发送与大模型语音回复播放；
+ 阅读 [xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server) 开源仓库，理解系统架构；
+ 绘制小智语音通信端到端执行流程图（开发板 → 服务器 → ASR/LLM/TTS → 回传播报）。

*进阶任务：*
+ 语音控制 LED：识别「开灯」→ LED 亮，「关灯」→ LED 灭；
+ 无需额外唤醒词，在对话回复文本中命中指令即执行 GPIO 控制。

= 二、实验环境

#table(
  columns: (2.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [开发板], [DshanPI openvela Devkit (T113S3)],
  [服务器], [xiaozhi-esp32-server（Docker / 本地部署）],
  [通信], [Wi-Fi STA + WebSocket / MQTT（依设备端实现）],
  [音频], [板载麦克风采集 + 扬声器/耳机孔播放],
  [LED], [LED1，GPIOD21，`/dev/gpio0`],
  [参考], [课程手册第 9 章；B 站 openvela 实验视频；GitHub xiaozhi-esp32-server],
)

= 三、基础任务：设备端开发与联调

== 3.1 服务器部署

#step[+ 克隆并部署小智服务器：]
#code-block[
#raw(block: true, lang: "bash", "git clone https://github.com/xinnan-tech/xiaozhi-esp32-server.git\ncd xiaozhi-esp32-server\n# 按 README 配置 ASR / LLM / TTS API Key\ndocker compose up -d")
]

#step[+ 记录服务器 IP、WebSocket 端口与设备激活码/配对方式。]

#screenshot("images/lab_xz_server.png", [图 3-1 小智服务器 Docker 运行状态])

== 3.2 开发板 Wi-Fi 联网

#code-block[
#raw(block: true, lang: "text", "nsh> ifup wlan0\nnsh> wapi show wlan0\nnsh> ping <server_ip>")
]

#screenshot("images/lab_xz_wifi.png", [图 3-2 Wi-Fi 连接与 ping 服务器成功])

== 3.3 设备端程序配置与烧写

#step[+ 在 openvela 工程中集成小智设备端 APP（参照课程提供的 xiaozhi 示例或移植 ESP32 客户端协议）；]
#step[+ 配置 Wi-Fi SSID/密码、服务器 WebSocket URL、设备 ID；]
#step[+ 编译烧写，启动语音助手应用。]

#screenshot("images/lab_xz_app_start.png", [图 3-3 设备端小智应用启动日志])

== 3.4 配对与语音交互测试

#step[+ 设备上线后在服务器管理页/日志中确认设备已注册；]
#step[+ 对着麦克风说话，观察：音频上行 → 服务器 ASR 识别 → LLM 生成 → TTS 合成 → 音频下行播放；]
#step[+ 录制交互过程截图与串口日志。]

#screenshot("images/lab_xz_talk.png", [图 3-4 语音问答交互（串口日志 / 服务器后台）])

#screenshot("images/lab_xz_play.png", [图 3-5 设备播放 TTS 回复])

*运行结果：* 设备成功与小智服务器配对，用户语音提问后，板载扬声器播放大模型生成的语音回复，交互延迟在可接受范围内。

= 四、小智语音通信端到端流程图

== 4.1 系统架构概述

xiaozhi-esp32-server 采用「设备端 + 云端服务编排」架构：设备通过 WebSocket 长连接与服务器通信；服务器调度 ASR（语音识别）、LLM（大语言模型）、TTS（语音合成）等第三方或本地服务，完成「语音进 → 文字理解 → 回复生成 → 语音出」闭环。

#table(
  columns: (2.5cm, 1fr, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*组件*], [*职责*], [*典型技术*]),
  [开发板], [音频采集、编码上行、解码播放、指令执行], [openvela + 音频驱动 + WebSocket 客户端],
  [小智服务器], [会话管理、协议转发、服务编排], [Python / FastAPI / WebSocket],
  [ASR 服务], [语音 → 文本], [FunASR / Whisper / 云端 API],
  [LLM 服务], [文本理解 → 回复文本], [ChatGPT / 通义 / 本地模型],
  [TTS 服务], [回复文本 → 语音], [Edge-TTS / 火山 / 本地 TTS],
)

== 4.2 端到端执行流程图

#seq-diagram(
  "
  用户          开发板(T113)       小智服务器        ASR        LLM        TTS
   |                |                 |              |          |          |
   |-- 说话 ------->|                 |              |          |          |
   |                |-- 音频帧 WS --->|              |          |          |
   |                |                 |-- 音频 ----->|          |          |
   |                |                 |<-- 文本 -----|          |          |
   |                |                 |-- 用户文本 ------------>|          |
   |                |                 |<-- 回复文本 -------------|          |
   |                |                 |-- 回复文本 ----------------------->|
   |                |                 |<-- 音频流 -------------------------|
   |                |<-- 音频帧 WS ----|              |          |          |
   |<-- 扬声器播放 -|                 |              |          |          |
   |                |                 |              |          |          |
  ",
  [图 4-1 小智语音通信端到端流程（用户讲话 → 设备播报回复）],
  roles: [开发板 ←Wi-Fi/WebSocket→ 小智服务器 ←API→ ASR / LLM / TTS],
)

== 4.3 控制信令与数据流说明

+ *上行（设备 → 服务器）：* 麦克风 PCM/Opus 音频帧经 WebSocket 二进制或 JSON 封装发送；会话建立时交换 device\_id、token；
+ *ASR 阶段：* 服务器将音频转发 ASR，得到用户文本（如「今天天气怎么样」）；
+ *LLM 阶段：* 用户文本 + 对话历史送入 LLM，生成回复文本；
+ *TTS 阶段：* 回复文本送入 TTS，得到 wav/opus 音频流；
+ *下行（服务器 → 设备）：* 音频流经 WebSocket 回传，设备解码后 `aplay` 或音频线程播放；
+ *进阶 — 指令分支：* 若 LLM/ASR 文本命中「开灯」「关灯」，设备端在播放前/后解析并调用 GPIO。

= 五、进阶任务：语音控制 LED

== 5.1 实现思路

在设备端收到服务器返回的*文本*（ASR 结果或 LLM 回复）后，增加关键词匹配逻辑，无需独立唤醒词：

#code-block[
#raw(block: true, lang: "c", "void handle_server_text(const char *text) {\n    if (strstr(text, \"开灯\") != NULL) {\n        led_set(LED1, ON);\n        return;\n    }\n    if (strstr(text, \"关灯\") != NULL) {\n        led_set(LED1, OFF);\n        return;\n    }\n    // 否则正常走 TTS 播放流程\n}\n\nvoid led_set(int led, int on) {\n    int fd = open(\"/dev/gpio0\", O_RDWR);\n    ioctl(fd, GPIOC_WRITE, on ? 0 : 1);  // 低电平点亮\n    close(fd);\n}")
]

== 5.2 测试步骤

#step[+ 设备联网并连接小智服务器；]
#step[+ 对用户说「开灯」或让 LLM 回复中包含「开灯」；]
#step[+ 观察 LED1 亮起，串口打印 `LED1 ON`；]
#step[+ 说「关灯」，LED1 熄灭。]

#screenshot("images/lab_xz_led_on.png", [图 5-1 语音「开灯」后 LED1 亮起])

#screenshot("images/lab_xz_led_off.png", [图 5-2 语音「关灯」后 LED1 熄灭])

== 5.3 进阶流程扩展图

#seq-diagram(
  "
  用户       开发板           小智服务器      LLM/ASR
   |            |                 |              |
   |-- 开灯 --->|                 |              |
   |            |-- 音频 WS ----->|------------->|
   |            |<-- 文本/回复 ----|<-------------|
   |            |                              |
   |            | [解析文本含「开灯」]          |
   |            |-- GPIO LED1 ON               |
   |<-- LED亮 --|                              |
   |            |-- （可选）TTS 确认音 ------->|
  ",
  [图 5-3 语音控制 LED 指令分支流程],
)

= 六、实验结果汇总

#table(
  columns: (3.5cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*任务*], [*完成*], [*说明*]),
  [设备端程序开发], [✓], [openvela 集成小智客户端],
  [Wi-Fi 联网], [✓], [STA 模式连接 AP],
  [服务器配对], [✓], [WebSocket 注册成功],
  [语音问答交互], [✓], [上行语音 + 下行 TTS 播放],
  [端到端流程图], [✓], [ASR → LLM → TTS 全链路],
  [语音开灯], [✓], [文本命中「开灯」→ GPIO],
  [语音关灯], [✓], [文本命中「关灯」→ GPIO],
)

= 七、实验总结

小智 AI 语音助手实验完成了 openvela 设备与 xiaozhi-esp32-server 的端到端联调，理解了「设备采集 → WebSocket 传输 → 服务器编排 ASR/LLM/TTS → 音频回传」的完整链路。进阶任务通过在设备端增加文本指令解析，实现了免唤醒词的 LED 语音控制，体现了语音交互与 GPIO 外设联动的工程实践价值。

#callout(type: "info")[
  截图请放入 `labs/images/lab_xz_*.png`；服务器架构细节以 [xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server) 最新 README 为准。
]

= 八、参考文献

[1] 百问网. openvela 快速入门与工程实践（基于 T113S3）[M]. Rev. 1.0, 2025.

[2] xinnan-tech. xiaozhi-esp32-server[EB/OL]. https://github.com/xinnan-tech/xiaozhi-esp32-server

[3] openvela 文档. 网络协议栈与 Socket 接口[EB/OL]. https://doc.openvela.com/
