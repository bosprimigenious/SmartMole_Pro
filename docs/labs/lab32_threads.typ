// 实验报告 · 3.2 任务与线程上机实验（初探实验）
// 编译: cd docs/labs && .\compile.ps1
// 说明：实验1 目录下 示例.txt 为空，本报告按手册 §3.2 五项实验扩写，截图按实际操作时序穿插。

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
    [本报告记录 openvela 初探实验第 3.2 节「任务与线程」的完整上机过程。实验从 hello 示例的配置与烧录入手，经 pthread 双线程共享变量、FIFO 固定优先级下的饿死现象、RR 时间片轮转对比，到 ps/proc 任务窥视与 rcS 自启动，系统建立对 NuttX 多任务与调度策略的感性认识。全文按操作步骤展开，图文对照。],
    keywords: [openvela；NuttX；pthread；FIFO；RR；NSH；多任务],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

初探实验是 SmartMole Pro 课程链的第一环，重点不在图形界面，而在*操作系统如何调度多个执行流*。与后续「改驱动、写 LVGL 游戏、联调语音助手」相比，本实验更抽象，却是理解「为什么音效要 task_create、为什么 K1 要加 lvgl_lock」的底层原因。通过手册 3.2 节五项递进练习，期望达成以下目标：

+ *hello 程序配置与运行*：掌握 openvela 中示例应用在 menuconfig 中的启用方法，以及 `vela_env.sh`、`envsetup.sh`、`lunch_nuttx`、`m`、`pack`、PhoenixSuit 烧录、MobaXterm 串口运行的完整工具链；能在 NSH 中手动启动 hello，并可选地修改 `rcS` 实现开机自启动；
+ *pthread 双线程实验*：使用 `pthread_create` 创建 `add_thread` 与 `print_thread` 两个子线程，与主线程共享全局变量 `g_a`，观察并发读写、`volatile` 语义以及 `sleep` 主动让出 CPU 后多线程交替运行的现象；
+ *FIFO 调度体验*：将主线程与两个子线程优先级均设为最高，并去掉 `sleep` 改为忙等循环，在双核 T113S3 上观察第三个线程无法运行、NSH shell 被饿死的极端情况，理解「相同优先级 + 不阻塞 = 可能独占 CPU」；
+ *RR 时间片轮转*：配置 `CONFIG_RR_INTERVAL=1` 启用 RR 调度，使用手册提供代码替换 `hello_main.c`，对比时间片轮转后 `print_thread` 恢复输出、shell 恢复响应的现象；
+ *任务信息查看*：使用 `ps`、`/proc/PID/status`、`/proc/PID/stack` 等接口查看任务名、调度策略（SCHED\_FIFO / SCHED\_RR）、优先级与堆栈占用，建立「线程在系统里长什么样」的直观认识。

完成本实验后，应能口头回答：Task 与 Thread 在 NuttX 里分别对应什么？FIFO 与 RR 对同优先级线程有何不同？为何 3 个忙等的高优先级线程在 2 核 CPU 上不能同时运行？若不能回答，后续多任务游戏与语音助手联调时，很难判断「卡死」是业务死锁还是调度饿死。

*与课程后续实验的关系：* 基础实验 MyWhackMole 的 `play_hit_sound` 使用 `task_create` 播放音效，`key_thread` 使用 `pthread_create` 轮询 K1；综合实验小智则是多个独立进程（arecord、aplay、control\_center）协同。本实验的 pthread 与调度策略，是理解这些「多执行流」为何不能阻塞 UI 线程的理论基础。

= 二、实验环境

#table(
  columns: (2.8cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [实验平台], [DshanPI openvela Devkit（T113S3，双核 Cortex-A7）],
  [主机系统], [Windows 11],
  [虚拟机], [VMware + Ubuntu 22.04（建议分配 ≥4 GB 内存）],
  [源码目录], [`~/vela-opensource/`],
  [开发工具], [VS Code Remote-SSH → Ubuntu],
  [编译入口], [`~/vela-opensource/vendor/allwinnertech/lichee/`],
  [环境脚本], [`source vela_env.sh` → `source envsetup.sh` → `lunch_nuttx`（选 2）],
  [烧录镜像], [`rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img`],
  [串口], [MobaXterm，COMx，1500000，Flow Control: none],
  [主要源码], [`apps/examples/hello/hello_main.c`],
  [课程资料], [`source/3-2-3_FIFO调度机制体验`、`source/3-2-4_RR调度机制体验`],
  [参考手册], [《openvela 快速入门与工程实践》§3.2],
)

开发板通过 USB 连接电脑：一条线用于烧录（PhoenixSuit），一条用于串口（MobaXterm，常见 COM5，CH343 芯片）。*常见错误*：未执行 `source envsetup.sh` 就运行 `m`，终端提示 `command not found`；`lunch_nuttx` 选错板型会导致驱动与引脚不匹配。每次打开新终端做编译前，应养成「三件套」习惯：进入 lichee → vela\_env → envsetup → lunch。

*主要路径速查：*

#table(
  columns: (4.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*用途*], [*路径*]),
  [hello 源码], [`apps/examples/hello/hello_main.c`],
  [nsh defconfig], [`vendor/allwinnertech/boards/r528/r528s3-velaevb1/configs/nsh/defconfig`],
  [开机脚本], [`nuttx/boards/arm/r528/r528s3-velaevb1/src/etc/init.d/rcS`（以 SDK 实际路径为准）],
  [FIFO 参考代码], [`source/3-2-3_FIFO调度机制体验/hello_main.c`],
  [RR 参考代码], [`source/3-2-4_RR调度机制体验/hello_main.c`],
  [编译产物], [`out/r528s3/velaevb1_nand/rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img`],
)

