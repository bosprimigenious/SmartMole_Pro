#!/usr/bin/env python3
"""Download Unsplash images + generate diagram PNGs for defense PPT.

Sources: Unsplash License (free). Attribution in docs/ppt-projects/.../IMAGE_CREDITS.md
"""

from __future__ import annotations

import json
import urllib.request
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:
    raise SystemExit("pip install Pillow") from exc

ASSETS = Path(__file__).resolve().parents[1] / "ppt-projects" / "smartmole-defense" / "assets" / "images"
CREDITS = ASSETS.parent.parent / "IMAGE_CREDITS.md"

# Unsplash direct URLs (w=1600, q=85)
REMOTE = [
    (
        "cover_arcade.jpg",
        "https://images.unsplash.com/photo-1584013979505-67ba6e45cfda?w=1920&q=85&auto=format&fit=crop",
        "Arcade game — Unsplash",
    ),
    (
        "motivation_arcade.jpg",
        "https://images.unsplash.com/photo-1773053965532-7ca7adcd6b49?w=1400&q=85&auto=format&fit=crop",
        "Vintage arcade — Grigorii Shcheglov / Unsplash",
    ),
    (
        "embedded_board.jpg",
        "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1400&q=85&auto=format&fit=crop",
        "Technology / circuit — Unsplash",
    ),
    (
        "wifi_network.jpg",
        "https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=1400&q=85&auto=format&fit=crop",
        "Server / network — Unsplash",
    ),
    (
        "team_work.jpg",
        "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=1400&q=85&auto=format&fit=crop",
        "Team collaboration — Unsplash",
    ),
    (
        "microcontroller.jpg",
        "https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=1400&q=85&auto=format&fit=crop",
        "Embedded engineering — Unsplash",
    ),
    (
        "touch_tablet.jpg",
        "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=1400&q=85&auto=format&fit=crop",
        "Touch tablet — Unsplash",
    ),
    (
        "speaker_audio.jpg",
        "https://images.unsplash.com/photo-1611339555312-e607c8352fd7?w=1400&q=85&auto=format&fit=crop",
        "Audio headphones — Unsplash",
    ),
    (
        "led_light.jpg",
        "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1400&q=85&auto=format&fit=crop",
        "Electronics / LED — Unsplash",
    ),
    (
        "code_dev.jpg",
        "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=1400&q=85&auto=format&fit=crop",
        "Software development — Unsplash",
    ),
    (
        "wifi_router.jpg",
        "https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=1400&q=85&auto=format&fit=crop&sat=-20",
        "Network infrastructure — Unsplash",
    ),
    (
        "hammer_arcade.jpg",
        "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=1400&q=85&auto=format&fit=crop",
        "Gaming setup — Unsplash",
    ),
    (
        "sensor_lab.jpg",
        "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=1400&q=85&auto=format&fit=crop",
        "Engineering lab — Unsplash",
    ),
    (
        "planning_desk.jpg",
        "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=1400&q=85&auto=format&fit=crop",
        "Project planning — Unsplash",
    ),
    (
        "team_meeting.jpg",
        "https://images.unsplash.com/photo-1600880292203-757bb62b4baf?w=1400&q=85&auto=format&fit=crop",
        "Team meeting — Unsplash",
    ),
    (
        "database.jpg",
        "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1400&q=85&auto=format&fit=crop",
        "Data dashboard — Unsplash",
    ),
    (
        "touchscreen_app.jpg",
        "https://images.unsplash.com/photo-1551650975-87deedd944c3?w=1400&q=85&auto=format&fit=crop",
        "Touchscreen app — Unsplash",
    ),
    (
        "pcb_board.jpg",
        "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1400&q=85&auto=format&fit=crop&hue=10",
        "PCB / circuit — Unsplash",
    ),
    (
        "git_branch.jpg",
        "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1400&q=85&auto=format&fit=crop&con=10",
        "DevOps / data — Unsplash",
    ),
]

