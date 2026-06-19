// 实验报告 · MyWhackMole 打地鼠（基础实验）
// 编译: cd docs/labs && .\compile.ps1
// 依据：实验2 基础实验/示例.txt 扩写，57 张截图按操作步骤穿插。

#import "lab-common.typ": *

#set document(
  title: "MyWhackMole 打地鼠游戏实验报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init

#lab-cover(
  exp-no: "基础实验",
  exp-title: "LVGL 程序开发 · MyWhackMole",
)

#front-matter[
  #abstract-block(
    [本报告在 openvela 平台上完成 MyWhackMole 打地鼠游戏的驱动适配、应用开发与进阶交互。实验修改 LCD Framebuffer（RGB565 字节序与横屏 480×320）、FT5X06 触摸驱动（中断模式与坐标映射），创建独立 LVGL 应用并打包 res 资源；进阶实现击中特效、hit.wav 音效、LED1 闪烁与 K1 开始游戏。全文以示例大纲为骨、操作细节为肉，图文穿插。],
    keywords: [MyWhackMole；LVGL；Framebuffer；FT5X06；RGB565；横屏；音效；GPIO],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

基础实验围绕 openvela 平台下的 LVGL 图形界面程序开发展开，通过修改 LCD、触摸屏驱动并运行 MyWhackMole 打地鼠游戏，完成基础图形交互功能和进阶外设交互功能。通过本次实验，主要实现以下目的：

+ *LCD 显示驱动*：掌握 LCD 显示驱动的基本修改方法，理解 Framebuffer、RGB565 像素格式和横屏显示适配对屏幕显示效果的影响，使开发板屏幕能够正常显示 LVGL 界面和 MyWhackMole 游戏画面；
+ *触摸屏输入驱动*：掌握触摸屏输入驱动的基本修改方法，理解触摸坐标上报、轮询/中断方式和坐标变换的作用，使触摸位置能够与屏幕显示位置对应，实现正常的人机交互；
+ *工程流程*：掌握 openvela 中 LVGL 应用程序的配置、编译、打包、烧录和串口运行流程，能够将 MyWhackMole 程序正确加入工程并在开发板上运行；
+ *游戏实现*：能够使用 LVGL 图形库 API 实现 WhackMole 基础游戏，包括游戏界面、地鼠随机出现与消失、触摸击中判断、分数显示、倒计时显示和游戏结束提示等功能；
+ *难度分析*：通过阅读 MyWhackMole 程序代码，分析游戏难度与地鼠出现间隔、停留时间、游戏时长、计分规则等因素之间的关系，理解如何通过修改参数或逻辑改变游戏难度；
+ *进阶交互*：在基础游戏功能上完成击中视觉特效、播放 hit.wav 音效、控制 LED1 闪烁，以及按下 K1 键开始游戏，从而加深对 openvela 图形界面、声卡、LED、按键和多任务协作开发流程的理解。

与初探实验相比，本实验不再是验证单个外设命令，而是把显示、输入、图形库、文件系统、音频与 GPIO 装配成*可交付的交互产品*。任何一环配置错误，都会在游戏运行阶段以花屏、点偏、无声或无法启动等形式暴露，因此本实验对工程排查能力要求更高。完成本实验后，应能独立定位「是驱动问题、资源路径问题还是 LVGL 逻辑问题」，为后续 SmartMole Pro 联机对战与关卡扩展打下工程基础。

*能力矩阵：* 驱动修改能力（Framebuffer/触摸）、应用工程能力（Kconfig/Makefile）、LVGL 界面能力（定时器/事件）、外设联调能力（音频/GPIO/按键）四项缺一不可；本实验刻意将四项串成一条交付链，模拟真实产品开发中的集成测试场景。

= 二、实验环境

#table(
  columns: (2.8cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [实验平台], [DshanPI openvela Devkit（T113S3）开发板],
  [主机系统], [Windows 11],
  [虚拟机环境], [VMware + Ubuntu 22.04],
  [源码目录], [`~/vela-opensource/`],
  [开发工具], [VS Code 远程连接 Ubuntu，用于查看、修改 openvela 源码和实验程序],
  [编译环境], [openvela 交叉编译；在 `~/vela-opensource/vendor/allwinnertech/lichee/` 下执行 vela\_env.sh、envsetup.sh、lunch\_nuttx、m、pack],
  [烧录工具], [PhoenixSuit；镜像 `rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img`],
  [串口工具], [MobaXterm，Serial 模式，Speed 1500000，Flow Control: none],
  [主要实验程序], [MyWhackMole：基于 LVGL 实现游戏界面、地鼠随机出现、触摸击中、计时和计分],
  [驱动修改], [LCD 显示驱动 + 触摸屏输入驱动；RGB565 适配、横屏适配、触摸坐标适配],
  [资源文件], [res 文件夹：游戏图片、字体、hit.wav；放入 UDISK 后打包到 `/data/res`],
  [外设功能], [LCD、触摸屏、声卡、LED1、K1：显示、触摸、音效、闪灯、按键开始],
  [连接方式], [两根 USB：一根烧录/调试，另一根串口输入输出],
)

*连接与路径说明：* 开发板通过两根 USB 线连接 Windows 主机。第一根线用于 PhoenixSuit 烧录与部分调试通道；第二根线枚举为串口设备（本机常见为 COM5/COM6，芯片 CH343），供 MobaXterm 以 1500000 波特率连接 NSH。源码统一放在 Ubuntu 虚拟机 `~/vela-opensource/`，VS Code Remote-SSH 直接编辑；编译入口固定为 `vendor/allwinnertech/lichee/`，切勿在未 `source envsetup.sh` 时执行 `m`。游戏资源在主机侧放入 `board/common/data/UDISK/res`，烧录后映射为开发板 `/data/res`；触摸设备节点为 `/dev/input0`，LED1 为 `/dev/gpio0`，K1 为 `/dev/gpio1`。牢记这三条路径，可快速区分「镜像未打包资源」与「程序写错路径」两类故障。

*主要路径速查：*

#table(
  columns: (4.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*用途*], [*路径*]),
  [LCD 驱动], [`nuttx/drivers/video/spi_lcd_fb.c`],
  [触摸驱动], [`nuttx/drivers/input/ft5x06.c`],
  [游戏应用], [`apps/examples/MyWhackMole/`],
  [资源打包], [`lichee/board/common/data/UDISK/res`],
  [运行时资源], [`/data/res`（板端）],
  [触摸节点], [`/dev/input0`],
  [LED1 / K1], [`/dev/gpio0`、`/dev/gpio1`],
)

= 三、实验原理

基础实验是在 openvela 平台上基于 LVGL 实现 MyWhackMole 打地鼠游戏。实验整体包括 LCD 显示、触摸输入、游戏逻辑、音效、LED 和按键交互等内容。以下分五部分说明各模块如何协同工作。

== 3.1 LVGL 图形库与界面对象

LVGL 是面向嵌入式设备的图形界面库，可以创建按钮、标签、图片、动画等界面对象。本实验使用 LVGL 创建游戏背景、地鼠洞、地鼠对象、分数标签、倒计时标签和开始按钮，并通过*事件回调*和*定时器*实现点击判断、计时计分和地鼠随机出现。LVGL 将控件树绘制到 Framebuffer，由显示驱动刷新到 LCD；触摸事件经 NuttX 输入子系统注入 LVGL 的 indev 读回调，最终在对象上触发 `LV_EVENT_CLICKED` 等事件。理解「绘制在 FB、输入走 indev」的双通道模型，是排查花屏与点偏的前提。

== 3.2 Framebuffer 与 RGB565

LCD 的显示依赖于 Framebuffer。Framebuffer 是保存整帧图像像素数据的内存区域，LVGL 将界面内容写入 Framebuffer 后，由 LCD 驱动发送到屏幕显示。本次实验 LCD 原始分辨率为 320×480，像素格式为 RGB565，每个像素占 16 bit，即红 5 位、绿 6 位、蓝 5 位。

由于 SPI 发送数据时存在高低字节顺序问题，需要在 LCD 驱动中交换 RGB565 数据的高低字节；否则会出现颜色错误、条纹或花屏。`sw_rgb565_swap` 以 32 位字批量交换高低字节，兼顾效率与边界像素。RGB565 单像素占 16 bit：R 5 位、G 6 位、B 5 位；整帧 480×320 约 300 KB，SPI 带宽与 `updatearea` 按行发送的策略直接影响刷新率。若仅修改 LVGL 分辨率而不改驱动 `xres/yres`，会出现裁剪或拉伸异常。

同时为了横屏显示游戏，还需要修改 LCD 方向参数和分辨率配置，使逻辑坐标系与 WhackMole 界面布局（480×320）一致。横屏不仅是「把屏转 90°」，而是 Framebuffer 宽高、扫描方向与触摸映射三者必须一致，否则玩家会看到横屏画面却按竖屏坐标点击。

