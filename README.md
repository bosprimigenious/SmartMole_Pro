# SmartMole Pro

多模态感知智能打地鼠竞技系统 — OpenVela / NuttX 课程项目。

## 仓库结构

```
SmartMole_Pro/
├── docs/                              # Typst 报告（开题 / 进度 / 分工 / 结题）
├── src/MyWhackMole/                   # 游戏源码（集成路径 apps/examples/MyWhackMole/）
├── MyWhackMole_Final_20260607.tar.gz  # 完整源码包（2026-06-07）
├── res.zip                            # 音效、字体、图标（解压部署至板端 /data/res/）
├── 地鼠_WIFI图形联网版.img             # 含 WiFi 图形菜单的演示镜像
└── README.md
```

## 源码说明

主程序目录：`src/MyWhackMole/`  
在 openvela 工程中的目标路径：`apps/examples/MyWhackMole/`

| 模块 | 文件 | 说明 |
|------|------|------|
| 游戏主逻辑 | `MyWhackMole.c` | 闯关、联机、COMBO、特殊地鼠 |
| 入口 | `MyWhackMole_main.c` | NuttX 应用入口 |
| Wi-Fi 图形连接 | `wifi_ui.c` | LVGL 弹窗 + `wapi` / `ifup` |
| 联机协议 | `versus/` | UDP START/SCORE/FINISH |
| 本地存储 | `storage.c` | 统计与持久化 |
| 开发快照 | `_snapshots/` | 历史 `.c` 备份，不参与编译 |

**当前主源码包：** `MyWhackMole_Final_20260607.tar.gz`（仓库根目录，2026-06-07）

## 资源文件

根目录 `res.zip` 含 8 个 wav 音效：

| 文件 | 用途 |
|------|------|
| `hit.wav` | 普通击中（已实现触发） |
| `gold.wav` | 黄金地鼠 |
| `bomb.wav` | 炸弹地鼠 |
| `combo.wav` | 连击奖励 |
| `countdown.wav` | 倒计时提醒 |
| `gameover.wav` | 结算 |
| `start.wav` | 开局 |
| `bgm.wav` | 背景音乐 |

部署到开发板：解压 `res.zip` → `/data/res/`（含 `fonts/`、`icons/` 子目录）。

## 演示镜像

| 文件 | 说明 |
|------|------|
| `地鼠_WIFI图形联网版.img` | 含 WiFi 图形连接菜单的版本 |

## 文档编译

```powershell
cd docs
.\compile.ps1
```

输出：`SmartMolePro_开题报告.pdf`、`SmartMolePro_任务进度报告.pdf`、`SmartMolePro_分工报告.pdf`、`SmartMolePro_结题报告.pdf`（均在 `docs/` 目录）。

## 已知限制

- 联机对端 IP 硬编码为 `192.168.137.91`（`MyWhackMole.c` → `versus_init_if_enabled`），换板需改配置。
- 音效资源已齐全，当前代码仅对击中事件播放 `hit.wav`；其余 wav 待挂钩。