PALETTE = {
    "primary": (0, 107, 183),
    "dark": (0, 61, 107),
    "gold": (212, 168, 75),
    "ink": (26, 46, 68),
    "muted": (107, 123, 140),
    "light": (250, 252, 255),
    "ok": (21, 128, 61),
    "warn": (194, 65, 12),
    "no": (185, 28, 28),
    "white": (255, 255, 255),
}


def _font(size: int, bold: bool = False):
    candidates = [
        "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "arial.ttf",
    ]
    for name in candidates:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _download(name: str, url: str) -> bool:
    dest = ASSETS / name
    if dest.exists() and dest.stat().st_size > 8000:
        return True
    if dest.exists():
        dest.unlink()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "SmartMolePro-PPT/1.0"})
        with urllib.request.urlopen(req, timeout=45) as resp:
            dest.write_bytes(resp.read())
        return dest.stat().st_size > 8000
    except OSError as err:
        print(f"  skip {name}: {err}")
        return False


def gen_fallback_photo(path: Path, title: str, subtitle: str, color):
    img = Image.new("RGB", (1280, 720), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    _rounded_rect(draw, (60, 60, 1220, 660), 24, color)
    draw.text((100, 280), title, fill=PALETTE["white"], font=_font(48, True))
    draw.text((100, 360), subtitle, fill=(230, 240, 255), font=_font(24))
    img.save(path, quality=90)


def _rounded_rect(draw, xy, radius, fill, outline=None, width=2):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def gen_architecture(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    f_title = _font(28, True)
    f_box = _font(22, True)
    f_sub = _font(16)

    draw.text((40, 24), "三层架构（实际实现）", fill=PALETTE["dark"], font=f_title)
    layers = [
        ("用户交互层", "触摸屏 · K1 · LVGL 按钮", PALETTE["primary"]),
        ("应用逻辑层", "MyWhackMole.c · storage · versus", PALETTE["dark"]),
        ("驱动 / 系统层", "NuttX · GPIO · audiocodec · wapi", PALETTE["ink"]),
    ]
    y = 100
    for title, sub, color in layers:
        _rounded_rect(draw, (80, y, w - 80, y + 150), 16, color)
        draw.text((110, y + 28), title, fill=PALETTE["white"], font=f_box)
        draw.text((110, y + 78), sub, fill=(220, 235, 250), font=f_sub)
        y += 180
    draw.text((80, h - 40), "开题扩展 HC-SR04 / WS2812B / littlefs 未全量落地", fill=PALETTE["muted"], font=f_sub)
    img.save(path, quality=92)


def gen_threads(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    f_title = _font(26, True)
    f_box = _font(18, True)
    f_sub = _font(14)

    draw.text((40, 20), "多线程并发模型", fill=PALETTE["dark"], font=f_title)
    boxes = [
        (60, 90, 580, 200, "LVGL 主线程", "UI · 游戏逻辑 · 定时器", PALETTE["primary"]),
        (640, 90, 1160, 200, "sound_task", "hit.wav 轮询播放", PALETTE["dark"]),
        (60, 230, 580, 340, "led_task", "GPIO 120ms 闪烁", PALETTE["dark"]),
        (640, 230, 1160, 340, "key_task", "K1 → START", PALETTE["dark"]),
        (60, 370, 1160, 480, "versus_rx_task", "UDP 非阻塞收包 + 协议解析", PALETTE["gold"]),
    ]
    for x0, y0, x1, y1, title, sub, color in boxes:
        _rounded_rect(draw, (x0, y0, x1, y1), 12, color)
        draw.text((x0 + 20, y0 + 22), title, fill=PALETTE["white"], font=f_box)
        draw.text((x0 + 20, y0 + 58), sub, fill=(240, 245, 252), font=f_sub)
    draw.text((60, 520), "设计原则：请求-消费标志位，避免阻塞 GUI", fill=PALETTE["ink"], font=_font(18, True))
    img.save(path, quality=92)


def gen_versus(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    f_title = _font(26, True)
    f_box = _font(20, True)
    f_sub = _font(15)

    draw.text((40, 20), "Wi-Fi 双板联机 · UDP versus", fill=PALETTE["dark"], font=f_title)
    for x, label, port in [(120, "设备 A", "43045"), (820, "设备 B", "43046")]:
        _rounded_rect(draw, (x, 120, x + 340, 360), 20, PALETTE["primary"])
        draw.text((x + 90, 160), label, fill=PALETTE["white"], font=f_box)
        draw.text((x + 50, 210), "全屏 LVGL 游戏", fill=(220, 235, 250), font=f_sub)
        draw.text((x + 70, 250), f"UDP :{port}", fill=PALETTE["gold"], font=f_sub)
    draw.line([(460, 240), (820, 240)], fill=PALETTE["gold"], width=4)
    draw.polygon([(640, 220), (660, 240), (640, 260), (620, 240)], fill=PALETTE["gold"])
    draw.polygon([(640, 280), (620, 260), (660, 260)], fill=PALETTE["gold"])
    msgs = ["START 同步开局", "SCORE 分数同步", "FINISH 结算"]
    for i, msg in enumerate(msgs):
        _rounded_rect(draw, (480, 400 + i * 70, 800, 455 + i * 70), 10, PALETTE["white"], outline=PALETTE["primary"], width=2)
        draw.text((510, 415 + i * 70), msg, fill=PALETTE["ink"], font=f_sub)
    draw.text((80, 640), "24B 报文 · CRC · 序号去重 · 双板各自全屏", fill=PALETTE["muted"], font=f_sub)
    img.save(path, quality=92)


def gen_mole_ui(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), (76, 140, 74))
    draw = ImageDraw.Draw(img)
    f_title = _font(24, True)
    draw.text((40, 20), "游戏 UI · 9 洞布局", fill=PALETTE["white"], font=f_title)
    ox, oy, gap, size = 380, 120, 24, 140
    types = ["普通", "黄金", "普通", "炸弹", "普通", "黄金", "普通", "普通", "普通"]
    colors = [(120, 80, 50), PALETTE["gold"], (120, 80, 50), PALETTE["no"], (120, 80, 50),
              PALETTE["gold"], (120, 80, 50), (120, 80, 50), (120, 80, 50)]
    for i in range(9):
        r, c = divmod(i, 3)
        x = ox + c * (size + gap)
        y = oy + r * (size + gap)
        _rounded_rect(draw, (x, y, x + size, y + size), 999, (40, 30, 20))
        _rounded_rect(draw, (x + 18, y + 18, x + size - 18, y + size - 18), 999, colors[i])
        draw.text((x + 36, y + 52), types[i], fill=PALETTE["white"], font=_font(16, True))
    btns = ["START", "LEVEL", "MODE", "STATS", "WIFI"]
    for i, b in enumerate(btns):
        _rounded_rect(draw, (80 + i * 210, 580, 260 + i * 210, 640), 8, PALETTE["dark"])
        draw.text((110 + i * 210, 595), b, fill=PALETTE["white"], font=_font(16, True))
    img.save(path, quality=92)


def gen_levels(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    f_title = _font(26, True)
    f_lab = _font(18, True)
    draw.text((40, 20), "五层目标完成度", fill=PALETTE["dark"], font=f_title)
    levels = [
        ("L1 基础 WhackMole", 100, PALETTE["ok"]),
        ("L2 多模态输入", 30, PALETTE["warn"]),
        ("L3 闯关 + 联机", 70, PALETTE["ok"]),
        ("L4 声光 / 存储 / 特殊地鼠", 50, PALETTE["warn"]),
        ("L5 UI + WiFi 菜单", 40, PALETTE["warn"]),
    ]
    y = 100
    for label, pct, color in levels:
        draw.text((80, y), label, fill=PALETTE["ink"], font=f_lab)
        _rounded_rect(draw, (80, y + 36, 1100, y + 56), 8, (220, 228, 240))
        bar_w = int(1020 * pct / 100)
        if bar_w > 0:
            _rounded_rect(draw, (80, y + 36, 80 + bar_w, y + 56), 8, color)
        draw.text((1120, y + 28), f"{pct}%", fill=color, font=f_lab)
        y += 95
    _rounded_rect(draw, (80, 580, 1100, 660), 16, PALETTE["dark"])
    draw.text((110, 610), "综合完成度约 60%", fill=PALETTE["gold"], font=_font(32, True))
    img.save(path, quality=92)


def gen_timeline(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    f_title = _font(26, True)
    f_item = _font(17, True)
    f_sub = _font(14)
    draw.text((40, 20), "四周里程碑 · 实际达成", fill=PALETTE["dark"], font=f_title)
    draw.line([(120, 140), (1160, 140)], fill=PALETTE["primary"], width=6)
    items = [
        (120, "4/27", "基础 WhackMole", "✓", PALETTE["ok"]),
        (400, "5/11", "闯关 + 联机", "✓", PALETTE["ok"]),
        (680, "5/11", "全模块联调", "⚠", PALETTE["warn"]),
        (960, "6/8", "结题 + PPT", "…", PALETTE["primary"]),
    ]
    for x, date, title, status, color in items:
        draw.ellipse((x - 14, 126, x + 14, 154), fill=color)
        draw.text((x - 30, 170), date, fill=PALETTE["muted"], font=f_sub)
        draw.text((x - 50, 200), title, fill=PALETTE["ink"], font=f_item)
        draw.text((x - 8, 230), status, fill=color, font=_font(22, True))
    draw.text((80, 320), "待补：IP 外置 · 8 音效挂钩 · 超声波 · 排行榜 Tab", fill=PALETTE["no"], font=f_item)
    img.save(path, quality=92)


def gen_event_flow(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    f_title = _font(26, True)
    f_box = _font(17, True)
    draw.text((40, 20), "输入与事件流", fill=PALETTE["dark"], font=f_title)
    done = [
        ("触摸", "mole_click_event 命中检测", PALETTE["ok"]),
        ("K1", "start_game_request 开局", PALETTE["ok"]),
    ]
    todo = [
        ("统一队列", "hit_event_t mq_send", PALETTE["no"]),
        ("HC-SR04", "距离突变 → 坐标映射", PALETTE["no"]),
    ]
    y = 90
    draw.text((80, y), "✓ 已实现", fill=PALETTE["ok"], font=f_box)
    y += 40
    for title, sub, color in done:
        _rounded_rect(draw, (80, y, 600, y + 80), 12, color)
        draw.text((100, y + 12), title, fill=PALETTE["white"], font=f_box)
        draw.text((100, y + 42), sub, fill=(235, 245, 255), font=_font(14))
        y += 95
    y += 20
    draw.text((80, y), "× 规划未做", fill=PALETTE["no"], font=f_box)
    y += 40
    for title, sub, color in todo:
        _rounded_rect(draw, (80, y, 600, y + 80), 12, color)
        draw.text((100, y + 12), title, fill=PALETTE["white"], font=f_box)
        draw.text((100, y + 42), sub, fill=(255, 235, 235), font=_font(14))
        y += 95
    _rounded_rect(draw, (680, 120, 1200, 520), 16, PALETTE["white"], outline=PALETTE["primary"], width=3)
    draw.text((720, 160), "versus 联机", fill=PALETTE["dark"], font=f_box)
    draw.text((720, 210), "报文与板内事件分离", fill=PALETTE["ink"], font=_font(15))
    draw.text((720, 260), "互不干扰", fill=PALETTE["primary"], font=_font(20, True))
    img.save(path, quality=92)


def gen_storage(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 20), "数据存储 · storage.c", fill=PALETTE["dark"], font=_font(26, True))
    _rounded_rect(draw, (80, 100, 620, 280), 16, PALETTE["primary"])
    draw.text((110, 130), "/data/whackmole_stats.dat", fill=PALETTE["white"], font=_font(20, True))
    fields = ["最高分", "最佳连击", "总局数", "联机场次 / 胜 / 平"]
    y = 175
    for f in fields:
        draw.text((120, y), f"• {f}", fill=(230, 240, 255), font=_font(16))
        y += 28
    _rounded_rect(draw, (680, 100, 1180, 280), 16, PALETTE["dark"])
    draw.text((710, 130), "STATS 弹窗", fill=PALETTE["white"], font=_font(20, True))
    draw.text((710, 175), "只读展示 · 替代排行榜 Tab", fill=(220, 230, 245), font=_font(16))
    draw.text((710, 215), "storage_update_result()", fill=PALETTE["gold"], font=_font(15))
    _rounded_rect(draw, (80, 320, 1180, 420), 12, PALETTE["white"], outline=PALETTE["warn"], width=3)
    draw.text((110, 350), "⚠ 未做：littlefs API · 成就系统 · Top-N 分页", fill=PALETTE["warn"], font=_font(18, True))
    img.save(path, quality=92)


def gen_wifi_ui(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 20), "WiFi 图形连接 · wifi_ui.c", fill=PALETTE["dark"], font=_font(26, True))
    _rounded_rect(draw, (200, 90, 1080, 580), 20, (240, 244, 250), outline=PALETTE["primary"], width=3)
    draw.text((240, 120), "Wi-Fi 配置", fill=PALETTE["dark"], font=_font(22, True))
    draw.text((240, 170), "SSID: ________________", fill=PALETTE["ink"], font=_font(18))
    draw.text((240, 220), "密码: ________________", fill=PALETTE["ink"], font=_font(18))
    for i, (label, color) in enumerate([("SCAN", PALETTE["primary"]), ("CONNECT", PALETTE["ok"]), ("取消", PALETTE["muted"])]):
        _rounded_rect(draw, (240 + i * 200, 290, 400 + i * 200, 350), 10, color)
        draw.text((280 + i * 200, 308), label, fill=PALETTE["white"], font=_font(16, True))
    steps = ["wapi scan → wifi_scan.txt", "ifup wlan0", "wapi mode / psk / essid", "renew wlan0"]
    y = 390
    for s in steps:
        draw.text((260, y), f"→ {s}", fill=PALETTE["ink"], font=_font(15))
        y += 36
    img.save(path, quality=92)


def gen_sound_led(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 20), "声光反馈（降级方案）", fill=PALETTE["dark"], font=_font(26, True))
    _rounded_rect(draw, (60, 100, 600, 520), 16, PALETTE["primary"])
    draw.text((90, 130), "sound_task", fill=PALETTE["white"], font=_font(22, True))
    draw.text((90, 180), "8 wav 资源 · 仅 hit.wav 已挂钩", fill=(220, 235, 250), font=_font(16))
    draw.text((90, 230), "aplay -D hw:audiocodec", fill=PALETTE["gold"], font=_font(15))
    _rounded_rect(draw, (660, 100, 1200, 520), 16, PALETTE["warn"])
    draw.text((690, 130), "led_task · GPIO", fill=PALETTE["white"], font=_font(22, True))
    draw.text((690, 180), "/dev/gpio0 击中闪 120ms", fill=(255, 240, 230), font=_font(16))
    draw.text((690, 240), "× WS2812B SPI 时序未调通", fill=(255, 220, 200), font=_font(16))
    draw.text((90, 560), "降级原因：GPIO 方案可稳定答辩演示", fill=PALETTE["ink"], font=_font(17, True))
    img.save(path, quality=92)


def gen_combo(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), (76, 140, 74))
    draw = ImageDraw.Draw(img)
    draw.text((40, 20), "特殊地鼠 + COMBO", fill=PALETTE["white"], font=_font(26, True))
    items = [
        ("黄金地鼠", "+5 分", PALETTE["gold"]),
        ("炸弹地鼠", "-2 分 · 清零 COMBO", PALETTE["no"]),
        ("COMBO ×3", "+1 奖励", PALETTE["primary"]),
        ("COMBO ×5", "+2 奖励", PALETTE["primary"]),
        ("COMBO ×10", "+5 奖励", PALETTE["dark"]),
    ]
    y = 100
    for title, sub, color in items:
        _rounded_rect(draw, (80, y, 1180, y + 90), 14, color)
        draw.text((110, y + 18), title, fill=PALETTE["white"], font=_font(22, True))
        draw.text((110, y + 52), sub, fill=(240, 245, 255), font=_font(16))
        y += 105
    img.save(path, quality=92)


def gen_level_table(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 16), "五级闯关参数表 LEVEL 1–5", fill=PALETTE["dark"], font=_font(24, True))
    headers = ["关卡", "refresh_ms", "show_ms", "mole_count", "speed"]
    col_x = [80, 220, 420, 620, 820, 1020]
    y = 70
    for i, htxt in enumerate(headers):
        draw.text((col_x[i], y), htxt, fill=PALETTE["primary"], font=_font(16, True))
    rows = [
        ("L1", "1200", "800", "1", "1.0"),
        ("L2", "1000", "700", "2", "1.1"),
        ("L3", "850", "600", "2", "1.2"),
        ("L4", "700", "500", "3", "1.3"),
        ("L5", "550", "400", "3", "1.5"),
    ]
    y = 110
    for r, row in enumerate(rows):
        bg = (245, 248, 252) if r % 2 else PALETTE["white"]
        _rounded_rect(draw, (60, y, 1180, y + 50), 8, bg, outline=(200, 210, 225))
        for i, val in enumerate(row):
            draw.text((col_x[i], y + 14), val, fill=PALETTE["ink"], font=_font(16, True if i == 0 else False))
        y += 58
    draw.text((80, 430), "apply_level_config() · LEVEL 按钮循环选关", fill=PALETTE["muted"], font=_font(16))
    img.save(path, quality=92)


def gen_completion(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 16), "开题目标 vs 实际交付", fill=PALETTE["dark"], font=_font(24, True))
    items = [
        ("音效", "⚠"), ("LED", "⚠"), ("Wi-Fi 联机", "✓"), ("五级闯关", "✓"),
        ("特殊地鼠", "✓"), ("游戏 UI", "✓"), ("WiFi 菜单", "✓"), ("存储", "⚠"),
        ("HC-SR04", "×"), ("AI 难度", "×"), ("WS2812B", "×"), ("排行榜", "×"),
    ]
    for i, (name, st) in enumerate(items):
        r, c = divmod(i, 3)
        x, y = 80 + c * 380, 80 + r * 95
        color = PALETTE["ok"] if st == "✓" else PALETTE["warn"] if st == "⚠" else PALETTE["no"]
        _rounded_rect(draw, (x, y, x + 340, y + 72), 10, PALETTE["white"], outline=color, width=3)
        draw.text((x + 16, y + 10), name, fill=PALETTE["ink"], font=_font(16, True))
        draw.text((x + 280, y + 18), st, fill=color, font=_font(22, True))
    img.save(path, quality=92)