== 3.3 触摸屏驱动 FT5X06

触摸屏驱动负责把用户触摸转换为坐标输入。本实验使用 FT5X06 触摸屏驱动，并将触摸设备作为 LVGL 的输入设备使用。触摸屏状态包括按下、滑动和松开；若使用轮询模式，容易错过按下和松开的瞬间，因此需要关闭 `FT5X06_POLLMOD`，改用中断方式，并启用 LVGL 的 NuttX 触摸屏支持（`LV_USE_NUTTX`、`LV_USE_NUTTX_TOUCHSCREEN`）。

横屏后还需要进行坐标交换（`FT5X06_SWAPXY`）和坐标修正（例如用触摸芯片 Y 通道换算 X 并做 480 方向翻转），使触摸位置与屏幕显示位置对应。若只做显示横屏而不改触摸映射，会出现「视觉横屏、触点仍按竖屏」的错位现象。

== 3.4 MyWhackMole 游戏核心逻辑

游戏开始后，`game_timer` 每秒递减 `game_time`，`mole_timer` 周期性调用 `pop_random_mole` 随机显示地鼠；用户点击屏幕时，`mole_click_event` 判断被点地鼠是否处于可见状态，击中则加分并隐藏地鼠。游戏难度可以通过地鼠出现间隔、停留时间、游戏总时长、计分规则等参数进行调整。`start_game` 负责重置状态并创建双定时器，是难度参数的集中入口。

== 3.5 进阶功能与多任务协作

进阶功能主要是在击中地鼠后增加反馈效果：视觉特效通过 LVGL 创建半透明框实现；音效通过播放 res 目录中的 hit.wav 实现；LED1 闪烁通过控制开发板 GPIO 实现；K1 开始游戏则通过读取按键输入并触发 `start_game` 实现。为了避免影响界面刷新，音效、LED 和按键检测适合使用任务、线程或标志位方式配合主界面运行，这也是手册 3.3 音乐任务与 LED 任务在本实验中的迁移应用。

通过本次实验，可以把 LCD、触摸屏、LVGL 图形界面、声卡、LED、按键和多任务协作结合起来，理解 openvela 上嵌入式图形交互程序的基本开发流程。

== 3.6 数据流总览

从用户手指到屏幕反馈的完整链路为：触摸芯片 → FT5X06 驱动（中断上报坐标）→ `/dev/input0` → LVGL indev → `mole_click_event`；击中后并行触发 LVGL 重绘（特效、隐藏地鼠、改分数）、`task_create` 播放音效、`flash_led1` 控制 GPIO。显示链路为：LVGL 绘制 → Framebuffer → `spi_lcd_updatearea`（RGB565 交换）→ SPI → LCD 面板。理解该双向数据流，有助于在联调时快速判断故障位于输入侧、显示侧还是应用逻辑侧。

= 四、实验内容与操作步骤

本章严格对照 `示例.txt` 大纲 (一)～(十一)，按「准备 → 显示驱动 → 触摸驱动 → 横屏 → 创建应用 → 游戏代码 → 资源 → 运行 → 难度分析 → 进阶功能」顺序展开。每一步写明*我做了什么*、*用了什么命令*、*预期现象*与*截图说明*；建议未完成 §4.1 外设自检前不要改游戏逻辑，否则故障难以定位。

== 4.1 (一) 实验准备与基础功能确认

*步骤 1：打开工程并备份驱动。* 我在 Windows 用 VS Code Remote-SSH 连接 Ubuntu，打开 `~/vela-opensource/`，确认可见 `apps`、`nuttx`、`vendor` 等目录（图 4-1）。为防止改错无法恢复，先备份 LCD 与触摸驱动：

#code-block[
#raw(block: true, lang: "bash", "mkdir -p ~/experiment_backup/whackmole
cp /home/ubuntu/vela-opensource/nuttx/drivers/video/spi_lcd_fb.c \\
  ~/experiment_backup/whackmole/spi_lcd_fb_before.c
cp /home/ubuntu/vela-opensource/nuttx/drivers/input/ft5x06.c \\
  ~/experiment_backup/whackmole/ft5x06_before.c
cp /home/ubuntu/vela-opensource/nuttx/drivers/input/Make.defs \\
  ~/experiment_backup/whackmole/input_Make_defs_before")
]

#lab-img("实验2 基础实验/微信图片_20260617233156_1722_16.png", [图 4-1 实验前工程总览与目录结构])

*图 4-1 说明：* VS Code 左侧资源管理器可见 `apps`、`nuttx`、`vendor` 等顶层目录，说明远程 SSH 已正确挂载 `~/vela-opensource`，后续改驱动与写应用都在此工程内进行。

#lab-img("实验2 基础实验/微信图片_20260617233855_1723_16.png", [图 4-2 备份命令执行记录])

*图 4-2 说明：* 终端执行 `mkdir` 与三条 `cp` 后无报错，驱动文件已备份到 `~/experiment_backup/whackmole/`。若横屏或触摸改乱，可从备份恢复，避免从零 diff。

*步骤 2：加载编译环境。* 进入 lichee，执行三件套并 `lunch_nuttx` 选 *2*（图 4-3、4-4）。未 source 直接 `m` 会报 command not found。

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/\nsource vela_env.sh\nsource envsetup.sh\nlunch_nuttx")
]

*步骤 3：串口连接。* MobaXterm Serial，1500000，Flow Control none（图 4-5）。

*步骤 4：外设自检。* 改驱动前先确认 LCD、触摸、LED、音频可用。我依次在 `nsh>` 执行下列命令（与示例一致）：

#code-block[
#raw(block: true, lang: "text", "nsh> fb
nsh> ft5x06 /dev/input0
nsh> led
nsh> amixer set 6 180
nsh> amixer set 7 180
nsh> amixer set 15 7
nsh> aplay -D hw:audiocodec /data/moon.wav")
]

其中，`fb` 用于测试 LCD 显示；`ft5x06 /dev/input0` 用于输出触摸坐标；`led` 用于测试 LED1 和 K1；`aplay` 用于测试音频播放。执行上述命令是为了确认后续驱动和进阶功能的基础是否正常。

#lab-img("实验2 基础实验/微信图片_20260617233855_1724_16.png", [图 4-3 lunch_nuttx 选择板级配置])

*图 4-3：* 选择序号 2，对应 T113S3 开发板工程。

#lab-img("实验2 基础实验/微信图片_20260617233855_1725_16.png", [图 4-4 环境变量与 RTOS_CONFIG_PATH 确认])

*图 4-4：* `RTOS_CONFIG_PATH` 应指向 `r528s3-velaevb1/configs/nsh`。

#lab-img("实验2 基础实验/微信图片_20260617233855_1726_16.png", [图 4-5 MobaXterm 串口参数])

*图 4-5：* Serial 1500000，Flow Control none。

但在 `help` 中我发现缺少 `fb` 和 `ft5x06`，说明未编入系统：

#lab-img("实验2 基础实验/微信图片_20260617233855_1727_16.png", [图 4-6 help 中缺少 fb/ft5x06 的现象])

*图 4-6：* `help` 列表无 `fb` 与 `ft5x06`，须先 menuconfig 启用。*步骤 5：menuconfig 启用测试程序。* 执行：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/
source vela_env.sh
source envsetup.sh
lunch_nuttx
m menuconfig")
]

#lab-img("实验2 基础实验/微信图片_20260617233855_1728_16.png", [图 4-7 menuconfig 入口])

*图 4-7：* 在 lichee 目录执行 `m menuconfig` 进入配置界面，与编译使用同一套 defconfig。

#lab-img("实验2 基础实验/微信图片_20260617233855_1729_16.png", [图 4-8 menuconfig 搜索启用 fb 相关项])

*图 4-8：* 按 `/` 搜索 fb 相关符号并启用，使 `fb` 命令编入 NSH。

#lab-img("实验2 基础实验/微信图片_20260617233855_1730_16.png", [图 4-9 menuconfig 启用 ft5x06 测试])

*图 4-9：* 启用 ft5x06 测试程序，便于在串口直接查看 `/dev/input0` 触摸坐标。

#lab-img("实验2 基础实验/微信图片_20260617233855_1731_16.png", [图 4-10 保存配置并重新编译])

*图 4-10：* 保存退出后重新 `m && pack` 烧录，新配置才会进入镜像。

开启后这两个内置程序就编译进系统了。接下来依次检测相关功能是否工作正常（每测一项对照一张截图，避免多项故障混在一起）：

#lab-img("实验2 基础实验/微信图片_20260617233856_1732_16.png", [图 4-11 fb 命令屏幕显示色块])