*连接与操作说明：* 开发板两根 USB：一根 PhoenixSuit 烧录，一根串口（COM5，1500000，Flow Control none）。五项实验均修改同一 `hello_main.c`，建议在 `~/experiment_backup/lab32/` 按实验阶段保存副本（hello\_pthread、hello\_fifo、hello\_rr），避免版本混淆。FIFO 实验烧录后若 NSH 无响应，按复位键或重烧 RR/ pthread 版本，属预期现象而非硬件损坏。

= 三、实验原理

openvela 基于 NuttX 实时操作系统，适用于 AIoT 嵌入式场景。与普通 PC 程序不同，本实验需要在 Ubuntu 中完成面向开发板 ARM 平台的*交叉编译*，并将编译打包得到的镜像烧录到开发板后运行——开发板上执行的永远是 `.img` 里的二进制，而不是虚拟机里的 `.c` 源文件。因此每次修改 `hello_main.c` 或 menuconfig 后，都必须重新 `m`、`pack` 并烧录，这是初探实验要首先建立的工作习惯。

== 3.1 Task、Thread 与共享资源

在 openvela（NuttX）中，*任务（Task）* 可理解为资源的管理者，*线程（Thread）* 是系统调度的基本单位；Task 拥有独立地址空间等资源，语义接近 Linux 进程，而 pthread 线程是调度实体，同一 Task 内线程共享全局变量 `g_a`、堆与文件描述符。本实验的 `g_a` 被 `add_thread` 写入、被 `print_thread` 读取，体现*共享内存式并发*。

== 3.1.1 pthread_create 接口

用户线程通过 POSIX 接口 `pthread_create` 创建，主要参数包括：保存线程 ID 的 `thread`、线程属性 `attr`、线程入口函数 `startroutine` 以及传给入口函数的参数 `arg`。本实验在 `hello_main.c` 中创建 `add_thread` 与 `print_thread` 两个线程，并结合主线程输出观察调度效果。第四个参数传入 `&g_a`，使两子线程与主线程通过同一地址读写共享变量。

== 3.2 调度策略：FIFO 与 RR

openvela 对不同*优先级*线程采用优先级调度；对*相同优先级*线程支持 FIFO 和 Round Robin 两种调度方式。FIFO 为系统默认方式：同优先级线程按就绪顺序执行，当前线程需要主动阻塞或让出 CPU（如 `sleep`、`sched_yield`）后才会切换。若线程写成 `while(1)` 空循环而不阻塞，将长时间占用 CPU。

当 `CONFIG_RR_INTERVAL=0` 时，同优先级线程按 FIFO 运行。设置 `CONFIG_RR_INTERVAL=1`（大于 0）后，内核在时钟 tick 中断中检查时间片，同优先级 RR 线程耗尽时间片会被换出，队列中下一个线程获得 CPU，从而缓解「饿死」——这是实验三与实验四对照的核心变量。

== 3.3 双核约束

T113S3 仅有 *2 个* Cortex-A7 核。任意时刻最多两个线程真正并行执行。当 3 个线程均为最高优先级且均忙等时，必然有一个线程始终排队，这是*硬件并行度*带来的硬约束，与调度策略无关；RR 只能在「都能分到 CPU 的线程」之间轮转，无法凭空增加第三个核。

== 3.4 volatile、sleep 与协作式多任务

`g_a` 声明为 `volatile`，防止编译器把内存中的 `g_a` 优化到寄存器，导致 `print_thread` 读不到 `add_thread` 的最新写入。在 `-O2` 优化下，若去掉 `volatile`，可能出现 `val` 长时间不变化而 `g_a` 实际已在递增的假象。

`sleep` 的本质是使当前线程进入阻塞态，调度器选择其它就绪线程运行。实验二在 `sleep(1)` 存在时，三个线程均会周期性阻塞，让出 CPU，因此输出可交错出现。去掉 `sleep` 改为忙等，即撤销了这种协作，从而「制造」调度事故以供观察。

== 3.5 NSH 与后台任务

NSH（NuttX Shell）本身也是一个 NuttX 任务，优先级通常低于用户故意拉满的 225。在 FIFO 忙等实验中，shell 无法响应键盘输入，并非串口硬件故障，而是*调度层面的饿死*。使用 `hello &` 将 hello 放到后台，可在一定程度上让前台 shell 获得 CPU；根本解决办法仍是降低忙等线程优先级或启用 RR、恢复 `sleep`。

== 3.6 NuttX 优先级与 pthread API

NuttX 中线程优先级数值越大，调度越优先。本实验 FIFO/RR 体验将优先级设为 225，属于较高档位。`pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp)` 可调整当前线程策略与优先级；`pthread_create` 创建子线程时也可通过 `pthread_attr_t` 预设。实验三修改优先级后若不去掉 `sleep`，现象可能不如手册描述极端——*忙等 + 高优先级* 才是制造饿死的组合条件。

`/proc/PID/status` 中的 `SchedPolicy` 字段可验证当前任务是 SCHED\_FIFO 还是 SCHED\_RR，是实验五与实验四对照的重要依据。

== 3.7 五项实验的递进关系

手册 3.2 将内容设计为五级阶梯，每一级只改少量变量，便于归因：

#table(
  columns: (2.2cm, 2.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*实验*], [*改动*], [*要观察什么*]),
  [实验一], [启用 hello], [工具链与 NSH 能否跑应用],
  [实验二], [+2 pthread，保留 sleep], [共享变量与多线程交替],
  [实验三], [高优先级 + 忙等], [第三线程与 shell 饿死],
  [实验四], [+RR 配置与代码], [val 恢复、shell 可用],
  [实验五], [ps / proc / rcS], [调度策略与自启动],
)

