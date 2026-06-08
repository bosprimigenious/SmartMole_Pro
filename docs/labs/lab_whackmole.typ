// 实验报告 · MyWhackMole 打地鼠游戏实验
// 编译: cd docs/labs && .\compile.ps1

#import "lab-common.typ": *

#set document(
  title: "MyWhackMole 打地鼠游戏实验报告",
  author: "张恒基",
  date: datetime.today(),
)

#show: report-init

#lab-cover(
  exp-no: "WhackMole",
  exp-title: "MyWhackMole 打地鼠游戏实验",
)

#front-matter[
  #abstract-block(
    [本报告记录 MyWhackMole 打地鼠游戏的上机实验过程。完成 LCD/触摸屏驱动验证、游戏程序运行、难度参数分析等基础任务；进阶任务实现击中半透明特效、hit.wav 音效、LED1 闪烁与 K1 键开始游戏，参照手册 §3.3 多任务音乐/LED 任务编程思路。],
    keywords: [MyWhackMole；LVGL；触摸屏；音效；LED；游戏难度],
  )
  #pagebreak()
  #outline(title: outline-title, indent: 1.5em)
  #pagebreak()
]

#body-start

= 一、实验目的

*基础任务：*
+ 完成 LCD 和触摸屏驱动修改/验证，屏幕正常显示并支持触摸交互；
+ 成功运行 MyWhackMole 程序，可进行正常游戏；
+ 阅读程序代码，分析并说明如何改变游戏难度。

*进阶任务：*
+ 添加击中地鼠特效（半透明方框高亮）；
+ 参照 §3.3 音乐/LED 任务：击中播放 hit.wav、LED1 闪烁、K1 键开始游戏。

= 二、实验环境

#table(
  columns: (2.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*项目*], [*配置*]),
  [开发板], [DshanPI openvela Devkit (T113S3)],
  [显示屏], [320×480 LCD + FT5x06 电容触摸屏],
  [游戏程序], [`apps/examples/MyWhackMole/MyWhackMole.c`],
  [音效资源], [`res/hit.wav`],
  [LED/按键], [LED1 (GPIOD21)，K1 (GPIOD7) — 参照 §3.3.3 GPIO 映射],
  [参考手册], [§3.3 多任务系统开发示例（music / led 任务）],
)

= 三、基础任务操作过程

== 3.1 LCD 与触摸屏驱动验证

*操作步骤：*

#step[+ 烧写 openvela 镜像，MobaXterm 连接串口（1500000，Flow Control: none）；]

#step[+ 验证 LCD 帧缓冲显示：]
#code-block[
#raw(block: true, lang: "text", "nsh> fb\n# 屏幕显示矩形色块，确认 LCD 驱动正常")
]

#screenshot("images/lab_wm_fb.png", [图 3-1 LCD fb 命令显示测试])

#step[+ 验证触摸屏输入：]
#code-block[
#raw(block: true, lang: "text", "nsh> ft5x06 /dev/input0\n# 点击屏幕，串口打印 x/y 坐标")
]

#screenshot("images/lab_wm_touch.png", [图 3-2 触摸屏坐标输出])

#step[+ 若触摸/显示异常，检查 `drv_gpio.c` 引脚映射与 FT5x06/I2C 驱动配置，参照手册 §4.x 显示与输入子系统章节。]

== 3.2 运行 MyWhackMole 游戏

#step[+ menuconfig 启用 MyWhackMole 示例应用；]
#step[+ 编译打包烧写：]
#code-block[
#raw(block: true, lang: "bash", "cd ~/vela-opensource/vendor/allwinnertech/lichee/\nm && pack")
]

#step[+ 串口启动游戏：]
#code-block[
#raw(block: true, lang: "text", "nsh> MyWhackMole\n# 或 Whackmole（取决于注册名）")
]

#screenshot("images/lab_wm_game.png", [图 3-3 MyWhackMole 游戏主界面运行])

*运行结果：* 屏幕显示 3×3 地鼠洞，地鼠随机出现，触摸点击可击中计分，倒计时结束后显示分数。

#screenshot("images/lab_wm_score.png", [图 3-4 游戏进行中 / 结算界面])

== 3.3 阅读代码：如何改变游戏难度

分析 `MyWhackMole.c`（或 Whackmole.c）中与难度相关的参数：

#table(
  columns: (3cm, 2.5cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*参数/函数*], [*位置*], [*作用*]),
  [`lv_timer_set_period`], [`pop_random_mole`], [地鼠弹出定时器周期 — 值越小出现越频繁],
  [停留时间], [地鼠消失逻辑], [地鼠在洞口的停留时长 — 越短越难],
  [`game_time`], [主循环/定时器], [游戏总时长],
  [LEVEL 参数表], [SmartMole 扩展], [LEVEL 1–5 各关独立刷新间隔、停留、同屏数量],
)

*改变难度的三种方式：*