*图 4-11（fb）：* 执行 `nsh> fb` 后，LCD 应显示彩色色块或测试图案，证明 Framebuffer → SPI → 面板通路正常。若花屏，先记下现象，完成 §4.2 RGB565 交换后再对比。

#lab-img("实验2 基础实验/微信图片_20260617233856_1733_16.png", [图 4-12 fb 与串口输出对照])

*图 4-12：* 串口侧有 fb 命令回显，屏幕侧有色块，显示与日志一致。

#lab-img("实验2 基础实验/微信图片_20260617233856_1734_16.png", [图 4-13 ft5x06 触摸坐标输出])

*图 4-13（ft5x06）：* 执行 `nsh> ft5x06 /dev/input0` 后，手指按压屏幕时串口应打印 X/Y 坐标。无输出则检查触摸驱动与设备节点。

#lab-img("实验2 基础实验/微信图片_20260617233856_1735_16.png", [图 4-14 led 命令 LED1 闪烁])

*图 4-14（led）：* `nsh> led` 后 LED1 闪烁约 3 次，同时可验证 K1 按键电平是否在串口打印（为进阶 K1 开始游戏做准备）。

#lab-img("实验2 基础实验/微信图片_20260617233856_1736_16.png", [图 4-15 amixer 音量设置])

*图 4-15（amixer）：* 依次设置 codec 音量寄存器，避免后续 `aplay` 因音量过低误判为「声卡坏了」。

#lab-img("实验2 基础实验/微信图片_20260617233856_1737_16.png", [图 4-16 aplay 播放 moon.wav 成功])

*图 4-16（aplay）：* `aplay -D hw:audiocodec /data/moon.wav` 后板载扬声器可听到音乐，说明音频输出链路正常。

音乐正常播放！至此可确认：显示、触摸、LED、音频四条通路正常，再改驱动与写游戏时不易把问题混为一谈。

*自检结论：* `fb` 验证 Framebuffer 到面板的通路；`ft5x06` 验证触摸坐标上报；`led` 同时覆盖 LED 输出与 K1 输入（串口会打印按键电平）；`amixer` 调整 codec 音量避免 `aplay` 无声误判。四条命令均通过后再进入驱动修改，可将后续问题范围缩小到「本次改动」而非「板子根本不通」。

== 4.2 (二) 修改 LCD 显示驱动

*步骤 1：打开驱动文件。* 路径：`nuttx/drivers/video/spi_lcd_fb.c`（完整路径 `/home/ubuntu/vela-opensource/nuttx/drivers/video/spi_lcd_fb.c`）。本实验 LCD 经 SPI 发送 RGB565；发送顺序与 Framebuffer 存储的高低字节相反，须在发送前交换每个像素的两个字节。

*步骤 2：添加 sw_rgb565_swap。* 在 `spi_lcd_updatearea` 定义之前添加字节交换函数（见嵌入代码）。函数用 `0xff00ff00` / `0x00ff00ff` 掩码在 32 位字内成对交换，循环展开 8 字；奇数宽度行末像素单独处理。

*步骤 3：修改 spi_lcd_updatearea。* 按行 `memcpy` 到临时缓冲 → `sw_rgb565_swap` → `SPI_SNDBLOCK` 发出。

*步骤 4：编译打包烧录。* 保存后 lichee 目录 `m`、`pack`，PhoenixSuit 烧录。

*步骤 5：lvgldemo 验证。* 串口执行 `nsh> lvgldemo`，屏幕应显示白底界面与文字，无严重色偏花屏（图 4-19）。

#embed-code("snippets/sw_rgb565_swap.c")

然后修改 `spi_lcd_updatearea` 函数，使 SPI 发送交换顺序的数据。核心思路是：按行 `memcpy` 到临时缓冲区，调用 `sw_rgb565_swap` 后再 `SPI_SNDBLOCK` 发出：

#embed-code("snippets/spi_lcd_updatearea.c")

保存修改后的文件，编译、打包：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/
source vela_env.sh
source envsetup.sh
lunch_nuttx
m
pack")
]

烧录成功后在 MobaXterm 串口中输入 `lvgldemo` 并观察板子屏幕：

#lab-img("实验2 基础实验/微信图片_20260618001351_1738_16.png", [图 4-17 spi_lcd_fb.c 中 sw_rgb565_swap 与 updatearea])

*图 4-17：* 源码编辑区可见 `sw_rgb565_swap` 与 `spi_lcd_updatearea` 中按行 `memcpy`、交换、`SPI_SNDBLOCK` 的修改，与 §4.2 嵌入代码一致。

#lab-img("实验2 基础实验/微信图片_20260618001351_1739_16.png", [图 4-18 修改后编译打包日志])

*图 4-18：* `m` 重新编译 `spi_lcd_fb.c` 无错误；`pack` 成功生成 img，准备烧录。

#lab-img("实验2 基础实验/微信图片_20260618001351_1740_16.png", [图 4-19 lvgldemo 显示正常界面])

*图 4-19：* 烧录后 `nsh> lvgldemo`，屏幕白底界面与文字清晰，无严重色偏花屏，说明 RGB565 字节交换生效。

如图所示：屏幕能够显示白底图形界面和文字内容，界面清晰，说明 LVGL 能够正常使用 Framebuffer 进行显示。若仍花屏，应优先检查字节交换是否对每一行都调用，而非怀疑 LVGL 本身。

*原理补充：* RGB565 每个像素占 2 字节，SPI 控制器往往按 8 位流发送，若高低字节与面板期望相反，红色与蓝色通道会互换，绿色也可能错位，表现为整体色调异常。`sw_rgb565_swap` 使用位掩码 `0xff00ff00` 与 `0x00ff00ff` 在 32 位字内成对交换字节，循环展开 8 字以提升吞吐；奇数宽度行末像素单独处理，避免越界。`spi_lcd_updatearea` 按脏矩形逐行发送，是 LVGL 局部刷新的落点，因此字节交换必须发生在「每行发送前」而非整帧一次性处理。

== 4.3 修改触摸屏驱动

触摸屏状态包括按下、滑动和松开。若使用轮询模式，容易错过按下和松开的瞬间，因此本实验需要将触摸屏驱动改为中断方式。根据基础实验文档说明，将课程提供的改进版 `ft5x06.c` 和 `Make.defs` 复制到 `nuttx/drivers/input/` 并覆盖原文件。覆盖前可先备份：

#code-block[
#raw(block: true, lang: "bash", "mkdir -p ~/experiment_backup
cp /home/ubuntu/vela-opensource/nuttx/drivers/input/ft5x06.c \\
  ~/experiment_backup/ft5x06_before_whackmole.c
cp /home/ubuntu/vela-opensource/nuttx/drivers/input/Make.defs \\
  ~/experiment_backup/Make.defs_before_whackmole")
]

#lab-img("实验2 基础实验/微信图片_20260618001351_1741_16.png", [图 4-20 覆盖 ft5x06 驱动文件])

*图 4-20：* 将课程改进版 `ft5x06.c` 与 `Make.defs` 覆盖到 `nuttx/drivers/input/`，为中断模式触摸打基础。

进入 menuconfig 配置界面，搜索 `FT5X06_POLLMOD`，取消选中该配置项，使 FT5X06 触摸屏使用中断方式。继续搜索 `LV_USE_NUTTX` 和 `LV_USE_NUTTX_TOUCHSCREEN` 并选中，使 LVGL 能够通过 NuttX 输入设备读取触摸事件（记得按 Q、Y 保存）：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/
source vela_env.sh
source envsetup.sh
lunch_nuttx
m menuconfig")
]

#lab-img("实验2 基础实验/微信图片_20260618001351_1742_16.png", [图 4-21 menuconfig 关闭 FT5X06_POLLMOD])

*图 4-21：* 取消 `FT5X06_POLLMOD`，驱动改为中断上报，减少漏触。

#lab-img("实验2 基础实验/微信图片_20260618001351_1743_16.png", [图 4-22 启用 LV_USE_NUTTX_TOUCHSCREEN])

*图 4-22：* 同时启用 `LV_USE_NUTTX` 与 `LV_USE_NUTTX_TOUCHSCREEN`，LVGL 才能从 `/dev/input0` 读触摸事件。

编译、打包且烧录成功后，在串口中输入 `lvgldemo` 并观察：

#lab-img("实验2 基础实验/微信图片_20260618001351_1744_16.png", [图 4-23 lvgldemo 触摸点击响应])

*图 4-23：* 串口打印 framebuffer 与 touchscreen open success；点击 Wi-Fi 图标后界面切换，串口出现 `btn_set_wifi_event_cb`，证明触摸点击事件已送达 LVGL。