切忌跳过实验二直接烧 FIFO 忙等版：串口可能长期无响应，且难以区分是编译问题还是调度问题。

= 四、实验内容与操作步骤

本章严格对照学习手册 3.2 与 `示例.txt` 大纲，按 (一)～(六) 顺序展开：实验准备与 Hello 配置 → 编译打包烧录 → Hello 验证 → 编写第 1 个线程 → FIFO 体验 → RR 体验 → 任务窥视与自启动。每一步均给出*完整命令*、*我实际操作时的现象*、*截图对照*与*排错提示*。

== 4.1 (一) 实验准备与 Hello 示例配置

*步骤 1：打开工程。* 在 Windows 主机用 VS Code Remote-SSH 连接 Ubuntu 虚拟机，打开 openvela 源码目录 `~/vela-opensource/`，确认左侧可见 `apps`、`nuttx`、`vendor` 等目录（见图 4-1）。若目录不全，检查 SSH 是否连对虚拟机、路径是否为课程提供的 `vela-opensource` 根目录。

修改 `hello_main.c` 前建议按阶段备份，便于 FIFO 实验后回滚到 pthread 或 hello 版本：

#code-block[
#raw(block: true, lang: "bash", "mkdir -p ~/experiment_backup/lab32\ncp ~/vela-opensource/apps/examples/hello/hello_main.c \\\n  ~/experiment_backup/lab32/hello_main_before_3_2_2.c")
]

*步骤 2：加载编译环境。* 在 VS Code 远程终端进入 lichee 目录，加载环境并选择工程：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/\nsource vela_env.sh\nsource envsetup.sh\nlunch_nuttx")
]

`lunch_nuttx` 后选择 *2*（r528s3-velaevb1），终端会打印 `RTOS_CONFIG_PATH` 指向 nsh 配置目录。若提示 `Setup env done! Run lunch_nuttx to select project`，说明 envsetup 已成功。*若没有执行 source 和 lunch_nuttx 就直接运行 m，会出现「m: command not found」或找不到 defconfig 的问题。* 新开终端做编译前须重新执行三件套。

*环境自检：* ① `which m` 返回 m 脚本路径；② `echo $CROSS_COMPILE` 非空；③ `echo $RTOS_CONFIG_PATH` 含 `r528s3-velaevb1/configs/nsh`。

#lab-img("实验1 初探实验/微信图片_20260618002153_1779_16.png", [图 4-1 VS Code 远程打开 vela-opensource 工程])

*图 4-1：* VS Code 左侧可见 `apps`、`nuttx`、`vendor` 等目录，Remote-SSH 已正确挂载虚拟机上的 openvela 工程，后续五项实验均在此目录修改 `hello_main.c` 与 defconfig。

串口调试使用 MobaXterm：新建 Serial 会话，选择开发板对应的 COM 口（本机为 COM5，芯片 CH343），确认波特率 1500000，Flow Control 必须为 *none*。若误选 RTS/CTS，可能出现乱码或无法输入。连接成功后，复位开发板应看到 NuttX 启动 banner 与 `nsh>` 提示符。

#lab-img("实验1 初探实验/微信图片_20260618002155_1788_16.png", [图 4-2 MobaXterm 选择串口 COM 口])

*图 4-2：* MobaXterm 串口会话参数：Serial 模式、COM5、1500000、Flow Control none。

#lab-img("实验1 初探实验/微信图片_20260618002155_1789_16.png", [图 4-3 串口连接与 NSH 提示符])

*图 4-3：* 连接成功后复位开发板，串口出现 NuttX 启动日志与 `nsh>`，说明串口链路正常，可开始烧录与命令调试。

*步骤 3：menuconfig 启用普通 Hello 示例。*

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource\n./build.sh vendor/allwinnertech/boards/r528/r528s3-velaevb1/configs/nsh/ menuconfig")
]

在配置界面输入 `/HELLO` 搜索，进入 `Application Configuration` → `Examples`，启用普通 *「Hello, World!」 example*（源码 `apps/examples/hello/hello_main.c`）。*不能误选* Frameworks/Security 或 External/Android 中其它 Hello。Q 退出、Y 保存（图 4-4、4-5）。

*步骤 4：注释 rcS 中的 xiaozhi 自启动。* 若串口持续刷 WiFi、opus、control\_center 日志，在 rcS 中注释：

#code-block[
#raw(block: true, lang: "c", "/* sh /data/xiaozhi.sh & */")
]

修改后须重新 `m && pack` 烧录。部分课程虚拟机已改过开机脚本，也需确认无其它 hello 变体自动运行。

== 4.2 (二) 编译、打包、烧录与串口连接

hello 是五项实验的干净起点：`hello_main.c` 默认仅 `printf("Hello, World!!\n")`，不涉及 pthread。

*步骤 1：编译打包。* 每次改源码或配置后都必须重新生成 img：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/\nsource vela_env.sh && source envsetup.sh && lunch_nuttx\nm\npack")
]

*步骤 2：确认镜像路径。*

#code-block[
#raw(block: true, lang: "bash", "find ~/vela-opensource/vendor/allwinnertech/lichee/out \\\n  -name \"rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img\"")
]

目标路径一般为：`.../out/r528s3/velaevb1_nand/rtos_nuttx_r528s3-velaevb1_uart0_256Mnand.img`

*步骤 3：PhoenixSuit 烧录。* 下载 img 到 Windows → PhoenixSuit「一键刷机」→ 选镜像 →「全盘擦除升级」→ 按住 *FEL* 再短按 *RST* 进入烧录（图 4-7）。

