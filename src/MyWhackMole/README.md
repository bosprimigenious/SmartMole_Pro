# MyWhackMole 应用模块

## 集成到 openvela

将整个目录复制到：

```
vela-opensource/apps/examples/MyWhackMole/
```

并在 menuconfig 中启用 `CONFIG_EXAMPLES_MYWHACKMOLE`（参见 `Kconfig`）。

## 编译

```bash
# 在 openvela 工程根目录
source vela_env.sh && source envsetup.sh
lunch_nuttx
m
```

## 板端资源

将根目录 `res.zip` 解压后同步到开发板 `/data/res/`：

```bash
# 示例：adb / 串口挂载后
unzip res.zip -d /data/
```

## 目录说明

| 路径 | 说明 |
|------|------|
| `MyWhackMole.c` | 游戏逻辑、UI 按钮、LED 线程 |
| `media_wifi/media_wifi.c` | 音效 + WiFi 配网 + UDP 联机 + 对战会话（合并模块） |
| `media_wifi/media_wifi_ui.c` | WiFi 连接 LVGL 弹窗 |
| `storage.c` | 本地统计数据读写 |
| `versus/versus_protocol.c` | 双板对战协议（编解码） |
| `_snapshots/` | 开发过程备份，**不参与** Makefile 编译 |

## 联机 IP 配置

`media_wifi/media_wifi.c` 中默认对端 IP：

```c
#define MEDIA_WIFI_PEER_IP "192.168.137.91"
```

本地端口 `43046`，对端端口 `43045`。设备 A/B 角色见 `versus/versus_protocol.h`。

## 统一 API

游戏主程序只需 `#include "media_wifi/media_wifi.h"`：

- `media_wifi_init()` — 初始化音效线程、WiFi 状态、对战 UDP
- `media_wifi_sound_play()` — 播放 hit/start 音效
- `media_wifi_connect()` / `media_wifi_ui_show()` — WiFi 配网
- `media_wifi_versus_send_*()` — 对战消息发送