串口输出显示 framebuffer device opened successfully，且 touchscreen /dev/input0 open success，说明 LVGL 能够正常打开显示与触摸设备。触摸界面上的 Wi-Fi 标识后，屏幕切换到选择热点界面，且串口触发 btn_set_wifi_event_cb 相关输出，说明触摸事件能够被系统接收并响应，修改成功。

*中断与轮询对比：* 轮询模式下驱动周期性读取触摸芯片，若采样间隔大于手指按下持续时间，可能漏报 DOWN/UP 事件，表现为「点了没反应」或坐标跳变。中断模式在触摸发生时由硬件拉脚触发，驱动在中断上下文或工作队列中读取坐标，响应更及时。配合 `LV_USE_NUTTX_TOUCHSCREEN` 后，LVGL 通过标准输入设备接口获取事件，应用层无需直接读 I2C。

== 4.4 LCD 与触摸屏横屏适配

完成 LCD 基础显示修复和触摸屏驱动修改后，为了让 MyWhackMole 游戏界面更适合横屏显示，还需要继续对 LCD 显示方向、Framebuffer 分辨率以及触摸屏坐标映射进行适配。该步骤的核心目的是使屏幕显示方向变为 480×320 横屏，并保证触摸位置与界面响应位置一致。

*步骤 1：横屏扫描方向。* 搜索 `LCD_WritePara(0x48)`，将*所有*匹配处改为 `LCD_WritePara(0xe8)`（图 4-24）。该参数设置 LCD 扫描方向，竖屏改横屏必须修改。

*步骤 2：显示范围参数。* 在 `set_screen_size` 附近，原竖屏 320×480 列/行地址为 `0x3f`（320−1）与 `0xdf`（480−1）。横屏 480×320 需交换：

#code-block[
#raw(block: true, lang: "c", "// 原竖屏列 0~0x3f，行 0~0xdf\n// 横屏改为：列 0~0xdf，行 0~0x3f\nLCD_WriteCmd(0x2a);\nLCD_WritePara(0x00); LCD_WritePara(0x00);\nLCD_WritePara(0x01); LCD_WritePara(0xdf);  // 列 479\nLCD_WriteCmd(0x2b);\nLCD_WritePara(0x00); LCD_WritePara(0x00);\nLCD_WritePara(0x01); LCD_WritePara(0x3f);  // 行 319")
]

*步骤 3：Framebuffer 分辨率。* 在 `spi_lcd_fb_register` 中把 `fb->videoinfo.xres = 320; yres = 480` 改为 `xres = 480; yres = 320`（图 4-26），使 LVGL 按横屏布局。

*步骤 4：触摸坐标映射。* 打开 `ft5x06.c`，在 `#ifdef CONFIG_FT5X06_SWAPXY` 附近将 `x = TOUCH_POINT_GET_Y(touch[0])` 改为 `x = 480 - TOUCH_POINT_GET_Y(touch[0])`；多点触摸 `point[i].x` 同理（图 4-27）。

*步骤 5：启用 FT5X06_SWAPXY。* `m menuconfig` 搜索 `FT5X06_SWAPXY`，勾选 `[*] Swap X/Y`（图 4-28）。

*步骤 6：重新 m、pack、烧录，执行 lvgldemo。* 串口应显示 framebuffer open success，分辨率 `xres:480`、`yres:320`；触摸与显示位置一致（图 4-29、4-30）。

#lab-img("实验2 基础实验/微信图片_20260618001351_1745_16.png", [图 4-24 修改 LCD_WritePara 横屏扫描])

*图 4-24：* 将 `LCD_WritePara(0x48)` 改为 `0xe8`（所有匹配处均改），改变面板扫描方向。

#lab-img("实验2 基础实验/微信图片_20260618001351_1746_16.png", [图 4-25 列行地址窗口参数修改])

*图 4-25：* 列/行地址参数已对调，面板扫描窗口与横屏一致。

#lab-img("实验2 基础实验/微信图片_20260618001353_1747_16.png", [图 4-26 Framebuffer xres/yres 修改])

*图 4-26：* LVGL 与驱动报告的逻辑分辨率为 480×320。

#lab-img("实验2 基础实验/微信图片_20260618001353_1748_16.png", [图 4-27 ft5x06 横屏坐标公式修改])

*图 4-27：* 源码中可见横屏坐标换算，与显示方向匹配。

#lab-img("实验2 基础实验/微信图片_20260618001353_1749_16.png", [图 4-28 启用 FT5X06_SWAPXY])

*图 4-28：* menuconfig 中勾选 FT5X06_SWAPXY。

#lab-img("实验2 基础实验/微信图片_20260618001353_1750_16.png", [图 4-29 横屏 lvgldemo 显示与触摸验证 1])

*图 4-29：* 横屏界面完整显示，串口打印 `xres:480`、`yres:320`。

#lab-img("实验2 基础实验/微信图片_20260618001353_1751_16.png", [图 4-30 横屏 lvgldemo 显示与触摸验证 2])

*图 4-30：* 滑动与点击位置与按钮对齐，横屏显示与触摸映射联调通过。

横屏适配是 WhackMole 能否「玩得下去」的关键：显示与触摸必须同一套坐标系，否则会出现点 A 响应 B 的错位。

*横屏参数对照：* 竖屏时列地址 0x00–0x3f（320 列）、行地址 0x00–0xdf（480 行）；横屏后列扩展为 0xdf、行收缩为 0x3f，与 480×320 逻辑分辨率一致。`LCD_WritePara(0xe8)` 改变扫描方向，使面板行扫描与 Framebuffer 行序匹配。触摸侧在 `FT5X06_SWAPXY` 打开后，芯片原始 X/Y 与面板坐标轴对调，再用「480 减 Y」完成镜像修正，三者缺一不可。

== 4.5 创建 MyWhackMole 应用程序

#step[+ *复制 lvgldemo 为 MyWhackMole*：进入 apps/examples 目录，复制一份 lvgldemo 并重命名，复用 LVGL 初始化与应用结构：]

#code-block[
#raw(block: true, lang: "bash", "cd /home/ubuntu/vela-opensource/apps/examples
cp -r lvgldemo MyWhackMole
cd MyWhackMole")
]

#lab-img("实验2 基础实验/微信图片_20260618001353_1755_16.png", [图 4-31 复制 lvgldemo 为 MyWhackMole 目录])

*图 4-31：* `apps/examples` 下已存在 `MyWhackMole` 目录，由 lvgldemo 复制而来，保留 LVGL 初始化骨架。

#step[+ *修改 Kconfig*：将 LVGLDEMO 相关配置改为 MYWHACKMOLE，并添加程序优先级、栈大小、触摸屏设备路径和资源根目录。栈大小设为 327680 以保证 LVGL 与图片资源加载稳定：]

#embed-code("snippets/mywhackmole_kconfig", lang: "kconfig")

#lab-img("实验2 基础实验/微信图片_20260618001354_1752_16.png", [图 4-32 Kconfig 中 MYWHACKMOLE 配置项])

*图 4-32：* Kconfig 中已定义 MYWHACKMOLE 优先级、栈大小、触摸路径与 `/data/res` 资源根目录。

#step[+ *修改 apps/examples/Make.defs*：将 MyWhackMole 加入 openvela 应用编译队列：]

#code-block[
#raw(block: true, lang: "make", "ifneq ($(CONFIG_EXAMPLES_MYWHACKMOLE),)\nCONFIGURED_APPS += $(APPDIR)/examples/MyWhackMole\nendif")
]

#lab-img("实验2 基础实验/微信图片_20260618001354_1753_16.png", [图 4-33 Make.defs 加入编译队列])

*图 4-33：* `CONFIGURED_APPS` 包含 `MyWhackMole`，`m` 时才会编译本应用。

#step[+ *修改 Makefile*：`PROGNAME` 定义串口命令名 `mywhackmole`，`MAINSRC` 指定主函数文件，`CSRCS` 指定游戏核心源码：]

#code-block[
#raw(block: true, lang: "make", "include $(APPDIR)/Make.defs\n\nPROGNAME = mywhackmole\nPRIORITY = $(CONFIG_EXAMPLES_MYWHACKMOLE_PRIORITY)\nSTACKSIZE = $(CONFIG_EXAMPLES_MYWHACKMOLE_STACKSIZE)\nMODULE = $(CONFIG_EXAMPLES_MYWHACKMOLE)\n\nCSRCS = MyWhackMole.c\nMAINSRC = MyWhackMole_main.c\n\ninclude $(APPDIR)/Application.mk")
]

#lab-img("实验2 基础实验/微信图片_20260618001354_1754_16.png", [图 4-34 Makefile 与 PROGNAME 配置])

*图 4-34：* `PROGNAME = mywhackmole` 决定 NSH 命令名；`MAINSRC`/`CSRCS` 指向主文件与游戏逻辑。