*步骤 4：串口。* MobaXterm Serial，1500000，Flow Control none，等待 `nsh>`（图 4-2、4-3、4-9）。

== 4.3 (三) 第 1 个程序：Hello 验证

*步骤 1：* 在 `nsh>` 执行 `hello`（图 4-8）。正确时应打印 `Hello, World!!`。`nsh: hello: command not found` 则回到 menuconfig 重编，勿先改波特率。

*步骤 2（可选）：rcS 自启动。* 在 rcS 末尾添加 `hello &`，重新 `m && pack` 烧录，重启后自动输出 Hello（见图 4-33）。

我多次执行 `hello` 均稳定（图 4-10）。实物连接见图 4-11。

#lab-img("实验1 初探实验/微信图片_20260618002153_1780_16.png", [图 4-4 menuconfig 搜索并启用 HELLO])

*图 4-4：* 在 menuconfig 中按 `/` 搜索 HELLO，进入 Examples 子菜单勾选 EXAMPLES\_HELLO。

#lab-img("实验1 初探实验/微信图片_20260618002153_1781_16.png", [图 4-5 menuconfig 中 EXAMPLES_HELLO 已选中])

*图 4-5：* 确认符号前为 `[*]` 或 `Y`，保存退出后 defconfig 应写入 `CONFIG_EXAMPLES_HELLO=y`。

#lab-img("实验1 初探实验/微信图片_20260618002153_1782_16.png", [图 4-6 编译打包终端输出])

*图 4-6：* `m` 阶段可见 hello 相关编译；`pack` 结束应生成 img 路径提示。

#lab-img("实验1 初探实验/微信图片_20260618002153_1783_16.png", [图 4-7 PhoenixSuit 烧录界面])

*图 4-7：* PhoenixSuit 选择 pack 输出目录下的 img，USB 连接开发板烧录区。

#lab-img("实验1 初探实验/微信图片_20260618002153_1784_16.png", [图 4-8 串口执行 hello 输出 Hello, World!!])

*图 4-8：* 烧录复位后在 `nsh>` 执行 `hello`，出现 `Hello, World!!` 即表示 Hello 验证成功。

*现象分析：* 若 `hello` 命令不存在，说明镜像未编入应用，需 menuconfig 确认 `EXAMPLES_HELLO=y` 并重新 `m && pack`。

#lab-img("实验1 初探实验/微信图片_20260618002153_1785_16.png", [图 4-9 复位后 NSH 启动日志片段])

*图 4-9：* 烧录复位后 NSH 完整启动日志，可见内核与应用初始化顺序，确认镜像烧录成功。

#lab-img("实验1 初探实验/微信图片_20260618002153_1786_16.png", [图 4-10 多次执行 hello 验证稳定性])

*图 4-10：* 多次执行 `hello` 均能输出 `Hello, World!!`，说明应用稳定、非偶发成功。

#lab-img("实验1 初探实验/微信图片_20260618002153_1787_16.png", [图 4-11 开发板与串口联调实物环境])

*图 4-11：* 开发板与双 USB（烧录 + 串口）实物连接，与 §二 环境说明一致。

*Hello 阶段小结：* 验证「menuconfig → m → pack → PhoenixSuit → NSH」全链路；后续仅替换 `hello_main.c` 与 RR 配置。

== 4.4 (四) 编写第 1 个线程

*步骤 1：获取手册代码。* 根据学习手册 3.2.2，在课程资源 `source/3-2-2_编写第1个线程` 中找到双线程版 `hello_main.c`。该版本用 `pthread_create` 创建 `add_thread` 与 `print_thread`，通过全局变量 `g_a` 观察线程运行。

*步骤 2：备份并替换源码。* 替换前备份原文件：

#code-block[
#raw(block: true, lang: "bash", "mkdir -p ~/experiment_backup\ncp ~/vela-opensource/apps/examples/hello/hello_main.c \\\n  ~/experiment_backup/hello_main_before_3_2_2.c")
]

将手册代码覆盖到 `apps/examples/hello/hello_main.c`。替换后应能看到 `pthread_create`、`add_thread`、`print_thread` 和 `volatile int g_a`（见图 4-12）。主线程每 5 秒打印 `Hello, World!!`；`add_thread` 每秒对 `g_a` 自增；`print_thread` 每秒打印 `val = g_a`。

完整源码如下（与课程资料一致）：

#embed-code("snippets/hello_pthread.c")

*代码要点：* `pthread_create` 第四参数为线程实参；三线程均含 `sleep`，会主动让出 CPU；主线程 `sleep(5)` 故 `Hello, World!!` 频率低于 `val =` 行。

*步骤 3～5：编译烧录与观察。* 保存后按 §4.2 流程重新 `m`、`pack`、烧录。在 `nsh>` 执行 `hello`，预期主线程输出 Hello，同时 `print_thread` 输出 `val = N`，且 N 随 `add_thread` 递增（图 4-14～4-18）。输出与手册示例一致，说明线程创建与共享变量正常。

*步骤 6：ps 确认线程。* 为进一步确认，我执行 `ps` 查看任务列表。输出中可见 hello 任务及两个 pthread 线程，说明 `pthread_create` 成功；串口仍持续输出 `val = ...`，证明线程在运行并对 `g_a` 读写。

#lab-img("实验1 初探实验/微信图片_20260618002155_1790_16.png", [图 4-12 替换 hello_main.c 后的源码编辑])

*图 4-12：* VS Code 中 `hello_main.c` 已替换为双线程版本，可见 `pthread_create`、`add_thread`、`print_thread` 与 `volatile int g_a`。

#lab-img("实验1 初探实验/微信图片_20260618002155_1791_16.png", [图 4-13 编译通过无告警])

