#!/usr/bin/env python3
"""Generate lab *.typ files with all PNG images embedded."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DOCS = ROOT.parent


def imgs(folder: str) -> list[Path]:
    d = ROOT / folder
    return sorted(d.glob("微信图片_*.png"), key=lambda p: p.name)


def rel(p: Path) -> str:
    """Path relative to docs/labs/ (typ source directory)."""
    return str(p.relative_to(ROOT)).replace("\\", "/")


def esc_raw(s: str) -> str:
    """Escape # for typst raw strings inside code-block."""
    return s.replace("#", "\\#")


def lab_img(p: Path, caption: str) -> str:
    return f'#lab-img("{rel(p)}", [{caption}])'


def chunk(lst, sizes):
    out, i = [], 0
    for s in sizes:
        out.append(lst[i : i + s])
        i += s
    if i < len(lst):
        out.append(lst[i:])
    return out


def write(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    print(f"wrote {path.name} ({len(content)} chars)")


# ── 实验1：初探实验（3.2 任务与线程）────────────────────────────
e1 = imgs("实验1 初探实验")
s1 = chunk(e1, [2, 7, 9, 6, 6, 4])  # env / hello / pthread / fifo / rr / ps+rcS

exp1 = r'''// 实验报告 · 3.2 任务与线程上机实验（初探实验）
// 编译: cd docs/labs && .\compile.ps1

#import "lab-common.typ": *

#set document(
  title: "3.2 任务与线程上机实验报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init

#lab-cover(
  exp-no: "3.2",
  exp-title: "任务与线程上机实验",
)

#front-matter[
  #abstract-block(
    [本报告完整记录 openvela 初探实验中第 3.2 节「任务与线程」的上机过程。实验从 hello 示例的配置编译入手，逐步过渡到 pthread 双线程共享变量、FIFO 固定优先级调度下的线程饿死现象，以及启用 RR 时间片轮转后的多线程交替运行；最后通过 `ps` 与 `/proc` 接口观察任务堆栈与调度策略，并在 `rcS` 中配置开机自启动。],
    keywords: [openvela；NuttX；pthread；FIFO；RR 调度；任务与线程],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

初探实验聚焦 openvela 多任务系统的基本机制，通过五项递进式上机练习建立对 Task、Thread 与调度策略的直观认识：

+ *hello 程序配置与运行*：掌握 menuconfig 启用示例应用、交叉编译、镜像打包烧录及 NSH 命令行运行的完整流程；
+ *pthread 双线程实验*：使用 `pthread_create` 创建累加线程与打印线程，观察同 Task 内全局变量 `g_a` 的共享与并发访问；
+ *FIFO 调度体验*：将多个线程设为最高优先级并去掉 `sleep`，在双核 T113S3 上观察低优先级线程与 shell 被饿死的现象；
+ *RR 时间片轮转*：配置 `CONFIG_RR_INTERVAL=1`，对比相同优先级线程按时间片轮流占用 CPU 的行为差异；
+ *任务信息查看与自启动*：使用 `ps`、`/proc/<pid>` 查看调度策略与堆栈占用，并修改 `rcS` 实现 `hello` 后台自启动。

= 二、实验环境

#table(
  columns: (2.8cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [实验平台], [DshanPI openvela Devkit（T113S3，双核 Cortex-A7）],
  [主机系统], [Windows 11],
  [虚拟机], [VMware + Ubuntu 22.04],
  [源码目录], [`~/vela-opensource/`],
  [开发工具], [VS Code 远程 SSH 连接 Ubuntu，浏览与编辑 NuttX 源码],
  [编译环境], [`lichee/` 下 `source vela_env.sh`、`source envsetup.sh`、`lunch_nuttx`、`m`、`pack`],
  [烧录工具], [PhoenixSuit，镜像 `rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img`],
  [串口工具], [MobaXterm，Serial 模式，波特率 1500000，Flow Control: none],
  [主要源码], [`apps/examples/hello/hello_main.c`],
  [参考手册], [《openvela 快速入门与工程实践》§3.2],
)

= 三、实验原理

openvela 基于 NuttX RTOS，Task 在资源隔离意义上类似 Linux 进程，而 pthread 线程是 CPU 调度的基本单元。同一 Task 内的多个线程共享地址空间、文件描述符与全局变量，因此 `hello_main.c` 中的 `g_a` 可被 `add_thread` 与 `print_thread` 同时访问。

调度方面，当 `CONFIG_RR_INTERVAL=0` 时，相同优先级线程采用 FIFO 策略：先运行的线程若不主动让出 CPU（如 `sleep`、`pthread_yield`），将一直占用处理器。T113S3 仅有 2 个 CPU 核，当 3 个高优先级线程均进入忙等循环时，必然有一个线程无法获得执行机会，NSH shell 也可能因优先级较低而无法响应输入。

将 `CONFIG_RR_INTERVAL` 设为 1 后，系统在每个 tick 中断检查时间片，相同优先级线程将轮流运行，从而避免长期饿死。通过 `ps -heap` 与 `/proc/<pid>/status` 可查看任务的调度策略（`SCHED_FIFO` / `SCHED_RR`）、优先级及堆栈使用量。

= 四、实验内容与操作步骤

== 4.1 开发环境准备与串口连接

在 Windows 主机通过 VS Code Remote-SSH 连接 Ubuntu 虚拟机，打开 `~/vela-opensource/` 工程，确认 `apps`、`nuttx`、`vendor` 等顶层目录可见。串口调试使用 MobaXterm 选择开发板对应的 COM 口（如 COM5，USB-Enhanced-SERIAL CH343），波特率 1500000。

#step[+ 进入 lichee 目录并加载编译环境：]
#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/\\nsource vela_env.sh\\nsource envsetup.sh\\nlunch_nuttx   \\# 选择 2 → r528s3-velaevb1")
]

'''

exp1 += "\n".join(lab_img(p, f"图 4-1-{i+1} 开发环境与工程目录") for i, p in enumerate(s1[0]))
exp1 += r'''

== 4.2 实验一：hello 程序配置与运行

通过 menuconfig 搜索并启用 `EXAMPLES_HELLO`，编译打包烧录后在 NSH 中执行 `hello`，应输出 `Hello, World!!`。该步骤验证交叉编译链、镜像生成与串口交互链路均正常。

#step[+ menuconfig 启用 hello（在 nsh 配置目录执行）：]
#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource\\n./build.sh vendor/allwinnertech/boards/r528/r528s3-velaevb1/configs/nsh/ menuconfig\\n\\# 搜索 /HELLO，选中 EXAMPLES_HELLO")
]

#step[+ 编译打包并烧录：]
#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/\\nm && pack")
]

#code-block[
#raw(block: true, lang: "text", "nsh> hello\\nHello, World!!")
]

'''

exp1 += "\n".join(lab_img(p, f"图 4-2-{i+1} hello 程序配置与运行") for i, p in enumerate(s1[1]))
exp1 += r'''

== 4.3 实验二：创建 pthread 双线程（add + print）

将 `hello_main.c` 替换为手册 3.2.2 节代码：创建 `add_thread` 每秒执行 `g_a++`，`print_thread` 每秒打印 `g_a`，主线程每 5 秒打印 `Hello, World!!`。重新编译烧录后，串口应交替出现 `val = N` 与 `Hello, World!!`，且 `g_a` 持续递增，说明三线程并发运行。

核心逻辑如下：

#code-block[
#raw(block: true, lang: "c", "static volatile int g_a;\\n\\nvoid *add_thread(void *arg) {\\n    volatile int *p = (volatile int *)arg;\\n    while (1) { (*p)++; sleep(1); }\\n    return NULL;\\n}\\n\\nvoid *print_thread(void *arg) {\\n    volatile int *p = (volatile int *)arg;\\n    while (1) { printf(\\\"val = %d\\\\n\\\", *p); sleep(1); }\\n    return NULL;\\n}")
]

'''

exp1 += "\n".join(lab_img(p, f"图 4-3-{i+1} pthread 双线程运行输出") for i, p in enumerate(s1[2]))
exp1 += r'''

== 4.4 实验三：FIFO 调度机制体验

使用 `source/3-2-3_FIFO调度机制体验` 目录代码替换 `hello_main.c`：将主线程、`add_thread`、`print_thread` 优先级均设为最高（225），并将 `sleep(1)` 改为空循环忙等 `for (volatile int i = 0; i < 100000000; i++);`。

*预期现象：* 双核 CPU 最多同时运行 2 个线程，主线程与 `add_thread` 可运行（`g_a` 递增），`print_thread` 无法输出 `val =`；NSH 终端无法输入，shell 被饿死。该实验直观展示了 FIFO 调度下高优先级忙等线程对系统的垄断效应。

'''

exp1 += "\n".join(lab_img(p, f"图 4-4-{i+1} FIFO 调度下 shell 无响应") for i, p in enumerate(s1[3]))
exp1 += r'''

== 4.5 实验四：RR 时间片轮转调度

在 menuconfig 中搜索 `RR_INTERVAL`，将 `CONFIG_RR_INTERVAL` 设为 1 并保存。使用 `source/3-2-4_RR调度机制体验` 代码替换 `hello_main.c`，重新 `m && pack` 烧录运行。

*预期现象：* 启用 RR 后，相同优先级线程按时间片轮流运行，`print_thread` 也能输出 `val = N`，NSH 终端恢复可用。对比 FIFO 实验，可清晰理解时间片轮转对公平性的改善。

'''

exp1 += "\n".join(lab_img(p, f"图 4-5-{i+1} RR 调度下多线程交替运行") for i, p in enumerate(s1[4]))
exp1 += r'''

== 4.6 实验五：查看任务信息与 rcS 自启动

运行 hello 程序后（可用 `hello &` 放后台），执行以下命令查看任务状态：

#code-block[
#raw(block: true, lang: "text", "nsh> ps -heap 12\\nnsh> cat /proc/12/status\\nnsh> cat /proc/12/stack\\nnsh> cat /proc/12/heap")
]

观察任务名、调度策略（`SCHED_RR` / `SCHED_FIFO`）、优先级与堆栈使用量。可选地在 `init.d/rcS` 末尾添加 `hello &`，重启后系统自动后台运行 hello，串口持续输出 `Hello, World!! g_a = N` 与 `val = N`。

'''

exp1 += "\n".join(lab_img(p, f"图 4-6-{i+1} ps / proc 任务信息与 rcS 自启动") for i, p in enumerate(s1[5]))
exp1 += r'''

= 五、实验结果与分析

#table(
  columns: (3cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*实验项*], [*结果*], [*现象说明*]),
  [hello 配置运行], [✓], [NSH 执行 hello 输出 Hello, World!!],
  [pthread 双线程], [✓], [`g_a` 递增，`val` 与 Hello 交替打印],
  [FIFO 调度体验], [✓], [2 核仅 2 线程运行，print 线程与 shell 饿死],
  [RR 调度体验], [✓], [时间片轮转后三线程均可运行],
  [/proc 任务查看], [✓], [可查看优先级、调度策略、堆栈占用],
  [rcS 自启动], [✓], [重启后 hello 后台自动运行],
)

*分析与思考：*

+ *Task 与 Thread：* openvela 中 Task 提供资源隔离边界，同 Task 内 pthread 共享全局变量与文件描述符，是多线程协作的基础；
+ *FIFO vs RR：* FIFO 下高优先级线程不主动让出 CPU 将长期占用处理器；RR 通过 tick 中断强制时间片轮转，提升同优先级线程间的公平性；
+ *双核约束：* T113S3 双核最多同时运行 2 个线程，第 3 个高优先级忙等线程必须等待，是理解嵌入式调度容量限制的关键实验现象。

= 六、实验总结

通过初探实验的五项练习，系统掌握了 openvela 下 pthread 创建、优先级配置、FIFO/RR 两种调度策略的实际表现，以及 NSH 任务管理与开机自启动配置。这些多任务基础知识为后续 MyWhackMole 图形游戏与小智语音助手中的音频线程、LED 线程、按键检测线程等多任务协作开发奠定了实践基础。
'''

write(ROOT / "lab32_threads.typ", exp1)

# ── 实验2：基础实验（WhackMole）────────────────────────────────
e2 = imgs("实验2 基础实验")
# 按 示例.txt 章节大致分配 57 张图
s2 = chunk(e2, [3, 15, 3, 4, 7, 6, 2, 4, 4, 3, 3, 3, 3, 3, 3])

exp2_head = r'''// 实验报告 · MyWhackMole 打地鼠游戏实验（基础实验）
// 编译: cd docs/labs && .\compile.ps1

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
    [本报告记录 openvela 平台下基于 LVGL 的 MyWhackMole 打地鼠游戏完整开发过程。实验涵盖 LCD Framebuffer 驱动修改（RGB565 字节交换与横屏适配）、FT5X06 触摸屏中断驱动与坐标映射、游戏应用创建与资源打包、难度参数分析，以及击中视觉特效、hit.wav 音效、LED1 闪烁和 K1 按键开始游戏四项进阶功能。],
    keywords: [MyWhackMole；LVGL；Framebuffer；触摸屏；RGB565；音效；GPIO],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

基础实验围绕 openvela 平台 LVGL 图形界面程序开发展开，通过修改 LCD、触摸屏驱动并运行 MyWhackMole 打地鼠游戏，完成基础图形交互与进阶外设交互功能：

+ 掌握 LCD 显示驱动修改方法，理解 Framebuffer、RGB565 像素格式与横屏显示适配；
+ 掌握触摸屏输入驱动修改，理解触摸坐标上报、中断方式与坐标变换；
+ 掌握 openvela 中 LVGL 应用的配置、编译、打包、烧录与串口运行流程；
+ 使用 LVGL API 实现地鼠随机出现、触摸击中判断、分数与倒计时显示；
+ 分析游戏难度与地鼠间隔、停留时间、游戏时长等因素的关系；
+ 进阶：击中特效、hit.wav 音效、LED1 闪烁、K1 键开始游戏。

= 二、实验环境

#table(
  columns: (2.8cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [实验平台], [DshanPI openvela Devkit（T113S3）],
  [主机 / 虚拟机], [Windows 11 + VMware Ubuntu 22.04],
  [源码目录], [`~/vela-opensource/`],
  [开发工具], [VS Code 远程连接 Ubuntu],
  [编译环境], [`lichee/` 下 vela\_env.sh、envsetup.sh、lunch\_nuttx、m、pack],
  [烧录 / 串口], [PhoenixSuit；MobaXterm 1500000 baud],
  [主要程序], [MyWhackMole（`apps/examples/MyWhackMole/`）],
  [资源文件], [`res/` 图片、字体、hit.wav → `board/common/data/UDISK/res`],
  [外设], [LCD、触摸屏、声卡、LED1、K1],
)

= 三、实验原理

(1) *LVGL 图形库*：面向嵌入式设备的 GUI 库，可创建按钮、标签、图片与动画。本实验用 LVGL 构建游戏背景、地鼠洞、地鼠对象、分数/倒计时标签与开始按钮，通过事件回调和定时器实现点击判断与地鼠随机出现。

(2) *Framebuffer 显示*：LVGL 将界面写入 Framebuffer 后由 LCD 驱动送屏。LCD 原始分辨率 320×480，像素格式 RGB565（16 bit/像素）。SPI 发送存在高低字节顺序问题，需在驱动中交换 RGB565 字节；横屏显示还需修改扫描方向与分辨率配置。

(3) *触摸屏驱动*：FT5X06 将触摸转换为坐标输入。关闭 `FT5X06_POLLMOD` 启用中断方式可提高响应；横屏后需交换 X/Y 并修正坐标，使触摸位置与显示一致。

(4) *游戏逻辑*：定时器控制地鼠随机出现与倒计时；点击回调判断是否击中并更新分数。难度可通过出现间隔、停留时间、同屏数量等参数调节。

(5) *进阶反馈*：击中后通过 LVGL 半透明框实现视觉特效；`task_create` 调用 `aplay` 播放 hit.wav；GPIO 控制 LED1 闪烁；独立线程轮询 K1 触发 `start_game`。

= 四、实验内容与操作步骤

== 4.1 实验准备与基础外设确认

在修改驱动前备份关键文件，加载编译环境，并确认 fb、ft5x06、led、aplay 等基础功能可用。若 `help` 中缺少 fb/ft5x06，需通过 menuconfig 启用后重新编译。

#code-block[
#raw(block: true, lang: "bash", "mkdir -p ~/experiment_backup/whackmole\\ncp nuttx/drivers/video/spi_lcd_fb.c ~/experiment_backup/whackmole/\\ncp nuttx/drivers/input/ft5x06.c ~/experiment_backup/whackmole/\\n\\ncd ~/vela-opensource/vendor/allwinnertech/lichee/\\nsource vela_env.sh && source envsetup.sh && lunch_nuttx")
]

#code-block[
#raw(block: true, lang: "text", "nsh> fb\\nnsh> ft5x06 /dev/input0\\nnsh> led\\nnsh> amixer set 6 180\\nnsh> aplay -D hw:audiocodec /data/moon.wav")
]

'''

exp2 = exp2_head
exp2 += "\n".join(lab_img(p, f"图 4-1-{i+1} 实验准备与外设检测") for i, p in enumerate(s2[0] + s2[1]))
exp2 += r'''

== 4.2 修改 LCD 显示驱动

在 `spi_lcd_fb.c` 中添加 `sw_rgb565_swap` 函数，在 `spi_lcd_updatearea` 发送前对每行像素做高低字节交换，解决 SPI RGB565 顺序问题。编译打包烧录后执行 `lvgldemo`，屏幕应显示白底 LVGL 界面。

#code-block[
#raw(block: true, lang: "c", "static void sw_rgb565_swap(void *buf, uint32_t buf_size_px) {\\n    /* 按 32 位批量交换 RGB565 高低字节 */\\n    ...\\n}\\n\\nstatic int spi_lcd_updatearea(...) {\\n    memcpy(swapped_datas, fb, width_byte);\\n    sw_rgb565_swap(swapped_datas, area->w);\\n    SPI_SNDBLOCK(spi, swapped_datas, width_byte);\\n    ...\\n}")
]

'''

exp2 += "\n".join(lab_img(p, f"图 4-2-{i+1} LCD 驱动修改与 lvgldemo 显示") for i, p in enumerate(s2[2]))
exp2 += r'''

== 4.3 修改触摸屏驱动

将改进版 `ft5x06.c` 与 `Make.defs` 覆盖到 `nuttx/drivers/input/`。menuconfig 中取消 `FT5X06_POLLMOD`，启用 `LV_USE_NUTTX` 与 `LV_USE_NUTTX_TOUCHSCREEN`。烧录后 `lvgldemo` 应能正常点击、滑动，串口输出触摸事件回调。

'''

exp2 += "\n".join(lab_img(p, f"图 4-3-{i+1} 触摸屏驱动与 menuconfig") for i, p in enumerate(s2[3]))
exp2 += r'''

== 4.4 LCD 与触摸屏横屏适配

将 LCD 扫描方向参数 `LCD_WritePara(0x48)` 改为 `0xe8`；交换列/行地址范围使显示为 480×320；修改 `fb->videoinfo.xres/yres` 为 480/320；在 `ft5x06.c` 中将 `x = TOUCH_POINT_GET_Y(...)` 改为 `x = 480 - TOUCH_POINT_GET_Y(...)`；menuconfig 启用 `FT5X06_SWAPXY`。验证时串口应显示 xres:480、yres:320，触摸与显示位置一致。

'''

exp2 += "\n".join(lab_img(p, f"图 4-4-{i+1} 横屏显示与触摸坐标适配") for i, p in enumerate(s2[4]))
exp2 += r'''

== 4.5 创建 MyWhackMole 应用程序

复制 `lvgldemo` 为 `MyWhackMole`，修改 Kconfig、Make.defs、Makefile、CMakeLists.txt，新建 `MyWhackMole.h/c`，在 `MyWhackMole_main.c` 中调用 `app_create()` 替代 `lv_demos_create()`。

'''

exp2 += "\n".join(lab_img(p, f"图 4-5-{i+1} MyWhackMole 工程结构") for i, p in enumerate(s2[5]))
exp2 += r'''

== 4.6 游戏核心代码要点

`init_whack_a_mole_game` 创建 3×3 地鼠洞与地鼠对象；`start_game` 重置分数与时间并启动游戏/地鼠定时器；`pop_random_mole` 随机显示地鼠；`mole_click_event` 处理击中逻辑。资源路径通过 `CONFIG_EXAMPLES_MYWHACKMOLE_DATA_ROOT` 指向 `/data/res`。

== 4.7 资源配置与编译选项

将 `res` 文件夹放入 `board/common/data/UDISK`，menuconfig 启用 `EXAMPLES_MYWHACKMOLE`，确认栈大小 327680、触摸路径 `/dev/input0`、资源路径 `/data/res`。

'''

exp2 += "\n".join(lab_img(p, f"图 4-7-{i+1} 资源目录与 menuconfig") for i, p in enumerate(s2[6]))
exp2 += r'''

== 4.8 运行 MyWhackMole 基础游戏

编译打包烧录后执行 `nsh> mywhackmole`，屏幕显示游戏界面，点击开始后地鼠随机出现，击中加分，倒计时结束显示 Game Over。

'''

exp2 += "\n".join(lab_img(p, f"图 4-8-{i+1} 游戏运行界面") for i, p in enumerate(s2[7]))
exp2 += r'''

== 4.9 游戏难度参数分析

通过阅读 `MyWhackMole.c` 可知，游戏难度并非由单一变量决定，而是由总时长、刷新速度、同屏数量、停留时间、位置分布、点击区域与计分规则共同塑造。以下从工程角度归纳各参数的调节方式与对玩家体验的影响。

*（1）游戏总时长 `GAME_TIME`：* 默认 30 秒。改小（如 20）会压缩得分窗口、提高节奏压力；改大（如 60）则降低紧迫感。

*（2）地鼠刷新速度：* `mole_timer = lv_timer_create(pop_random_mole, 1000, NULL)` 中 1000 表示每 1 秒刷新。改为 700 ms 难度上升，1500 ms 则更易上手。`pop_random_mole` 内还会根据剩余时间动态调整：剩余不足 40 s 时周期 800 ms，不足 20 s 时 600 ms，使后半局逐渐加速。

*（3）同屏地鼠数量：* `show_count = rand() % 2 + 1` 表示每次 1～2 只。改为 `rand() % 3 + 1` 可同时出现 3 只，命中概率上升；若只保留 1 只则要求更高专注度。

*（4）停留时间：* 与 mole\_timer 周期绑定——周期 1000 ms 时地鼠约显示 1 秒，600 ms 时玩家反应窗口明显变窄。

*（5）位置分布：* `hole_positions[9]` 决定 9 个洞口坐标；洞口越分散，手指移动距离越大，难度越高。

*（6）洞口与图片尺寸：* `lv_obj_set_size(hole, 80, 60)` 及 `transform_scale` 影响命中区域，缩小洞口或地鼠图可显著提高操作精度要求。

*（7）计分规则：* 当前每击中 +1 分。可扩展连击加分、误触扣分、倒计时加权计分等策略以增强可玩性。

*综合建议：* 降低难度可增大 `GAME_TIME`、放慢 mole\_timer、增加同屏数量、放大命中区；提高难度则反向调节，并可让地鼠更分散。`GAME_TIME`、mole\_timer 周期与 `show_count` 是改动最小、效果最明显的三个旋钮。

= 五、进阶功能实现

== 5.1 击中视觉特效

在 `mole_click_event` 确认地鼠可见并加分后，调用 `show_hit_effect`：于地鼠位置创建临时 `lv_obj_t` 方框，设置半透明白底、黄色边框与圆角，200 ms 定时器到期后删除对象。该方案不阻塞触摸回调，且仅在真实命中时触发。

#code-block[
#raw(block: true, lang: "c", "static void show_hit_effect(lv_obj_t *mole) {\\n  lv_obj_t *box = lv_obj_create(game_screen);\\n  lv_obj_set_style_bg_opa(box, LV_OPA_30, 0);\\n  lv_obj_set_style_border_color(box, lv_color_hex(0xFFFF00), 0);\\n  lv_timer_create(hit_effect_delete_cb, 200, box);\\n}")
]

'''

exp2 += "\n".join(lab_img(p, f"图 5-1-{i+1} 击中半透明特效") for i, p in enumerate(s2[8]))
exp2 += r'''

== 5.2 击中播放 hit.wav

参照手册 3.3 音乐任务：将 `res` 放入 UDISK 后运行路径为 `/data/res/hit.wav`。封装 `play_hit_sound`，以 `task_create` 启动短任务调用 `aplay_main`，避免在 LVGL 回调中长时间阻塞。

#code-block[
#raw(block: true, lang: "c", "static void play_hit_sound(void) {\\n  static char *argv[] = {\\\"aplay\\\", \\\"/data/res/hit.wav\\\", NULL};\\n  extern int aplay_main(int argc, char *argv[]);\\n  task_create(\\\"hit_sound\\\", 100, 81920, aplay_main, argv);\\n}")
]

串口应输出 play hit sound 相关日志，板载扬声器可听到短促击中音效。

'''

exp2 += "\n".join(lab_img(p, f"图 5-2-{i+1} 击中音效播放") for i, p in enumerate(s2[9]))
exp2 += r'''

== 5.3 击中时 LED1 闪烁

`drv_gpio.c` 映射表显示 `/dev/gpio0` 为 LED1（GPIOD21）。`flash_led1` 打开设备、设为输出、写 0 点亮、延时 150 ms 后写 1 熄灭。若亮灭逻辑与硬件相反，交换 write 的 0/1 即可。

#code-block[
#raw(block: true, lang: "c", "static void flash_led1(void) {\\n  int fd = open(\\\"/dev/gpio0\\\", O_RDWR);\\n  ioctl(fd, GPIOC_WRITE, 0);\\n  usleep(150 * 1000);\\n  ioctl(fd, GPIOC_WRITE, 1);\\n  close(fd);\\n}")
]

'''

exp2 += "\n".join(lab_img(p, f"图 5-3-{i+1} LED1 闪烁反馈") for i, p in enumerate(s2[10]))
exp2 += r'''

== 5.4 K1 键开始游戏

`/dev/gpio1` 对应 K1（GPIOD7，下拉输入）。`key_thread` 轮询 `GPIOC_READ`，检测到按下后 `lvgl_lock()` → `start_game()` → `lvgl_unlock()`，避免与界面刷新并发操作 LVGL 对象。屏幕 START 按钮保留为触摸备用入口。若电平极性与预期不符，将判断条件在 true/false 间切换即可。

#code-block[
#raw(block: true, lang: "c", "static void *key_thread(void *arg) {\\n  int fd = open(\\\"/dev/gpio1\\\", O_RDONLY);\\n  while (1) {\\n    ioctl(fd, GPIOC_READ, (unsigned long)&key_value);\\n    if (key_value) { lvgl_lock(); start_game(NULL); lvgl_unlock(); }\\n    usleep(20 * 1000);\\n  }\\n}")
]

'''

exp2 += "\n".join(lab_img(p, f"图 5-4-{i+1} K1 按键开始游戏") for i, p in enumerate(s2[11]))
# remaining images if any
if len(s2) > 12 and s2[12]:
    exp2 += "\n".join(lab_img(p, f"图 5-5-{i+1} 补充实验截图") for i, p in enumerate(s2[12]))
if len(s2) > 13 and s2[13]:
    exp2 += "\n".join(lab_img(p, f"图 5-6-{i+1} 补充实验截图") for i, p in enumerate(s2[13]))

exp2 += r'''

= 六、实验结果汇总

#table(
  columns: (3.5cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*任务*], [*完成*], [*说明*]),
  [LCD 横屏显示], [✓], [RGB565 字节交换 + 480×320 适配],
  [触摸屏交互], [✓], [中断模式 + 坐标映射正确],
  [MyWhackMole 运行], [✓], [完整游戏流程可玩],
  [难度分析], [✓], [定时器/数量/位置/计分多维度调节],
  [击中特效], [✓], [半透明方框 200 ms],
  [hit.wav 音效], [✓], [task_create + aplay],
  [LED1 闪烁], [✓], [GPIO ioctl],
  [K1 开始游戏], [✓], [key_thread + lvgl_lock],
)

= 七、实验总结

本次实验从驱动修改、应用创建、资源打包到开发板运行验证，完整实现了基于 LVGL 的 WhackMole 游戏。相比初探实验，本实验将 LCD、触摸屏、LVGL、声卡、GPIO 与多任务协作结合，更接近完整的嵌入式图形交互应用。进阶功能使游戏具备视觉、听觉与灯光反馈，为 SmartMole Pro 项目的关卡体系与联机扩展提供了直接工程经验。
'''

write(ROOT / "lab_whackmole.typ", exp2)

# ── 实验3：综合实验（小智）────────────────────────────────────
e3 = imgs("实验3 综合实验")

exp3 = r'''// 实验报告 · 小智 AI 语音助手实验（综合实验）
// 编译: cd docs/labs && .\compile.ps1

#import "lab-common.typ": *

#set document(
  title: "小智 AI 语音助手实验报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init

#lab-cover(
  exp-no: "综合实验",
  exp-title: "小智 AI 语音助手",
)

#front-matter[
  #abstract-block(
    [本报告记录小智 AI 语音助手在 DshanPI openvela 开发板上的部署与联调。基础任务完成 control\_center、wifi\_manager、arecord、aplay、lvgldemo 多程序协同，经 Wi-Fi 连接小智服务器实现语音问答；进阶任务在 STT 识别文本中匹配「开灯/关灯」关键词，直接控制 LED1 亮灭。],
    keywords: [小智；WebSocket；Opus；ASR；LLM；TTS；语音控制；LED],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

+ 熟悉小智语音助手在开发板端的程序结构、网络连接、音频采集播放与 WebSocket 通信流程；
+ 将综合实验资料包（9-5\_系统集成）中的 defconfig 与 rcS 自启动脚本接入当前 SDK，使 control\_center、lvgldemo、wifi\_manager 正确编入镜像；
+ 实现设备经 Wi-Fi 与小智服务器配对，完成语音上传、识别与 TTS 回复播放；
+ 绘制端到端流程图，理解 ASR → LLM → TTS 数据链路；
+ 进阶：在 STT 文本中本地匹配「开灯」「关灯」等指令，控制 LED1 亮灭。

= 二、实验环境

#table(
  columns: (2.8cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [实验平台], [DshanPI openvela Devkit（T113S3）],
  [主机 / 虚拟机], [Windows 11 + Ubuntu 22.04],
  [源码目录], [`~/vela-opensource/`],
  [主要程序], [control\_center、wifi\_manager、arecord、aplay、lvgldemo],
  [启动脚本], [`/data/xiaozhi.sh`（rcS 自启动）],
  [服务器], [小智云端（xiaozhi.me）],
  [串口工具], [MobaXterm 1500000 baud],
)

= 三、实验原理

(1) 设备端多程序协同：系统启动后 rcS 执行 `/data/xiaozhi.sh`，依次启动 wifi\_manager、arecord、aplay、control\_center 和 lvgldemo。

(2) 音频上行：arecord 采集 PCM 音频，Opus 编码后由 control\_center 经 WebSocket 上传服务器。

(3) 服务器处理：ASR 转文本 → LLM 生成回复 → TTS 合成语音，经 WebSocket 下行。

(4) 音频下行：aplay 播放回复语音，lvgldemo 显示对话状态。

(5) 进阶 LED 控制：control\_center 收到 type 为 stt 的消息时，除界面显示外，本地 `strstr` 匹配开灯/关灯关键词，调用 `leds_ctl` 控制 GPIO。

= 四、实验内容与操作步骤

== 4.1 基础程序检查与配置切换

#step[+ 检查综合实验资料包 `9-5_系统集成` 目录，确认包含 control\_center、wifi\_manager、lvgldemo、sound、UDISK、init.d 与 defconfig；]

#step[+ 核对远端 SDK 中 `apps/examples/control_center`、`lvgldemo`、`wifi_manager` 源码，`control_center.c` 已具备 WebSocket 连接、语音消息与 IoT 处理逻辑，`leds.c` 已封装 LED1/LED2 GPIO 控制；]

#step[+ 发现工程仍停留在实验二配置（`CONFIG_EXAMPLES_MYWHACKMOLE` 启用、CONTROL\_CENTER/LVGLDEMO 未启用、rcS 中 `xiaozhi.sh` 被注释）后，将资料包 defconfig 覆盖到 nsh 配置目录，并恢复 rcS 末尾 `sh /data/xiaozhi.sh &`；]

#step[+ 切换后确认 CONTROL\_CENTER、LVGLDEMO、WIFI\_MANAGER、Wi-Fi、Opus、WebSocket、GPIO、Audio 均已启用，MYWHACKMOLE 关闭。]

== 4.2 小智语音助手基础流程

系统启动 → rcS 执行 `/data/xiaozhi.sh` → 依次启动 wifi\_manager（并设置音量）、arecord、aplay、control\_center、lvgldemo。用户讲话后 arecord 采集 PCM 并经 Opus 编码上传；control\_center 经 WebSocket 与小智服务器交互；服务器完成 ASR→LLM→TTS 后下行音频由 aplay 播放，lvgldemo 同步显示对话状态。连接建立时 control\_center 会发送 hello 并上报 LED1/LED2 的 IoT 设备描述，使云端知晓可调用 `SetStatus` 方法。

== 4.3 进阶：语音控制 LED

底层 `leds_init` 打开 `/dev/gpio0`、`/dev/gpio2` 并配置为输出；`leds_ctl(0, true/false)` 控制 LED1（写 0 点亮，写 1 熄灭）。原程序已支持解析 type 为 iot 的云端命令；为满足「直接说开灯/关灯」的需求，在 `process_other_json` 的 stt 分支中，`send_stt` 之后增加 `process_voice_led_command`，对识别文本做本地关键词匹配（开灯、打开灯、打开LED、关灯、关闭灯等），命中即调用 `leds_ctl`，无需额外唤醒词，也不干扰正常对话与 TTS 播放。

#code-block[
#raw(block: true, lang: "c", "static void process_voice_led_command(const char *text) {\\n    if (strstr(text, \\\"开灯\\\") || strstr(text, \\\"打开灯\\\")) {\\n        leds_ctl(0, true);\\n    } else if (strstr(text, \\\"关灯\\\") || strstr(text, \\\"关闭灯\\\")) {\\n        leds_ctl(0, false);\\n    }\\n}")
]

== 4.4 编译打包与烧录

在 lichee 目录执行 `m && pack`，确认 control\_center、lvgldemo、wifi\_manager 编入镜像，usrdata 包含 xiaozhi.sh 与资源文件。

= 五、端到端流程图

#seq-diagram(
  "
  用户          开发板(T113)       小智服务器        ASR        LLM        TTS
   |                |                 |              |          |          |
   |-- 说话 ------->|                 |              |          |          |
   |                |-- Opus WS ----->|              |          |          |
   |                |                 |-- 音频 ----->|          |          |
   |                |                 |<-- 文本 -----|          |          |
   |                |                 |-- 用户文本 ------------>|          |
   |                |                 |<-- 回复文本 -------------|          |
   |                |                 |-- 回复文本 ----------------------->|
   |                |                 |<-- 音频流 -------------------------|
   |                |<-- 音频 WS -----|              |          |          |
   |<-- 扬声器播放 -|                 |              |          |          |
   |                | [STT含开灯/关灯] |              |          |          |
   |                |-- GPIO LED1 ---|              |          |          |
  ",
  [图 5-1 小智语音通信端到端流程（含 LED 控制支路）],
  roles: [开发板 ←WebSocket→ 小智服务器 ←API→ ASR / LLM / TTS],
)

= 六、实验截图与运行结果

烧录成功后，在串口配置 Wi-Fi 连接热点，屏幕显示激活码，在 https://xiaozhi.me 完成设备激活后即可语音对话。开灯/关灯演示见实验视频附件。

'''

# 6 images: wifi, activation code, xiaozhi web, activated, dialogue, flowchart
captions = [
    "图 6-1 串口配置 Wi-Fi 与 Opus 音频上传日志",
    "图 6-2 开发板屏幕显示激活码",
    "图 6-3 手机浏览器登录 xiaozhi.me 激活页面",
    "图 6-4 小智设备激活成功",
    "图 6-5 板端与小智语音对话运行",
    "图 6-6 小智语音通信端到端流程图",
]
exp3 += "\n".join(lab_img(p, c) for p, c in zip(e3, captions))

exp3 += r'''

= 七、实验结果汇总

#table(
  columns: (3.5cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*任务*], [*完成*], [*说明*]),
  [配置切换], [✓], [defconfig + rcS 自启动恢复],
  [Wi-Fi 联网], [✓], [连接热点并获取 IP],
  [服务器配对], [✓], [激活码绑定 xiaozhi.me],
  [语音问答], [✓], [上行 Opus + 下行 TTS 播放],
  [端到端流程图], [✓], [ASR/LLM/TTS 全链路],
  [语音开灯], [✓], [STT 文本匹配 → GPIO],
  [语音关灯], [✓], [STT 文本匹配 → GPIO],
)

= 八、实验总结

综合实验让我理解小智语音助手并非单一程序，而是 Wi-Fi 管理、录音、播放、服务器通信与 LVGL 界面多模块协作的结果。最容易出问题的环节往往是配置、启动脚本与资源路径是否真正接通，而非某一行业务代码。进阶 LED 控制虽改动较小，但把语音识别结果、WebSocket 通信与 GPIO 外设串联起来，形成了较完整的语音控制外设范例。后续可扩展 IoT 描述接入更多设备，并支持更自然的口语指令。
'''

write(ROOT / "lab_xiaozhi.typ", exp3)

print("done:", len(e1), len(e2), len(e3), "images")