#step[+ *修改 CMakeLists.txt*：将 MyWhackMole_main.c 和 MyWhackMole.c 加入 SRCS，使 CMake 构建流程也能识别本程序源码。]

#lab-img("实验2 基础实验/微信图片_20260618001357_1756_16.png", [图 4-35 CMakeLists.txt 源文件列表])

*图 4-35：* CMake 构建路径同样登记 `MyWhackMole_main.c` 与 `MyWhackMole.c`。

#step[+ *修改 MyWhackMole_main.c*：将原 lvgldemo.c 重命名，包含头文件 MyWhackMole.h；用条件编译屏蔽原 `lv_demos_create` 调用，改调 `app_create`：]

#code-block[
#raw(block: true, lang: "c", "#include \"MyWhackMole.h\"\n/* 条件编译屏蔽原有 lv_demos_create */\n#if 0\nlv_demos_create();\n#endif\n/* 创建 WhackMole 游戏界面 */\napp_create();")
]

#lab-img("实验2 基础实验/微信图片_20260618001357_1757_16.png", [图 4-36 MyWhackMole_main.c 调用 app_create])

*图 4-36：* 主函数屏蔽 `lv_demos_create`，改为调用 `app_create()` 进入打地鼠界面。

在 MyWhackMole 目录中新建 MyWhackMole.h 和 MyWhackMole.c，目录下应包含 CMakeLists.txt、Kconfig、Make.defs、Makefile、MyWhackMole.c、MyWhackMole.h、MyWhackMole_main.c 共七个关键文件。

*工程集成要点：* openvela 应用需同时满足 Kconfig（生成 CONFIG 符号）、Make.defs（加入 CONFIGURED_APPS）、Makefile（PROGNAME/MAINSRC/CSRCS）三处配置，CMakeLists.txt 为部分板级 CMake 流程提供兼容。栈大小 327680 字节（320 KiB）对 LVGL 加多图资源较充裕；若运行时出现栈溢出，串口可能无明显报错而直接复位，可通过增大 STACKSIZE 或精简局部变量排查。PROGNAME 决定 NSH 命令名，课程验收时应执行 `mywhackmole` 而非 `lvgldemo`。

== 4.6 编写 MyWhackMole 游戏核心代码

*（1）头文件 MyWhackMole.h* 主要用于声明游戏创建函数、初始化函数和资源路径。资源路径用于加载 res 目录中的图片、字体和音效文件：

#embed-code("snippets/mywhackmole_h.c")

*（2）核心变量与对象。* `MyWhackMole.c` 是程序核心文件，定义游戏屏幕对象、九个地鼠对象、分数标签、时间标签、锤子光标、分数、游戏时间、游戏计时器和地鼠刷新定时器等。地鼠洞和地鼠对象按 3×3 布局显示，位置由坐标数组 `hole_positions` 决定：

#code-block[
#raw(block: true, lang: "c", "static lv_obj_t *game_screen;\nstatic lv_obj_t *moles[9];\nstatic lv_obj_t *score_label;\nstatic lv_obj_t *time_label;\nstatic lv_obj_t *hammer;\nstatic lv_timer_t *game_timer;\nstatic lv_timer_t *mole_timer;\nstatic int score;\nstatic int game_time;")
]

*（3）init_whack_a_mole_game* 用于创建主界面，包括背景、标题、分数、倒计时、九个地鼠洞、九个地鼠对象、开始按钮和锤子光标等元素。

*（4）start_game* 用于开始或重新开始游戏：清零得分、重置游戏时间为 30 秒、隐藏全部地鼠，并创建游戏计时器与地鼠刷新定时器。默认地鼠定时器周期为 1000 ms。

*（5）update_game_timer* 每秒更新倒计时；当 `game_time` 减到 0 时，删除定时器、隐藏全部地鼠，并弹出 Game over 提示框。

*（6）pop_random_mole* 每次刷新先隐藏所有地鼠，再随机显示一至两只地鼠。该函数是控制游戏难度的重要位置，地鼠出现速度、出现数量和显示时间都会影响难度。

*（7）mole_click_event* 处理地鼠点击：若被点击地鼠当前未隐藏，则加分、隐藏地鼠，并触发击中特效、音效和 LED 闪烁等进阶功能。

*（8）app_create 入口。* `app_create` 在 MyWhackMole_main.c 中被调用，负责完成 LVGL 与 NuttX 显示/输入设备的衔接，并调用 `init_whack_a_mole_game` 搭建界面。相比直接运行 lvgldemo 演示，独立应用的好处是：可单独配置栈大小、资源路径与 Kconfig 开关，且 PROGNAME 与业务名称一致，便于课程验收与后续 SmartMole Pro 集成。

*（9）定时器协作关系。* `game_timer` 与 `mole_timer` 相互独立：`game_timer` 控制全局倒计时与 Game Over；`mole_timer` 控制地鼠刷新节奏。游戏结束时必须同时删除两个定时器并隐藏全部地鼠，否则会出现「时间已到但地鼠仍弹出」的状态不一致。阅读代码时应把「状态机」与「定时器生命周期」放在一起理解。

*（10）资源加载路径。* 头文件中 `RES_ROOT`、`ICONS_ROOT`、`FONTS_ROOT` 与 `HIT_WAV` 均基于 Kconfig 的 `CONFIG_EXAMPLES_MYWHACKMOLE_DATA_ROOT`，默认 `/data/res`。LVGL 通过文件系统接口加载 PNG 与字体；若路径错误或镜像未打包，界面会显示占位或空白，但程序不一定崩溃——这是嵌入式 UI 调试的常见陷阱。

== 4.7 存放 res 资源并配置编译选项

将 res.rar 解压，得到包含游戏图片、字体和 hit.wav 的 res 文件夹。放入开发板数据分区目录：

`/home/ubuntu/vela-opensource/vendor/allwinnertech/lichee/board/common/data/UDISK/res`

烧录后可通过 `/data/res` 访问，hit.wav 运行路径为 `/data/res/hit.wav`。

#lab-img("实验2 基础实验/微信图片_20260618001357_1758_16.png", [图 4-37 UDISK 目录下的 res 资源])

*图 4-37：* `lichee/board/common/data/UDISK/res` 下含 PNG 地鼠图、字体与 `hit.wav`，pack 后映射为板端 `/data/res`。

清除旧配置后重新进入 menuconfig，搜索 MYWHACKMOLE，选中 WHACKMOLE Demo，并确认栈大小 327680、触摸屏路径 `/dev/input0`、资源路径 `/data/res`：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource
./build.sh vendor/allwinnertech/boards/r528/r528s3-velaevb1/configs/nsh/ distclean
./build.sh vendor/allwinnertech/boards/r528/r528s3-velaevb1/configs/nsh/ menuconfig")
]

#lab-img("实验2 基础实验/微信图片_20260618001357_1759_16.png", [图 4-38 menuconfig 启用 WHACKMOLE Demo])

*图 4-38：* 已勾选 WHACKMOLE Demo，栈 327680、触摸 `/dev/input0`、资源 `/data/res` 与 Kconfig 一致。

若资源未打进镜像，游戏界面会缺图或音效无声，但程序仍可启动——这是区分「路径错误」与「逻辑错误」的典型症状。

*menuconfig 与 distclean：* 新增应用后若 `m` 未出现 MyWhackMole，常因旧 `.config` 缓存。执行 `distclean` 再 `menuconfig` 可强制重新生成配置树。确认项包括：`[*] WHACKMOLE Demo`、`Stack size (327680)`、`Touchscreen device path (/dev/input0)`、`Resource root path (/data/res)`。保存后 `m && pack`，避免只编译未打包导致 UDISK 资源未更新。

== 4.8 编译、打包、烧录并运行基础游戏

完成 MyWhackMole 程序和资源配置后，回到 lichee 目录重新编译、打包：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/
m
pack")
]

烧录完成后，MobaXterm 连接串口，在 nsh 提示符下执行：

#code-block[
#raw(block: true, lang: "text", "nsh> mywhackmole")
]

程序正常运行后，LCD 显示 WhackMole 游戏界面，包括地鼠洞、地鼠、分数、倒计时和开始按钮。点击开始后地鼠随机出现和隐藏；点击可见地鼠后分数增加；倒计时结束显示游戏结束提示。

*运行现象说明：* 游戏启动后先显示准备界面，可通过屏幕 START 或进阶功能中的 K1 开始。`game_timer` 每秒递减并在标签刷新；`pop_random_mole` 按周期隐藏全部地鼠再随机显示。击中时地鼠立即隐藏以防重复计分。Game Over 后定时器销毁，需再次 START 或按 K1 才能新开一局。若触摸无响应，应回溯 4.3、4.4 节触摸配置；若图片缺失，检查 UDISK 打包与 `/data/res` 路径。