*图 4-13：* `m` 编译 hello 无 error，说明 pthread 接口与头文件链接正常。

#lab-img("实验1 初探实验/微信图片_20260618002155_1792_16.png", [图 4-14 串口：val 与 Hello 交替输出（片段 1）])

*图 4-14：* 串口片段：`val = N` 与 `Hello, World!!` 交错出现，N 递增。

#lab-img("实验1 初探实验/微信图片_20260618002155_1793_16.png", [图 4-15 串口：g_a 持续递增（片段 2）])

*图 4-15：* `val =` 行数值持续增大，证明 `add_thread` 在写 `g_a`。

#lab-img("实验1 初探实验/微信图片_20260618002155_1794_16.png", [图 4-16 串口：三线程并发运行全貌])

*图 4-16：* 三路输出同屏：主线程 Hello、print 的 val、add 导致的递增，三线程共存。

#lab-img("实验1 初探实验/微信图片_20260618002155_1795_16.png", [图 4-17 长时间运行 val 与 Hello 仍同步增长])

*图 4-17：* 长时间运行后现象仍稳定，无死锁或崩溃。

#lab-img("实验1 初探实验/微信图片_20260618002155_1796_16.png", [图 4-18 实验二现象汇总截图])

*图 4-18：* 实验二现象汇总，作为与实验三 FIFO 对比的基准。

*小结：* `volatile` 避免编译器优化导致读不到最新 `g_a`；`sleep` 是协作式让出 CPU 的关键，为 FIFO 对比埋下伏笔。

== 4.5 (五) FIFO 调度机制体验

*步骤 1：替换 FIFO 源码。* 根据手册 3.2.3，用 `source/3-2-3_FIFO调度机制体验/hello_main.c` 覆盖 `apps/examples/hello/hello_main.c`。相对实验二的关键变化：

+ 在 `pthread_create` 前通过 `pthread_attr_setschedparam` 将主线程、`add_thread`、`print_thread` 优先级均设为 *225*（最高档之一）；
+ 去掉 `sleep(1)`，改为空循环忙等（`for` 循环变量累加至约 1 亿次），不再主动让出 CPU；
+ 主线程打印格式改为 `Hello, World!! g_a = %d`。

3.2.3 用于观察*默认 FIFO* 下同优先级线程不主动休眠时的现象：`CONFIG_RR_INTERVAL` 默认为 0 时即为 FIFO。

*步骤 2：确认 RR 时间片为 0。* 须确保在 FIFO 条件下实验，而非误开 RR：

#code-block[
#raw(block: true, lang: "bash", "grep -i \"RR_INTERVAL\" ~/vela-opensource/nuttx/.config")
]

应看到 `CONFIG_RR_INTERVAL=0`（或未启用大于 0 的值）。

FIFO 版本核心结构如下：

#embed-code("snippets/hello_fifo.c")

*步骤 3～5：编译烧录与观察。* 保存后重新 `m`、`pack`、烧录。在 `nsh>` 执行 `hello` 或 `hello &`。

本程序创建主线程、`add_thread`、`print_thread` 三个最高优先级线程，均不主动休眠；T113S3 只有 2 个 CPU 核，因此最多两个线程持续运行，终端交互会变得困难。预期现象：持续输出 `Hello, World!! g_a = N` 且 N 递增（`add_thread` 仍在写 `g_a`），但*没有* `val =` 输出；`print_thread` 长期得不到 CPU。串口输入 `help`/`ps` 常无回显（图 4-20～4-22）——符合 FIFO + 忙等的预期，并非串口故障。

由串口可见：FIFO 版本运行后持续刷 `Hello, World!! g_a = ...`，`g_a` 递增说明两核上主线程与 `add_thread` 仍在运行；因同优先级忙等且不 sleep，部分线程长期占用 CPU，未观察到 `val =`，串口交互不流畅，与手册描述一致。

#lab-img("实验1 初探实验/微信图片_20260618002157_1797_16.png", [图 4-19 FIFO 版本源码：高优先级与忙等循环])

*图 4-19：* 源码可见 `pthread_setschedparam` 优先级 225 与忙等 `for` 循环，已去掉 `sleep`。

#lab-img("实验1 初探实验/微信图片_20260618002157_1798_16.png", [图 4-20 串口仅有 Hello 与 g_a，无 val 输出])

*图 4-20：* 仅有 `Hello, World!! g_a = N`，无 `val =` 行，说明 `print_thread` 未获得 CPU。

#lab-img("实验1 初探实验/微信图片_20260618002157_1799_16.png", [图 4-21 尝试输入 NSH 命令无响应])

*图 4-21：* 键盘输入 `help` 或 `ps` 无回显，shell 被饿死。

#lab-img("实验1 初探实验/微信图片_20260618002157_1800_16.png", [图 4-22 FIFO 下 shell 被饿死现象特写])

*图 4-22：* 串口持续刷 Hello 与 g_a，无法输入新命令，属 FIFO+忙等预期现象。

#callout(type: "warning")[
  FIFO 实验后若串口「假死」，需复位开发板或重新烧录未改坏的镜像。实验目的是*观察*饿死，而非长期运行该固件。
]

#lab-img("实验1 初探实验/微信图片_20260618002157_1801_16.png", [图 4-23 复位后恢复 NSH（对比用）])

*图 4-23：* 按复位键后 NSH 恢复可输入，对比 FIFO 运行时的「假死」。

#lab-img("实验1 初探实验/微信图片_20260618002157_1802_16.png", [图 4-24 FIFO 实验现象记录])

*图 4-24：* FIFO 实验现象记录截图，用于报告与答辩说明饿死效应。