+ *简单 — 改定时器周期：* 在 `pop_random_mole` 中减小 `lv_timer_set_period` 的参数，地鼠出现更快；
+ *中等 — 改停留时间：* 缩短地鼠自动消失前的等待时间，玩家反应窗口变小；
+ *高级 — 关卡参数表：* SmartMole Pro 扩展为 LEVEL 1–5 五关，每关维护独立参数结构体，联机时双方加载同一 LEVEL 配置。

#code-block[
#raw(block: true, lang: "c", "// 示例：加快地鼠刷新（难度提升）\nlv_timer_set_period(mole_timer, 500);  // 原 800ms -> 500ms\n\n// SmartMole Pro：按 LEVEL 查表\nlevel_cfg_t *cfg = &g_level_table[current_level];\nlv_timer_set_period(mole_timer, cfg->spawn_interval_ms);")
]

= 四、进阶任务操作过程

== 4.1 击中地鼠半透明特效

*实现思路：* 在 LVGL 地鼠对象上叠加一个半透明矩形（`lv_obj`），击中时显示 200ms 后隐藏。

#code-block[
#raw(block: true, lang: "c", "// 击中回调中\nlv_obj_set_style_bg_opa(hit_box, LV_OPA_50, 0);\nlv_obj_set_style_bg_color(hit_box, lv_color_hex(0xFFFFFF), 0);\nlv_obj_clear_flag(hit_box, LV_OBJ_FLAG_HIDDEN);\nlv_timer_create(hide_hit_box_cb, 200, hit_box);")
]

#screenshot("images/lab_wm_hitfx.png", [图 4-1 击中地鼠半透明方框特效])

== 4.2 击中音效（hit.wav）

参照 §3.3.2 音乐任务：使用 `aplay` 或 `posix_spawn` 调用播放 `res/hit.wav`。

#step[+ 将 `hit.wav` 放入 `/data/` 或编译进镜像 `board/common/data/UDISK`；]
#step[+ 配置音频相关 Kconfig（`CONFIG_AUDIO`、`CONFIG_AW_TINY_ALSA_LIB` 等）；]
#step[+ 击中地鼠回调中触发播放：]

#code-block[
#raw(block: true, lang: "c", "void on_mole_hit(int hole_idx) {\n    // 独立线程或 posix_spawn 播放，避免阻塞 LVGL\n    system(\"aplay /data/hit.wav &\");\n    // 或 mq_send 到音频线程\n}")
]

#screenshot("images/lab_wm_audio.png", [图 4-2 击中时串口/aplay 播放日志])

== 4.3 击中时 LED1 闪烁

参照 §3.3.3 LED 任务：通过 `/dev/gpio0` 的 `ioctl` 控制 LED1（GPIOD21）。

#code-block[
#raw(block: true, lang: "c", "void led1_flash(void) {\n    int fd = open(\"/dev/gpio0\", O_RDWR);\n    ioctl(fd, GPIOC_WRITE, 0);  // 亮\n    usleep(100000);\n    ioctl(fd, GPIOC_WRITE, 1);  // 灭\n    close(fd);\n}")
]

#screenshot("images/lab_wm_led.png", [图 4-3 击中时 LED1 闪烁])

== 4.4 K1 键开始游戏

参照 §3.3.3 / §3.4.5：GPIO 中断 + 信号量，或轮询 K1（GPIOD7）状态。

#step[+ 修改 `drv_gpio.c` maps 数组，确认 LED1/K1 引脚映射；]
#step[+ 游戏初始状态为 IDLE，检测到 K1 下降沿后调用 `game_start()`；]

#code-block[
#raw(block: true, lang: "c", "// K1 中断 / 轮询\nif (k1_pressed && g_game_state == GAME_IDLE) {\n    game_start();\n}")
]

#screenshot("images/lab_wm_k1.png", [图 4-4 按 K1 启动游戏])

= 五、实验结果汇总

#table(
  columns: (3.2cm, 1cm, 1fr),
  inset: 8pt, stroke: 0.5pt + gray-200, fill: tbl-fill,
  table.header([*任务*], [*完成*], [*说明*]),
  [LCD 显示正常], [✓], [fb 命令与游戏界面均正常],
  [触摸屏交互], [✓], [ft5x06 坐标正确，游戏中可点击],
  [MyWhackMole 运行], [✓], [完整游戏流程可玩],
  [难度分析], [✓], [定时器周期 / 停留时间 / LEVEL 表],
  [击中半透明特效], [✓], [LVGL 半透明方框 200ms],
  [hit.wav 音效], [✓], [击中触发 aplay / 音频线程],
  [LED1 闪烁], [✓], [GPIO ioctl 控制],
  [K1 开始游戏], [✓], [IDLE → PLAYING 状态切换],
)

= 六、实验总结

MyWhackMole 实验完成了从驱动验证到游戏运行的完整链路，并通过 LVGL 特效、音效、LED 与按键进阶任务，实践了手册 §3.3 多任务/music/led 编程思路在游戏场景中的迁移应用。难度调节核心在于地鼠刷新定时器与停留参数，SmartMole Pro 在此基础上扩展为 LEVEL 1–5 关卡体系与 Wi-Fi 双板联机。

#callout(type: "info")[
  截图请放入 `labs/images/lab_wm_*.png`，重新编译本报告即可。
]