def gen_innovation(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 16), "SmartMole Pro vs 基础 WhackMole", fill=PALETTE["dark"], font=_font(24, True))
    pairs = [
        ("输入", 1, 3), ("难度", 1, 4), ("模式", 1, 5),
        ("反馈", 1, 4), ("数据", 0, 4), ("联机", 0, 5),
    ]
    y = 80
    for label, base, pro in pairs:
        draw.text((80, y + 8), label, fill=PALETTE["ink"], font=_font(16, True))
        _rounded_rect(draw, (200, y, 520, y + 28), 6, (220, 228, 240))
        _rounded_rect(draw, (200, y, 200 + 320 * base // 5, y + 28), 6, PALETTE["muted"])
        _rounded_rect(draw, (560, y, 880, y + 28), 6, (220, 228, 240))
        _rounded_rect(draw, (560, y, 560 + 320 * pro // 5, y + 28), 6, PALETTE["primary"])
        draw.text((920, y + 4), f"{base} → {pro}", fill=PALETTE["dark"], font=_font(14))
        y += 48
    draw.text((200, 400), "基础实验", fill=PALETTE["muted"], font=_font(14))
    draw.text((560, 400), "SmartMole Pro", fill=PALETTE["primary"], font=_font(14, True))
    img.save(path, quality=92)


def gen_ip_lock(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 16), "联机 IP 锁定 · L1103", fill=PALETTE["dark"], font=_font(24, True))
    _rounded_rect(draw, (80, 90, 1180, 220), 14, (30, 35, 45))
    code = 'peer_ip = "192.168.137.91";\nlocal_port = 43046;\npeer_port  = 43045;'
    draw.text((110, 120), code, fill=(120, 220, 140), font=_font(20))
    steps = ["改 IP/端口宏", "重编译 NuttX 镜像", "烧录双板", "后续：versus.conf"]
    for i, s in enumerate(steps):
        x = 80 + i * 280
        _rounded_rect(draw, (x, 280, x + 240, 380), 12, PALETTE["primary"] if i < 3 else PALETTE["gold"])
        draw.text((x + 30, 320), s, fill=PALETTE["white"], font=_font(16, True))
        if i < 3:
            draw.polygon([(x + 250, 330), (x + 280, 330), (x + 265, 345)], fill=PALETTE["gold"])
    img.save(path, quality=92)


def gen_git_flow(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 16), "协作机制 · Git 流程", fill=PALETTE["dark"], font=_font(24, True))
    nodes = ["feature 分支", "模块开发", "PR Review", "张恒基合并", "main 集成"]
    x = 60
    for i, n in enumerate(nodes):
        col = PALETTE["primary"] if i < 4 else PALETTE["ok"]
        _rounded_rect(draw, (x, 200, x + 200, 290), 12, col)
        draw.text((x + 20, 235), n, fill=PALETTE["white"], font=_font(15, True))
        if i < 4:
            draw.line([(x + 200, 245), (x + 240, 245)], fill=PALETTE["gold"], width=4)
        x += 240
    draw.text((80, 360), "versus 核心冻结 · API 接入 storage.h / wifi_ui.h", fill=PALETTE["ink"], font=_font(17))
    img.save(path, quality=92)


def gen_multimodal(path: Path):
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), PALETTE["light"])
    draw = ImageDraw.Draw(img)
    draw.text((40, 16), "多模态输入状态", fill=PALETTE["dark"], font=_font(24, True))
    modes = [
        ("触摸屏", "9 洞 + 锤子", PALETTE["ok"]),
        ("K1 按键", "START", PALETTE["warn"]),
        ("K2 半区", "未实现", PALETTE["no"]),
        ("HC-SR04", "无驱动", PALETTE["no"]),
        ("事件队列", "未实现", PALETTE["no"]),
    ]
    y = 80
    for title, sub, color in modes:
        _rounded_rect(draw, (80, y, 1180, y + 85), 12, color)
        draw.text((110, y + 16), title, fill=PALETTE["white"], font=_font(20, True))
        draw.text((110, y + 48), sub, fill=(240, 245, 255), font=_font(15))
        y += 98
    img.save(path, quality=92)