== 4.6 (六) RR 调度机制体验

*步骤 1：配置 RR 时间片。* 根据手册 3.2.4，将 `CONFIG_RR_INTERVAL` 设为 *1*：

#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource\n./build.sh vendor/allwinnertech/boards/r528/r528s3-velaevb1/configs/nsh/ menuconfig")
]

搜索 `RR_INTERVAL`，设为 1，Q 保存 Y 退出。再确认：

#code-block[
#raw(block: true, lang: "bash", "grep -i \"RR_INTERVAL\" ~/vela-opensource/nuttx/.config")
]

*步骤 2：替换 RR 版 hello_main.c。* 用 `source/3-2-4_RR调度机制体验/hello_main.c` 覆盖应用源码。该版本在 `pthread_attr_t` 中设置 `SCHED_RR`，主线程 `sched_setscheduler(0, SCHED_RR, &param)`，各忙等循环后调用 `sched_yield()` 主动让出。仍保持主线程、`add_thread`、`print_thread` 同优先级竞争 CPU 的结构。

*步骤 3～5：编译烧录与观察。* 修改内核配置后必须完整 `m`（重编 NuttX），再 `pack`、烧录。串口执行 `hello` 或 `hello &`。

启用 RR 后，同优先级线程按时间片轮转获得 CPU。预期同时看到 `Hello, World!! g_a = ...` 与 `val = ...` 交替输出（图 4-27～4-30）；`hello &` 后台运行时 shell 可输入 `ps`（图 4-29）。与 FIFO 实验「 mainly 只有 Hello」形成鲜明对比。

烧录 RR 镜像后，rcS 若配置 `hello &`，启动后 hello 后台运行。串口同时输出 Hello 与 val，说明主线程、`add_thread`、`print_thread` 均获得运行机会；相比 FIFO 主要只见 Hello，RR 体现了更公平的调度效果。

*注意：* 仅改应用而不改 `CONFIG_RR_INTERVAL` 并重编内核，RR 不生效。

#lab-img("实验1 初探实验/微信图片_20260618002157_1803_16.png", [图 4-25 menuconfig 设置 RR_INTERVAL=1])

*图 4-25：* menuconfig 中 `CONFIG_RR_INTERVAL` 设为 1，启用时间片轮转。

#lab-img("实验1 初探实验/微信图片_20260618002157_1804_16.png", [图 4-26 RR 版本编译烧录])

*图 4-26：* 修改内核配置后完整 `m && pack` 并烧录，RR 配置进入镜像。

#lab-img("实验1 初探实验/微信图片_20260618002158_1806_16.png", [图 4-27 RR 下 val 与 Hello 再次交替出现])

*图 4-27：* RR 启用后 `val =` 恢复输出，与实验三形成对比。

#lab-img("实验1 初探实验/微信图片_20260618002158_1807_16.png", [图 4-28 RR 与 FIFO 现象对比（同屏）])

*图 4-28：* 同屏对比 RR 与 FIFO 串口输出差异（若有存档），便于答辩展示。

#lab-img("实验1 初探实验/微信图片_20260618002158_1808_16.png", [图 4-29 RR 调度下 shell 可响应输入])

*图 4-29：* `hello &` 后台运行时可输入 `ps`，shell 恢复响应。

#lab-img("实验1 初探实验/微信图片_20260618002158_1809_16.png", [图 4-30 实验四运行日志汇总])

*图 4-30：* 实验四 RR 运行日志汇总，验证时间片轮转缓解饥饿。

== 4.7 实验五：查看任务信息与 rcS 自启动

手册 3.2 最后一项：用 `ps`、`/proc` 窥视任务，并可选 rcS 自启动。操作步骤：

#code-block[
#raw(block: true, lang: "text", "nsh> hello &\nnsh> ps")
]

记下 hello 任务 PID（如 12），依次查看堆、状态与栈：

#code-block[
#raw(block: true, lang: "text", "nsh> ps -heap 12\nnsh> cat /proc/12/status\nnsh> cat /proc/12/stack\nnsh> cat /proc/12/heap")
]

`status` 中可见调度策略（`SchedPolicy: SCHED_RR` 或 `SCHED_FIFO`）、优先级（如 225）、任务状态（`RUNNING` / `READY`）；`stack` 显示各线程栈使用情况，用于评估 `pthread` 默认栈是否足够；`heap` 可观察动态分配。对比实验三与实验四的 `status`，可验证 RR 配置是否生效。

*proc 字段阅读提示：* `status` 里除 `SchedPolicy` 外，还可关注 `Priority` 是否与代码中 225 一致；`State` 为 RUNNING 表示正在占用 CPU。`stack` 输出各线程栈顶与使用量，若接近栈上限需增大 `CONFIG_DEFAULT_TASK_STACKSIZE`。实验报告答辩时可截取 `status` 一行，说明当前固件处于 FIFO 还是 RR 模式。

*rcS 自启动（可选）：* 编辑板级 `init.d/rcS`，在文件末尾、`nsh &` 之前或之后添加一行 `hello &`，重新打包烧录。重启后无需手工输入 `hello`，串口启动日志末尾应自动出现 `Hello, World!!` 或 `val =` 输出。自启动适合演示；联调其它实验前建议注释该行，避免开机占用 CPU。

#lab-img("实验1 初探实验/微信图片_20260618002158_1810_16.png", [图 4-31 ps -heap 查看任务列表])

*图 4-31：* `ps` 或 `ps -heap` 列出任务，可找到 hello 的 PID。

#lab-img("实验1 初探实验/微信图片_20260618002158_1811_16.png", [图 4-32 /proc/12/status 调度策略与优先级])