#lab-img("实验2 基础实验/微信图片_20260618001357_1760_16.png", [图 4-39 游戏主界面与 START 按钮])

*图 4-39：* `nsh> mywhackmole` 后显示横屏游戏主界面、九个地鼠洞与 START 按钮，资源加载正常。

#lab-img("实验2 基础实验/微信图片_20260618001357_1761_16.png", [图 4-40 游戏中地鼠出现与计分])

*图 4-40：* 点击 START 后地鼠随机出现，分数与时间标签刷新。

#lab-img("实验2 基础实验/微信图片_20260618001357_1762_16.png", [图 4-41 击中地鼠后分数变化])

*图 4-41：* 击中可见地鼠后 score 增加，地鼠隐藏，符合 `mole_click_event` 逻辑。

#lab-img("实验2 基础实验/微信图片_20260618001357_1763_16.png", [图 4-42 倒计时结束 Game Over])

*图 4-42：* 倒计时归零弹出 Game Over，定时器销毁，需再次 START 或按 K1 重开一局。


== 4.9 阅读代码并分析游戏难度调整方法

通过阅读 MyWhackMole.c 可以看出，本游戏难度并非由单一变量决定，而是由游戏总时长、地鼠刷新速度、每次出现数量、地鼠显示时间、位置分布、点击区域大小以及计分方式等多个因素共同决定。通过修改这些参数，可以比较方便地调整游戏整体难度和节奏。

=== 4.9.1 修改游戏总时长

游戏总时间主要由 `GAME_TIME` 宏定义控制，默认 30 秒：

#code-block[
#raw(block: true, lang: "c", "#define GAME_TIME 30\nstatic int game_time = GAME_TIME;")
]

`GAME_TIME` 表示一局游戏持续的总时间。若改小为 20，玩家需在更短时间内得分，节奏更紧张、难度提高；若改大为 60，操作空间更大、难度降低。`GAME_TIME` 主要影响一局游戏的节奏压力：时间越短玩家越容易紧张，时间越长操作空间越大。修改后需同步检查 `start_game` 中 `game_time` 的初值赋值是否与宏一致。

=== 4.9.2 修改地鼠刷新速度

地鼠出现速度主要由 `mole_timer` 定时器控制。在 `start_game` 中创建地鼠刷新定时器：

#code-block[
#raw(block: true, lang: "c", "mole_timer = lv_timer_create(pop_random_mole, 1000, NULL);")
]

周期 1000 表示每 1000 ms 调用一次 `pop_random_mole`，即每隔 1 秒刷新地鼠。若改为 700，刷新变快、难度提高；若改为 1500，玩家反应时间更充裕、难度降低。

在 `pop_random_mole` 中还根据剩余时间动态调整周期：

#code-block[
#raw(block: true, lang: "c", "if (game_time < 40) {\n    lv_timer_set_period(timer, 800);\n}\nif (game_time < 20) {\n    lv_timer_set_period(timer, 600);\n}")
]

由于初始游戏时间为 30 秒，开始后刷新周期会变为 800 ms，后半段进一步加速，使难度逐渐增加而非从头到尾保持同样节奏。这种「渐进加速」比固定周期更能维持玩家紧张感。

=== 4.9.3 修改地鼠一次出现的数量

在 `pop_random_mole` 中，程序先隐藏所有地鼠，再随机显示一部分：

#code-block[
#raw(block: true, lang: "c", "for (int i = 0; i < 9; i++) {\n    lv_obj_add_flag(moles[i], LV_OBJ_FLAG_HIDDEN);\n}\nint show_count = rand() % 2 + 1;")
]

`show_count` 取值范围为 1 到 2，即每次刷新随机出现 1 只或 2 只地鼠。若希望更简单，可改为 `rand() % 3 + 1`，一次可能出现 1 到 3 只，玩家更容易点中；若希望更难，可让每次只出现 1 只或降低出现概率，需要更集中注意力。同屏地鼠数量与刷新周期叠加时，对难度影响呈非线性增长。

=== 4.9.4 修改地鼠显示持续时间

地鼠显示持续时间与 `mole_timer` 刷新周期有关。每次执行 `pop_random_mole` 时都会先隐藏全部地鼠再随机显示新地鼠，因此地鼠大约显示到下一次刷新为止。若周期为 1000 ms，地鼠大约显示 1 秒；若改为 600 ms，显示时间明显变短，玩家必须更快点击。想降低难度可延长显示时间，想提高难度可缩短显示时间。

从玩家体验角度，显示持续时间等于「有效反应窗口」。窗口过短会导致误触率上升、挫败感增强；窗口过长则节奏拖沓。与 4.9.2 的刷新周期联动调节时，建议先固定 `GAME_TIME`，只改 mole_timer 周期，观察 30 秒内的平均得分变化，再决定是否调整同屏数量。

=== 4.9.5 修改地鼠位置分布

地鼠洞位置由 `hole_positions` 数组控制：

#code-block[
#raw(block: true, lang: "c", "static hole_pos_t hole_positions[9] = {\n    { 92, 82 }, { 225, 82 }, { 363, 82 },\n    { 69, 149 }, { 225, 149 }, { 363, 149 },\n    { 69, 219 }, { 225, 219 }, { 382, 219 }\n};")
]

九组坐标决定 3×3 布局在 480×320 横屏上的位置。若地鼠洞距离较近，手指移动距离短、操作更轻松；若分布更分散，需在屏幕不同区域快速切换，难度提高。可通过调整坐标把洞口放得更分散或更靠近边缘，以增加点击难度。中心洞与四角洞对玩家拇指可达性的影响不同，实际调参时建议实机体验。

=== 4.9.6 修改地鼠大小和点击区域

每个地鼠洞大小通过 `lv_obj_set_size(hole, 80, 60)` 设置，地鼠图片创建在 hole 对象中。调大洞口或图片，玩家更容易点中、难度降低；调小则命中区域变小、需要点得更准。代码中还通过 `lv_obj_set_style_transform_scale` 设置缩放（默认 200），也会影响显示大小与操作难度。

LVGL 的点击命中以对象包围盒为准，而非透明像素。地鼠 PNG 若四周透明较多，视觉上较小但命中区仍可能较大；缩小 hole 对象可同时缩小命中区。横屏 480×320 下，洞口 80×60 约占单格宽度六分之一，对拇指操作较为友好；若改为 60×45，难度会明显上升。

=== 4.9.7 修改计分规则

当前击中逻辑如下：

#code-block[
#raw(block: true, lang: "c", "if (!lv_obj_has_flag(mole, LV_OBJ_FLAG_HIDDEN)) {\n    score++;\n    lv_label_set_text_fmt(score_label, \"score: %d\", score);\n    lv_obj_add_flag(mole, LV_OBJ_FLAG_HIDDEN);\n}")
]

每打中一只地鼠加 1 分，适合基础实验。若希望更有挑战性，可增加：连续命中多次额外加分；点击空白或误点隐藏地鼠时扣分；剩余时间越少击中得分越高；不同地鼠设置不同分值。这样游戏策略性更强，不只是简单点击。

=== 4.9.8 修改地鼠出现的随机性

代码使用 `rand() % 9` 随机选择地鼠出现位置，地鼠在九个位置中随机出现。若想更难，可避免连续出现在相近位置，或让其更容易出现在不易点击的位置；若想更简单，可让地鼠更均匀出现，避免长时间不出现在某些位置。随机性影响玩家预判：太规律则变简单，完全随机且刷新很快则更紧张。

进阶改法可维护「上次出现位置」变量，若新随机位置与上次相邻则重新抽取；或引入权重数组，让边角洞口概率更低。随机数种子通常在系统启动时确定，多次开局分布应足够均匀；若发现「总是同一洞」，需检查是否在游戏循环中误调 `srand` 或定时器周期过短导致肉眼错觉。

=== 4.9.9 综合调整方法

*降低难度*：将 `GAME_TIME` 调大（如 30 改为 60）；将 mole_timer 周期调大（如 1000 ms 改为 1500 ms）；增加每次出现地鼠数量；增大洞口或地鼠点击区域；取消误触扣分，只保留命中加分。

*提高难度*：将 `GAME_TIME` 调小（如 30 改为 20）；将 mole_timer 周期调小（如 600 ms）；减少每次出现数量；缩小地鼠尺寸或点击范围；让位置更分散；加入误触扣分或连续命中奖励。

总体来看，难度可从时间、速度、数量、位置、大小和计分方式等多方面调整。最直接的是修改 `GAME_TIME`、mole_timer 周期以及 `show_count` 取值范围，改动小但对节奏影响明显，可把游戏调成简单、普通或困难等不同档位。

