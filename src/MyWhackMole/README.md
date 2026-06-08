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
| `MyWhackMole.c` | 游戏逻辑、UI 按钮、音效/LED 线程 |
| `wifi_ui.c` | WiFi 连接弹窗（SSID/PWD + SCAN/CONNECT） |
| `storage.c` | 本地统计数据读写 |
| `versus/` | 双板 UDP 联机传输层与协议 |
| `_snapshots/` | 开发过程备份，**不参与** Makefile 编译 |

## 联机 IP 配置

`MyWhackMole.c` 中 `versus_init_if_enabled()`：

```c
config.peer_ip = "192.168.137.91";
config.local_port = 43046;
config.peer_port = 43045;
```

设备 A/B 角色由 `VERSUS_DEVICE_A` / `VERSUS_DEVICE_B` 宏区分，详见 `versus/versus_protocol.h`。