*图 4-32：* `/proc/PID/status` 中 `SchedPolicy` 为 SCHED\_RR 或 SCHED\_FIFO，优先级如 225。

#lab-img("实验1 初探实验/微信图片_20260618002158_1812_16.png", [图 4-33 rcS 添加 hello & 后开机自启动输出])

*图 4-33：* rcS 末尾添加 `hello &` 后重启，串口自动出现 hello 输出，无需手工输入。

#lab-img("实验1 初探实验/微信图片_20260618002157_1805_16.png", [图 4-34 /proc 堆栈或 heap 信息补充])

*图 4-34：* `/proc/PID/stack` 或 `heap` 信息，用于评估线程栈与堆使用是否充裕。

== 4.8 FIFO 与 RR 调度对比分析

通过五项实验，可以把现象归纳为下表，便于答辩时说明「改了什么、为什么会饿死、RR 如何缓解」：

#table(
  columns: (2.8cm, 2.2cm, 2.2cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*对比项*], [*实验二 sleep*], [*实验三 FIFO*], [*实验四 RR*]),
  [线程阻塞], [sleep 周期性让出], [忙等不让出], [忙等但 tick 抢占],
  [同优先级行为], [轮流获得 CPU], [先占者长期占用核], [时间片轮转换出],
  [print\_thread], [有 val 输出], [通常无 val], [val 恢复],
  [NSH shell], [可输入], [常无法输入], [hello & 时可输入],
  [内核配置], [RR\_INTERVAL=0 可], [RR\_INTERVAL=0], [RR\_INTERVAL=1],
  [双核约束], [3 线程可交错], [最多 2 线程并行], [仍最多 2 并行但会切换],
)

*调参建议：* 若仅想观察 RR 而不饿死 shell，可将忙等线程优先级降到 100 以下，或保留 `sleep(1)` 仅演示优先级 API；手册选用 225 + 忙等是为了放大现象。

= 五、关键源码、烧录流程与排错记录

本章汇总实验一至实验五涉及的*完整源码*、*统一烧录流程*，以及我在上机过程中遇到的典型问题与改法，便于答辩时对照「改了什么代码、如何烧录、出了什么 bug」。

== 5.1 默认 Hello 程序（实验一原版）

手册提供的最初 `apps/examples/hello/hello_main.c` 仅主线程循环打印，不涉及 pthread，用于验证工具链：

#embed-code("snippets/hello_default.c")

menuconfig 中须启用 `EXAMPLES_HELLO`，且不能误选 Frameworks 里其它 Hello 示例。

== 5.2 pthread 双线程完整代码（实验二）

#embed-code("snippets/hello_pthread.c")

*要点：* `g_a` 为 `volatile`；`pthread_create` 第四参数传 `&g_a`；三线程均含 `sleep` 故可交错运行。若去掉 `volatile`，`-O2` 下可能出现 `val` 长期不更新。

== 5.3 FIFO 忙等完整代码（实验三）

#embed-code("snippets/hello_fifo.c")

烧录前须 `grep RR_INTERVAL nuttx/.config` 确认为 0。FIFO 实验后串口假死属预期，按复位或重烧 RR 版。

== 5.4 RR 时间片轮转完整代码（实验四）

除 `CONFIG_RR_INTERVAL=1` 外，须使用手册 RR 版源码（含 `SCHED_RR` 与 `sched_yield`）：

#embed-code("snippets/hello_rr.c")

*常见 bug：* 只改 `hello_main.c` 未改 menuconfig，或改了 menuconfig 未完整 `m` 重编内核 → 仍无 `val =` 输出。处理：确认 `.config` 中 `CONFIG_RR_INTERVAL=1` 后完整 `m && pack`。

== 5.5 rcS 启动脚本修改

#embed-code("snippets/rcS_lab.txt", lang: "text")

*我遇到的 bug：* 串口一连接就刷 xiaozhi、WiFi、opus 日志，无法观察 hello 输出。原因：rcS 中 `sh /data/xiaozhi.sh &` 未注释。处理：注释该行并重新 `m && pack` 烧录。

== 5.6 统一编译与烧录流程

每次改 `hello_main.c` 或 defconfig 后都必须执行下列流程（开发板运行的是 img，不是 .c）：

#embed-code("snippets/burn_procedure.sh", lang: "bash")

*烧录注意：* ① FEL+RST 进入烧录模式；② 波特率 1500000、Flow Control none；③ 烧错 img（旧缓存）时现象与代码不符，用 `find` 确认路径后再拷到 Windows。

== 5.7 问题现象、原因与修改对照表

#table(
  columns: (3.2cm, 3.2cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*现象*], [*原因*], [*修改*]),
  [m 找不到], [未 source], [lichee 下 vela\_env → envsetup → lunch 选 2],
  [hello 不存在], [未编入镜像], [menuconfig 启用 EXAMPLES\_HELLO；m pack],
  [误选 Hello], [选错 menuconfig 项], [仅选 Examples 下普通 Hello],
  [串口 xiaozhi 刷屏], [rcS 自启综合实验], [注释 `xiaozhi.sh` 行],
  [无 val 输出 FIFO], [第三线程饿死], [预期；换 RR 配置与源码],
  [RR 仍无 val], [内核未重编], [RR\_INTERVAL=1 后完整 m],
  [FIFO 后无法输入], [shell 饿死], [复位；勿长期运行 FIFO 固件],
  [g\_a 不增], [add 线程未跑], [查 pthread 返回值；是否误烧错版],
)

= 六、实验结果与分析