*实验建议：* 课堂演示可选用「简单档」（GAME_TIME=60、mole 周期 1500 ms、show_count 1～3）保证可玩性；答辩展示可选用「困难档」突出动态加速与单鼠模式。调参时每次只改一个变量并记录 30 秒内得分，避免多变量同时变化导致无法归因——这也是软件实验中控制变量的基本方法。

上述九个小节覆盖了示例文档中的全部难度分析要点，并补充了与 LVGL 对象模型、定时器周期及随机策略相关的实现细节，可作为 SmartMole Pro 关卡难度配置的参考文档。

= 五、进阶功能实现

在基础游戏可稳定运行后，按课程要求依次叠加四项进阶反馈：视觉特效、音效、LED 闪烁、K1 开始。四项功能均参考 openvela 手册 3.3 的音乐任务与 LED 任务，迁移到「击中地鼠」这一业务场景；实现时遵循「UI 线程只做轻量操作，耗时 IO 放任务或短延时 GPIO」的原则。

== 5.1 击中地鼠时的视觉特效

为让击中反馈更明显，在 `mole_click_event` 判断地鼠可见并加分后，添加半透明方框作为击中特效。思路是创建临时 lv_obj 方框，设置半透明背景、边框和圆角，定位到被击中地鼠附近；再创建约 200 ms 的短定时器删除该对象。相关代码如下：

#embed-code("snippets/hit_effect.c")

在 `mole_click_event` 中击中地鼠后调用 `show_hit_effect(mole)`，仅真正击中时才出现特效。完整调用链为：判断可见 → 加分 → 特效 → 音效 → LED → 隐藏地鼠。各反馈模块彼此独立，便于单独开关调试。

#lab-img("实验2 基础实验/微信图片_20260618001357_1764_16.png", [图 5-1 show_hit_effect 源码片段])

*图 5-1：* `show_hit_effect` 创建半透明方框并设 200 ms 定时器删除，仅击中时调用。

#lab-img("实验2 基础实验/微信图片_20260618001359_1765_16.png", [图 5-2 击中瞬间半透明方框（特写 1）])

*图 5-2：* 击中地鼠瞬间，洞口附近出现半透明高亮方框。

#lab-img("实验2 基础实验/微信图片_20260618001359_1766_16.png", [图 5-3 击中瞬间半透明方框（特写 2）])

*图 5-3：* 另一帧击中特效，方框位置随被点地鼠移动。

#lab-img("实验2 基础实验/微信图片_20260618001359_1767_16.png", [图 5-4 特效与得分同时更新])

*图 5-4：* 特效显示的同时分数标签已更新，视觉与计分反馈同步。

红框圈起的透明方块即为预期生成的打中地鼠特效。

== 5.2 击中地鼠时播放 hit.wav 音效

击中音效参考开发板手册 3.3 音乐任务：通过创建播放任务调用 aplay 播放音频。本实验在击中时播放 res 下的 hit.wav，烧录后通过 `/data/res/hit.wav` 访问。封装 `play_hit_sound`，用 `task_create` 调用 `aplay_main`，避免在触摸回调中长时间阻塞 LVGL：

#embed-code("snippets/play_hit_sound.c")

在 `mole_click_event` 中击中后调用 `play_hit_sound()` 即可。

#lab-img("实验2 基础实验/微信图片_20260618001400_1768_16.png", [图 5-5 play_hit_sound 与 task_create])

*图 5-5：* 源码中 `play_hit_sound` 通过 `task_create` 拉起 aplay 任务，参数指向 `/data/res/hit.wav`。

#lab-img("实验2 基础实验/微信图片_20260618001400_1769_16.png", [图 5-6 串口 play hit sound 日志])

*图 5-6：* 击中时串口打印 play hit sound 或 aplay 相关日志，证明任务已创建。

#lab-img("实验2 基础实验/微信图片_20260618001400_1770_16.png", [图 5-7 击中时可听见的音效反馈])

*图 5-7：* 实机击中地鼠时可听见 hit.wav 短促音效，与视觉特效叠加。

击中时串口输出 play hit sound 相关日志，并可听见 hit.wav 音效。

*音效任务设计：* `task_create` 创建优先级 100、栈 81920 字节的短生命周期任务，入口为 `aplay_main`，与 NSH 下手动执行 aplay 相同。在 `mole_click_event` 中直接调用 aplay 会阻塞触摸处理，导致连击时界面卡顿；独立任务将音频 IO 与 LVGL 解耦。若 hit.wav 路径错误，任务仍会创建但串口可能打印 open failed，需对照 `/data/res/hit.wav` 是否存在。

== 5.3 击中地鼠时 LED1 闪烁

LED1 闪烁参考手册 3.3 LED 任务：通过 open 打开 GPIO 设备节点，ioctl 设置类型与电平。系统中存在 gpio0、gpio1 等设备节点；SDK 中 `drv_gpio.c` 映射已包含 LED1 与 K1，无需额外改驱动。映射关系如下：

#table(
  columns: (2.2cm, 3.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*索引*], [*引脚*], [*功能*]),
  [0], [GPIOD(21)], [LED1 输出],
  [1], [GPIOD(7)], [KEY1（K1）输入下拉],
  [2], [GPIOD(22)], [LED2 输出],
  [3], [GPIOD(8)], [KEY2 输入下拉],
  [4], [GPIOD(9)], [KEY3 输入下拉],
  [5], [GPIOG(12)], [WL_REG_ON 输出],
)

`/dev/gpio0` 对应 LED1，`/dev/gpio1` 对应 K1。封装 `flash_led1`：击中后点亮 LED1，延时约 150 ms 再熄灭。若亮灭逻辑相反，交换 GPIOC_WRITE 中的 0 和 1 即可：

#embed-code("snippets/flash_led1.c")

#lab-img("实验2 基础实验/微信图片_20260618001400_1771_16.png", [图 5-8 flash_led1 GPIO 操作代码])

*图 5-8：* `flash_led1` 打开 `/dev/gpio0`，写电平点亮约 150 ms 后熄灭。

#lab-img("实验2 基础实验/微信图片_20260618001400_1772_16.png", [图 5-9 串口 flash LED1 日志])

*图 5-9：* 击中时串口输出 flash LED1 类日志，与 GPIO 操作对应。

#lab-img("实验2 基础实验/微信图片_20260618001400_1773_16.png", [图 5-10 击中时板载 LED1 可见闪烁])

*图 5-10：* 板载 LED1 在击中瞬间可见闪烁（低电平点亮），与音效、特效同步。

串口打印 flash LED1 日志，板载 LED1 在打中地鼠时会闪烁。

*GPIO 操作要点：* `GPIOC_SETPINTYPE` 将引脚设为输出；`GPIOC_WRITE` 写电平。不同硬件 LED 可能是低电平点亮或高电平点亮，本实验以肉眼可见闪烁为准。`flash_led1` 在击中回调中执行，耗时约 150 ms 加 open/ioctl 开销；若连击频繁，可考虑改为非阻塞闪烁任务，与音效任务类似，进一步减轻 UI 线程压力。

== 5.4 按下 K1 键开始游戏

按下 K1 开始游戏参考 LED 任务中的按键读取逻辑：`/dev/gpio1` 对应 KEY1。打开设备后通过 GPIOC_READ 读取电平，检测到 K1 按下时调用 `start_game`。由于 `start_game` 会修改 LVGL 界面对象，而 K1 检测在线程中运行，调用时应加 LVGL 锁，避免与界面刷新同时操作 LVGL 对象：

#embed-code("snippets/key_thread.c")

在 `app_create` 或 `init_whack_a_mole_game` 完成界面初始化后，用 `pthread_create` 创建 key_thread。屏幕上的 START 按钮仍可作为触摸备用入口。若按下时读到 0，将判断条件改为 `key_value == false`；本 SDK 中 KEY1 为下拉输入，默认按下按高电平触发。

#lab-img("实验2 基础实验/微信图片_20260618001400_1774_16.png", [图 5-11 key_thread 源码与 pthread 创建])

*图 5-11：* `key_thread` 轮询 `/dev/gpio1`，`pthread_create` 在后台运行；调用 `start_game` 前加 `lvgl_lock`。

#lab-img("实验2 基础实验/微信图片_20260618001400_1775_16.png", [图 5-12 串口 K1 pressed, start game])

*图 5-12：* 按下 K1 后串口打印 K1 pressed, start game，与触摸 START 等效。

#lab-img("实验2 基础实验/微信图片_20260618001400_1776_16.png", [图 5-13 按 K1 后游戏立即开始])

*图 5-13：* 游戏计时与地鼠刷新立即启动，无需再点屏幕 START。

#lab-img("实验2 基础实验/微信图片_20260618001400_1777_16.png", [图 5-14 进阶功能全部就绪后的完整游戏画面])

*图 5-14：* 特效、音效、LED、K1 四项进阶均启用后的完整游戏界面。