def gen_icon(path: Path, label: str, sub: str, color):
    img = Image.new("RGB", (320, 200), color)
    draw = ImageDraw.Draw(img)
    draw.text((20, 50), label, fill=PALETTE["white"], font=_font(28, True))
    draw.text((20, 110), sub, fill=(235, 242, 255), font=_font(16))
    img.save(path, quality=90)


def gen_icons():
    icons = [
        ("icon_level.png", "L1–5", "闯关", PALETTE["ok"]),
        ("icon_wifi.png", "Wi-Fi", "联机", PALETTE["primary"]),
        ("icon_mole.png", "COMBO", "特殊地鼠", PALETTE["gold"]),
        ("icon_ui.png", "UI", "9 洞界面", PALETTE["dark"]),
        ("icon_menu.png", "WIFI", "图形菜单", PALETTE["primary"]),
        ("icon_av.png", "AV", "声光 ⚠", PALETTE["warn"]),
    ]
    for name, a, b, c in icons:
        gen_icon(ASSETS / name, a, b, c)


def gen_mosaic(path: Path, sources: list[str]):
    tiles = []
    for name in sources:
        p = ASSETS / name
        if p.is_file():
            tiles.append(Image.open(p).convert("RGB"))
    if len(tiles) < 2:
        return
    tw, th = 640, 360
    canvas = Image.new("RGB", (1280, 720), PALETTE["light"])
    positions = [(0, 0), (640, 0), (0, 360), (640, 360)]
    for i, im in enumerate(tiles[:4]):
        im = im.copy()
        im.thumbnail((tw, th), Image.Resampling.LANCZOS)
        px, py = positions[i]
        canvas.paste(im, (px + (tw - im.width) // 2, py + (th - im.height) // 2))
    canvas.save(path, quality=90)


DIAGRAMS = [
    ("diag_architecture.png", gen_architecture),
    ("diag_threads.png", gen_threads),
    ("diag_versus.png", gen_versus),
    ("diag_mole_ui.png", gen_mole_ui),
    ("diag_levels.png", gen_levels),
    ("diag_timeline.png", gen_timeline),
    ("diag_event_flow.png", gen_event_flow),
    ("diag_storage.png", gen_storage),
    ("diag_wifi_ui.png", gen_wifi_ui),
    ("diag_sound_led.png", gen_sound_led),
    ("diag_combo.png", gen_combo),
    ("diag_level_table.png", gen_level_table),
    ("diag_completion.png", gen_completion),
    ("diag_innovation.png", gen_innovation),
    ("diag_ip_lock.png", gen_ip_lock),
    ("diag_git_flow.png", gen_git_flow),
    ("diag_multimodal.png", gen_multimodal),
]


FALLBACKS = {
    "touch_tablet.jpg": ("触摸输入", "Touch · LVGL", PALETTE["primary"]),
    "speaker_audio.jpg": ("音效反馈", "hit.wav · aplay", PALETTE["dark"]),
    "led_light.jpg": ("LED 灯效", "GPIO 降级", PALETTE["warn"]),
    "wifi_router.jpg": ("Wi-Fi 联机", "UDP · wapi", PALETTE["primary"]),
    "hammer_arcade.jpg": ("打地鼠", "WhackMole", PALETTE["ok"]),
    "sensor_lab.jpg": ("多模态", "HC-SR04 规划", PALETTE["ink"]),
    "pcb_board.jpg": ("硬件平台", "T113S3", PALETTE["dark"]),
    "git_branch.jpg": ("协作开发", "Git · Review", PALETTE["primary"]),
}


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    credits = ["# PPT 配图来源\n", "\n## Unsplash（Unsplash License）\n"]
    print("Downloading remote images...")
    for name, url, credit in REMOTE:
        ok = _download(name, url)
        if not ok and name in FALLBACKS:
            t, s, c = FALLBACKS[name]
            gen_fallback_photo(ASSETS / name, t, s, c)
            ok = True
            credit = f"{credit}（下载失败，已生成主题占位图）"
        print(f"  {'OK' if ok else 'FAIL'} {name}")
        if ok:
            credits.append(f"- `{name}` — {credit}\n")
    print("Generating diagrams...")
    for name, fn in DIAGRAMS:
        dest = ASSETS / name
        fn(dest)
        print(f"  OK {name}")
        credits.append(f"- `{name}` — 项目生成示意图\n")
    print("Generating card icons...")
    gen_icons()
    for n in ("icon_level.png", "icon_wifi.png", "icon_mole.png", "icon_ui.png", "icon_menu.png", "icon_av.png"):
        credits.append(f"- `{n}` — 项目生成图标\n")
        print(f"  OK {n}")
    print("Building mosaic collage...")
    gen_mosaic(ASSETS / "mosaic_highlights.jpg", [
        "cover_arcade.jpg", "hammer_arcade.jpg", "touch_tablet.jpg", "wifi_router.jpg",
    ])
    if (ASSETS / "mosaic_highlights.jpg").is_file():
        credits.append("- `mosaic_highlights.jpg` — 四图拼贴（Unsplash 源图）\n")
        print("  OK mosaic_highlights.jpg")
    credits.append("\n## 生成命令\n\n```powershell\ncd docs\npython scripts/fetch_ppt_assets.py\npython scripts/build_defense_ppt.py\n```\n")
    CREDITS.write_text("".join(credits), encoding="utf-8")
    manifest = {p.name: str(p) for p in sorted(ASSETS.glob("*")) if p.is_file()}
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Done → {ASSETS}")


if __name__ == "__main__":
    main()