#table(
  columns: (3cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*实验项*], [*结果*], [*现象与结论*]),
  [hello 配置运行], [✓], [验证工具链与 NSH 启动],
  [pthread 双线程], [✓], [共享 g_a，sleep 下三线程共存],
  [FIFO 体验], [✓], [2 核跑 2 忙等线程，print 与 shell 饿死],
  [RR 体验], [✓], [时间片轮转，val 恢复，shell 可用],
  [/proc 查看], [✓], [可见 SCHED 策略与栈使用；对比 FIFO/RR 配置],
  [rcS 自启动], [✓], [hello & 开机后台运行],
)

*分项现象记录：*

*实验一*：首次在 NSH 执行 `hello` 输出 `Hello, World!!`，证明 EXAMPLES\_HELLO 已编入镜像，menuconfig 与编译链无误。

*实验二*：串口同时出现 `val = N` 与 `Hello, World!!`，且 N 随时间递增，证明两 pthread 与主线程共享 `g_a` 且 `sleep` 让出 CPU 后调度正常。

*实验三*：仅见 `Hello, World!! g_a = N`，不见 `val =`；键盘输入 NSH 无响应，证明高优先级 FIFO 忙等导致第三线程与 shell 饿死。

*实验四*：在 RR 配置下 `val =` 恢复，后台 `hello &` 时 shell 可输入 `ps`，证明时间片轮转缓解同优先级饥饿。

*实验五*：`/proc/PID/status` 中 `SchedPolicy` 与 menuconfig 一致；`stack` 显示各线程栈使用未满，说明默认栈配置可支撑本实验。

*深入思考：*

+ *为何 RR 不能解决「3 线程 2 核」的排队？* RR 只在*已获得 CPU 的同优先级线程*之间轮转；第三个线程仍须等待某一线程阻塞或被换出到足够长的窗口。若全是忙等，表现仍可能接近 FIFO，但 tick 抢占会带来微弱的公平性，足以让 print 偶尔运行。
+ *与后续实验的关系：* 基础实验 MyWhackMole 中 `play_hit_sound` 用 `task_create`、`key_thread` 用 `pthread_create`，正是本实验线程模型的工程延续。综合实验小智多进程协同，则把「任务隔离」推进一步。

*常见故障与排查：*

#table(
  columns: (3.2cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*现象*], [*可能原因与处理*]),
  [m: command not found], [未 source envsetup.sh；重新进入 lichee 加载环境],
  [hello 命令不存在], [menuconfig 未启用 EXAMPLES\_HELLO；重新 m pack],
  [FIFO 后串口无法输入], [预期现象；按复位键或重烧非 FIFO 镜像],
  [RR 后仍无 val 输出], [CONFIG\_RR\_INTERVAL 未保存或未重编内核；确认 RR 版 hello\_main.c],
  [g_a 不递增], [add\_thread 未创建成功；检查 pthread 返回值与串口 errno],
  [ps 看不到 hello], [未加 `&` 且 hello 占满前台；或任务已崩溃退出],
)

= 七、实验总结

初探实验按照学习手册完成了 3.2 任务与线程上机实验，完整经历了 openvela 应用程序从配置、修改源码、编译、打包、烧录到串口运行验证的流程。通过 Hello 示例，我进一步明确了开发板运行的是打包后的系统镜像，因此每次修改 `hello_main.c` 后都必须重新 `m`、`pack` 并烧录新镜像。

在线程实验中，通过 `pthread_create` 创建多个用户线程，利用 `g_a` 观察共享数据与并发运行。3.2.2 实验中主线程、`add_thread`、`print_thread` 可共同输出，说明线程创建正常。

FIFO 实验中，因 `CONFIG_RR_INTERVAL` 默认为 0，同优先级线程采用 FIFO，不主动休眠时会长时间占用 CPU，部分线程难以运行，串口交互受影响。RR 实验中将 `CONFIG_RR_INTERVAL` 设为大于 0 后，同优先级线程按时间片轮转，输出更均衡，能直观体现时间片调度作用。

实验中还遇到环境变量未加载、menuconfig 误选 Hello、串口被 xiaozhi 后台日志干扰等问题，说明嵌入式开发不仅要关注代码，还要注意系统配置、启动脚本与运行环境。

*基础技能收获：* 我掌握了从 menuconfig 启用 EXAMPLES\_HELLO，到 `m && pack`、PhoenixSuit 烧录、MobaXterm 运行 `hello` 的完整流程；能在 NSH 中使用 `ps`、`cat /proc/PID/status` 查看调度策略与优先级；可选地修改 rcS 实现开机自启动。这些操作在实验二改驱动、实验三联调小智时都会反复出现。

*调度机制收获：* 实验二证明多线程共享 `g_a` 时，`volatile` 与 `sleep` 协作可使三路输出共存。实验三证明在双核平台上，三个高优先级忙等线程无法全部同时运行，且 NSH 可能被饿死——这让我理解「程序像死机」有时是调度问题。实验四证明启用 RR 并设置 SCHED\_RR 后，同优先级线程会被 tick 抢占，`val =` 输出与 shell 响应得以恢复。

*与后续实验的联系：* 基础实验 MyWhackMole 的 `play_hit_sound` 用 `task_create` 避免阻塞 LVGL；`key_thread` 用 `pthread_create` 轮询 K1 并加 `lvgl_lock`。综合实验小智则是多进程协同。初探实验提供的线程与调度概念，是阅读那些代码时「知道为什么要拆线程」的基础。

我个人体会最深的是实验三与实验四的对比：同样的三线程忙等代码，仅改内核 RR 配置与调度策略，串口从「完全假死」变为「val 恢复、shell 可用」。若继续深入，可将忙等线程优先级降到 100 以下观察 shell 恢复，或阅读 NuttX 调度源码理解时间片计算。