#lab-img("实验2 基础实验/微信图片_20260618001400_1778_16.png", [图 5-15 实验总结性联调截图])

*图 5-15：* 联调总结截图：横屏游戏可玩，击中具备视听灯与按键反馈，满足课程全部要求。

按板子 K1 时，串口先输出 K1 key thread started，再输出 K1 pressed, start game，游戏立即开始，完全满足要求。

*线程安全说明：* LVGL 多数 API 非线程安全，必须在持有 `lvgl_lock` 时修改对象树。`key_thread` 以约 20 ms 周期轮询 GPIO，检测到按下后加锁调用 `start_game`，再 `usleep(300ms)` 消抖。若省略锁，可能出现标签文字与定时器状态不一致甚至硬 fault。START 按钮走 LVGL 事件回调，本身在 LVGL 线程上下文，无需额外加锁。两种开始方式并存，方便对比「触摸开始」与「物理按键开始」的用户体验。

= 六、关键源码、烧录流程与排错记录

== 6.1 RGB565 字节交换与 updatearea（驱动层）

#embed-code("snippets/sw_rgb565_swap.c")

#embed-code("snippets/spi_lcd_updatearea.c")

*bug：花屏、红蓝互换。* 原因：SPI 发送顺序与 Framebuffer 字节序相反。改法：每行 `memcpy` 后调用 `sw_rgb565_swap` 再 `SPI_SNDBLOCK`。

== 6.2 横屏触摸坐标修正

#embed-code("snippets/ft5x06_landscape.c")

配合 `LCD_WritePara(0xe8)`、列行地址 0xdf/0x3f 对调、`xres=480 yres=320`，以及 menuconfig 启用 `FT5X06_SWAPXY`。

== 6.3 MyWhackMole 工程入口与击中回调

`MyWhackMole_main.c` 屏蔽 `lv_demos_create`，改调 `app_create()`：

#embed-code("snippets/mywhackmole_main.c")

`mole_click_event` 完整调用链（计分 + 三项进阶）：

#embed-code("snippets/mole_click_event.c")

进阶音效与 LED 独立实现：

#embed-code("snippets/play_hit_sound.c")

#embed-code("snippets/flash_led1.c")

#embed-code("snippets/key_thread.c")

Kconfig 栈与资源路径（须 menuconfig 确认 327680、`/dev/input0`、`/data/res`）：

#embed-code("snippets/mywhackmole_kconfig", lang: "kconfig")

== 6.4 编译、打包、烧录与运行

#embed-code("snippets/burn_procedure.sh", lang: "bash")

烧录后在 `nsh>` 执行 `mywhackmole`（不是 `lvgldemo`）。`res` 目录须放在 `lichee/board/common/data/UDISK/res`，pack 后映射为 `/data/res/hit.wav`。

== 6.5 我遇到的问题与修改方法

#table(
  columns: (3cm, 3cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*现象*], [*原因*], [*修改*]),
  [help 无 fb/ft5x06], [测试程序未编入], [m menuconfig 启用后 m pack],
  [花屏色偏], [未做 RGB565 交换], [spi\_lcd\_fb.c 加 sw\_rgb565\_swap],
  [触摸无响应], [轮询漏触], [关 FT5X06\_POLLMOD；开 LVGL 触摸],
  [横屏点偏], [坐标未映射], [ft5x06 改 480-Y；开 SWAPXY],
  [mywhackmole 找不到], [未进 CONFIGURED\_APPS], [Kconfig+Make.defs+menuconfig],
  [图片空白], [res 未打进 usrdata], [UDISK/res 后 distclean menuconfig pack],
  [击中无声], [路径或音量], [ls /data/res；amixer；play\_hit\_sound 路径],
  [K1 无反应], [极性反了], [改 key\_value 判断；确认 /dev/gpio1],
  [LVGL 卡死], [回调里阻塞 aplay], [改 task\_create 播放；K1 加 lvgl\_lock],
)

= 七、实验结果汇总

#table(
  columns: (3.5cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*任务*], [*完成*], [*说明*]),
  [外设自检 fb/触摸/音频], [✓], [4.1 节全部通过，moon.wav 可播],
  [RGB565 字节交换], [✓], [lvgldemo 显示正常，无严重色偏],
  [触摸中断 + LVGL 输入], [✓], [点击 Wi-Fi 图标响应正确],
  [横屏 480×320], [✓], [串口 xres/yres 与触摸一致],
  [MyWhackMole 集成], [✓], [mywhackmole 命令可运行],
  [res 资源打包], [✓], [/data/res 下图标字体与 hit.wav 可访问],
  [难度分析], [✓], [九项参数关系已梳理],
  [击中视觉特效], [✓], [200 ms 半透明方框],
  [hit.wav 音效], [✓], [task_create + aplay 非阻塞],
  [LED1 闪烁], [✓], [GPIO0 点亮约 150 ms],
  [K1 开始游戏], [✓], [key_thread + lvgl_lock],
)

*常见故障与排查：*

#table(
  columns: (3.2cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*现象*], [*可能原因与处理*]),
  [花屏/色偏], [检查 spi_lcd_fb.c 是否每行调用 sw_rgb565_swap],
  [触摸无响应], [确认 FT5X06_POLLMOD 已关、LV_USE_NUTTX_TOUCHSCREEN 已开],
  [点偏/坐标反], [横屏后检查 SWAPXY 与 480 减 Y 公式],
  [mywhackmole 未找到], [menuconfig 启用 MYWHACKMOLE 并重新 m pack],
  [图片不显示], [确认 res 在 UDISK 且 CONFIG 路径为 /data/res],
  [击中无声], [串口 ls /data/res 检查 hit.wav；amixer 音量],
  [K1 无反应], [确认 /dev/gpio1；调整 key_value 判断极性],
)

= 八、实验总结

本次实验从驱动修改、应用创建、资源打包、编译烧录到开发板运行验证，完整实现了基于 LVGL 的 WhackMole 游戏。相比初探实验，本实验不只是验证任务和线程，而是把 LCD 显示、触摸屏、LVGL 界面、音频、GPIO 和按键等内容结合在一起，更接近一个完整的嵌入式交互应用。

在基础任务部分，我完成了 LCD 显示和触摸屏相关配置，使屏幕能够横屏显示，并且触摸坐标能够正常对应游戏界面。随后在示例工程基础上创建 MyWhackMole 应用，完成 Kconfig、Make.defs、Makefile 和 CMakeLists.txt 等文件配置，并编写 MyWhackMole_main.c、MyWhackMole.h 和 MyWhackMole.c，最终成功在开发板上运行打地鼠游戏。过程中我体会到：花屏往往来自 RGB565 字节序而非 LVGL 逻辑；点偏来自触摸坐标未随横屏变换；无声可能因 `/data/res` 未打进镜像而非 aplay 命令本身错误。

在阅读代码和调试过程中，我理解了游戏难度主要由 game_time、mole_timer 刷新周期、地鼠一次出现数量、地鼠大小和位置、得分规则等因素决定。通过调整这些参数，可以改变游戏节奏和玩家反应压力，也让我对 LVGL 定时器和事件回调的使用更加熟悉。`GAME_TIME`、刷新周期与 `show_count` 是改动成本最低、效果最明显的三个旋钮。

在进阶任务部分，我给击中地鼠添加了半透明方框特效，让命中反馈更加明显；同时参考 openvela 手册中的音乐任务和 LED 任务，实现了击中时播放 hit.wav 音效、LED1 闪烁以及按下 K1 开始游戏。这样游戏不只是在屏幕上显示，还加入了声音、灯光和物理按键反馈，交互效果更加完整。音效与 LED 均放在独立任务或短操作中执行，避免阻塞 LVGL 主线程，这与初探实验中学到的「耗时操作勿占 UI 线程」一脉相承。

通过这次实验，我认识到嵌入式图形程序并不是只写界面代码，还要同时考虑驱动配置、资源路径、构建系统、文件系统、设备节点和多任务配合。后续如果继续完善，可以进一步优化音效和 LED 触发方式，减少阻塞和轮询，也可以加入难度选择、排行榜或更多动画效果，为 SmartMole Pro 课程项目提供可复用的驱动与应用模板。

*个人收获归纳：* （1）驱动层：RGB565 字节序、横屏 MADCTL、触摸 SWAPXY 三类修改可复用到其他 LVGL 项目；（2）应用层：Kconfig + Makefile 三件套是 openvela 应用上架的固定流程；（3）交互层：定时器驱动游戏节奏，事件回调处理输入，任务/线程承载音效与 GPIO；（4）调试层：先外设自检、再 lvgldemo、最后 mywhackmole 的分层验证法显著缩短排错时间。本实验报告全部 57 张截图按操作顺序穿插，与正文步骤一一对应，便于复查与答辩展示。
