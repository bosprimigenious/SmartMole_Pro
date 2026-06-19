#!/usr/bin/env python3
"""Generate 22 polished defense SVG slides (CQU / ppt-master style)."""

from __future__ import annotations

import html
import math
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "ppt-projects" / "smartmole-defense"
SVG_DIR = ROOT / "svg"

C_PRIMARY = "#006BB7"
C_DARK = "#003D6B"
C_DEEP = "#004A82"
C_SKY = "#3A9BD9"
C_GOLD = "#D4A84B"
C_INK = "#1A2E44"
C_BODY = "#333D4A"
C_MUTED = "#6B7B8C"
C_LIGHT = "#FAFCFF"
C_CLOUD = "#E3F2FD"
C_OK = "#15803D"
C_WARN = "#C2410C"
C_NO = "#B91C1C"
FONT = "Microsoft YaHei, PingFang SC, sans-serif"
W, H = 1280, 720


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def defs() -> str:
    dots = []
    for i in range(18):
        x, y = 980 + (i % 6) * 42, 120 + (i // 6) * 48
        dots.append(f'<circle cx="{x}" cy="{y}" r="2.5" fill="{C_SKY}" opacity="0.35"/>')
    dot_svg = "\n".join(dots)
    return textwrap.dedent(f"""
    <defs>
      <linearGradient id="hdrGrad" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0%" stop-color="{C_DEEP}"/><stop offset="55%" stop-color="{C_PRIMARY}"/><stop offset="100%" stop-color="{C_SKY}"/>
      </linearGradient>
      <linearGradient id="coverGrad" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="{C_DARK}"/><stop offset="100%" stop-color="{C_PRIMARY}"/>
      </linearGradient>
      <linearGradient id="goldGrad" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0%" stop-color="#C49A3D"/><stop offset="100%" stop-color="{C_GOLD}"/>
      </linearGradient>
      <linearGradient id="panelGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#ffffff"/><stop offset="100%" stop-color="{C_CLOUD}"/>
      </linearGradient>
      <linearGradient id="grassGrad" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#5A9E56"/><stop offset="100%" stop-color="#3D7A3A"/>
      </linearGradient>
      <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
        <feDropShadow dx="0" dy="5" stdDeviation="10" flood-color="#003D6B" flood-opacity="0.2"/>
      </filter>
      <filter id="glow"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
      <marker id="arr" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto">
        <polygon points="0,0 10,4 0,8" fill="{C_GOLD}"/>
      </marker>
      <symbol id="ico-wifi" viewBox="0 0 24 24">
        <path d="M12 18c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2z" fill="#fff"/>
        <path d="M12 6C8 6 4.5 7.6 2 10l1.5 1.5C5.5 9.2 8.6 8 12 8s6.5 1.2 8.5 3.5L22 10c-2.5-2.4-6-4-10-4z" fill="#fff" opacity="0.9"/>
        <path d="M12 10c-2.5 0-4.8 1-6.5 2.6L7 14c1.3-1.2 3.1-2 5-2s3.7.8 5 2l1.5-1.4C17.8 11 15.5 10 12 10z" fill="#fff" opacity="0.75"/>
      </symbol>
      <symbol id="ico-chip" viewBox="0 0 24 24">
        <rect x="6" y="6" width="12" height="12" rx="2" fill="none" stroke="#fff" stroke-width="1.5"/>
        <path d="M9 3v3M12 3v3M15 3v3M9 18v3M12 18v3M15 18v3M3 9h3M3 12h3M3 15h3M18 9h3M18 12h3M18 15h3" stroke="#fff" stroke-width="1.5"/>
      </symbol>
      <symbol id="ico-hammer" viewBox="0 0 24 24">
        <rect x="4" y="14" width="14" height="4" rx="1" fill="#D4A84B" transform="rotate(-35 11 16)"/>
        <rect x="14" y="4" width="6" height="10" rx="1" fill="#8B6914" transform="rotate(-35 17 9)"/>
      </symbol>
    </defs>
    <g id="deco-dots" opacity="0.5">{dot_svg}</g>
    """)


def wave_bg(opacity: float = 0.1) -> str:
    return f"""
    <path d="M0,680 Q320,650 640,680 T1280,660 L1280,720 L0,720 Z" fill="{C_PRIMARY}" fill-opacity="{opacity}"/>
    <path d="M0,700 Q400,670 800,700 T1280,685 L1280,720 L0,720 Z" fill="{C_SKY}" fill-opacity="{opacity * 0.55}"/>
    """


def diag_accent() -> str:
    return f'<polygon points="1180,78 1280,78 1280,180 1100,78" fill="{C_SKY}" opacity="0.12"/>'


def footer(section: str, num: int) -> str:
    return f"""
    <rect x="0" y="658" width="{W}" height="62" fill="{C_LIGHT}"/>
    <line x1="0" y1="658" x2="{W}" y2="658" stroke="{C_CLOUD}" stroke-width="1"/>
    <text x="60" y="694" font-family="{FONT}" font-size="11" fill="{C_MUTED}">SmartMole Pro · 第六组</text>
    <text x="640" y="694" text-anchor="middle" font-family="{FONT}" font-size="11" fill="{C_MUTED}">{esc(section)}</text>
    <rect x="1188" y="672" rx="8" width="32" height="28" fill="url(#hdrGrad)"/>
    <text x="1204" y="692" text-anchor="middle" font-family="{FONT}" font-size="12" font-weight="700" fill="#fff">{num}</text>
    """


def header(title: str, section: str, num: int) -> str:
    return f"""
    <rect x="0" y="0" width="8" height="{H}" fill="{C_PRIMARY}"/>
    <rect x="8" y="0" width="{W-8}" height="78" fill="url(#hdrGrad)"/>
    <rect x="52" y="68" width="120" height="4" fill="url(#goldGrad)" rx="2"/>
    <text x="52" y="48" font-family="{FONT}" font-size="28" font-weight="700" fill="#fff">{esc(title)}</text>
    {diag_accent()}
    {footer(section, num)}
    {wave_bg(0.08)}
    """


def wrap(body: str) -> str:
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
{defs()}
<rect width="{W}" height="{H}" fill="{C_LIGHT}"/>
{body}
</svg>
'''


def diagram_frame(x: int, y: int, w: int, h: int, inner: str) -> str:
    return f"""
    <g transform="translate({x},{y})" filter="url(#shadow)">
      <rect width="{w}" height="{h}" rx="18" fill="url(#panelGrad)" stroke="{C_CLOUD}" stroke-width="1"/>
      <g transform="translate(16,12)">{inner}</g>
    </g>
    """


def bullets(x: int, y: int, items: list[str], size: int = 16, gap: int = 32, max_w: int = 580) -> str:
    out = []
    cy = y
    for item in items:
        raw = item
        if raw.startswith("✓"):
            dot, fc, text = C_OK, C_OK, raw[1:].strip()
        elif raw.startswith("⚠"):
            dot, fc, text = C_WARN, C_WARN, raw[1:].strip()
        elif raw.startswith("×"):
            dot, fc, text = C_NO, C_NO, raw[1:].strip()
        else:
            dot, fc, text = C_PRIMARY, C_BODY, raw
        out.append(f'<rect x="{x}" y="{cy-14}" width="4" height="20" rx="2" fill="{dot}"/>')
        out.append(
            f'<text x="{x+14}" y="{cy}" font-family="{FONT}" font-size="{size}" fill="{fc}">{esc(text)}</text>'
        )
        cy += gap
    return "\n".join(out)


def ring_chart(cx: int, cy: int, r: int, pct: int, label: str) -> str:
    circ = 2 * math.pi * r
    dash = circ * pct / 100
    return f"""
    <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="18"/>
    <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{C_GOLD}" stroke-width="18" stroke-linecap="round"
      stroke-dasharray="{dash:.1f} {circ:.1f}" transform="rotate(-90 {cx} {cy})"/>
    <text x="{cx}" y="{cy+8}" text-anchor="middle" font-family="{FONT}" font-size="44" font-weight="700" fill="{C_GOLD}">{pct}%</text>
    <text x="{cx}" y="{cy+36}" text-anchor="middle" font-family="{FONT}" font-size="14" fill="#E3F2FD">{esc(label)}</text>
    """


def card(x, y, w, h, title, desc, accent=C_PRIMARY, icon: str | None = None) -> str:
    ico = ""
    if icon:
        ico = f'<use href="#{icon}" x="{x+14}" y="{y+18}" width="28" height="28"/>'
    return f"""
    <g filter="url(#shadow)">
      <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="#fff" stroke="{C_CLOUD}" stroke-width="1"/>
      <rect x="{x}" y="{y}" width="{w}" height="7" rx="14" fill="{accent}"/>
      {ico}
      <text x="{x+48 if icon else x+16}" y="{y+38}" font-family="{FONT}" font-size="15" font-weight="700" fill="{C_DARK}">{esc(title)}</text>
      <text x="{x+16}" y="{y+64}" font-family="{FONT}" font-size="12" fill="{C_BODY}">{esc(desc)}</text>
    </g>
    """


def progress_bar(x, y, w, label, pct, color) -> str:
    bw = max(0, int((w - 110) * pct / 100))
    return f"""
    <text x="{x}" y="{y}" font-family="{FONT}" font-size="14" font-weight="600" fill="{C_INK}">{esc(label)}</text>
    <rect x="{x}" y="{y+12}" width="{w-110}" height="12" rx="6" fill="{C_CLOUD}"/>
    <rect x="{x}" y="{y+12}" width="{bw}" height="12" rx="6" fill="{color}"/>
    <text x="{x+w-90}" y="{y+22}" font-family="{FONT}" font-size="13" font-weight="700" fill="{color}">{pct}%</text>
    """


# ── Illustrations (inline <g>, no nested svg) ──

def illust_mole_board() -> str:
    g = [f'<rect x="0" y="0" width="528" height="340" rx="14" fill="url(#grassGrad)"/>']
    holes = ["普", "金", "普", "炸", "普", "金", "普", "普", "普"]
    cols = [C_BODY, C_GOLD, C_BODY, C_NO, C_BODY, C_GOLD, C_BODY, C_BODY, C_BODY]
    ox, oy, sz, gap = 110, 36, 88, 14
    for i, (lab, col) in enumerate(zip(holes, cols)):
        r, c = divmod(i, 3)
        x, y = ox + c * (sz + gap), oy + r * (sz + gap)
        g.append(f'<ellipse cx="{x+44}" cy="{y+52}" rx="40" ry="26" fill="#2A1C12"/>')
        g.append(f'<ellipse cx="{x+44}" cy="{y+44}" rx="30" ry="20" fill="{col}"/>')
        g.append(f'<text x="{x+44}" y="{y+49}" text-anchor="middle" font-family="{FONT}" font-size="12" font-weight="700" fill="#fff">{lab}</text>')
    g.append('<use href="#ico-hammer" x="400" y="8" width="48" height="48" opacity="0.9"/>')
    for i, b in enumerate(["START", "LEVEL", "MODE", "STATS", "WIFI"]):
        g.append(f'<rect x="{16+i*100}" y="290" width="88" height="32" rx="8" fill="{C_DARK}"/>')
        g.append(f'<text x="{60+i*100}" y="311" text-anchor="middle" font-family="{FONT}" font-size="10" fill="#fff">{b}</text>')
    return "\n".join(g)


def diag_layers() -> str:
    layers = [("用户交互层", "触摸 · K1 · LVGL", C_PRIMARY, 0), ("应用逻辑层", "MyWhackMole · storage · versus", C_DARK, 88),
              ("驱动 / 系统层", "NuttX · GPIO · 音频 · wapi", C_INK, 176)]
    g = []
    for t, s, c, dy in layers:
        g.append(f'<rect x="0" y="{dy}" width="500" height="72" rx="12" fill="{c}"/>')
        g.append(f'<text x="18" y="{dy+30}" font-family="{FONT}" font-size="17" font-weight="700" fill="#fff">{t}</text>')
        g.append(f'<text x="18" y="{dy+54}" font-family="{FONT}" font-size="13" fill="#E3F2FD">{s}</text>')
    g.append(f'<text x="0" y="280" font-family="{FONT}" font-size="12" fill="{C_MUTED}">开题扩展 HC-SR04 / WS2812B / littlefs 未全量落地</text>')
    return "\n".join(g)


def diag_threads() -> str:
    boxes = [(0, 0, 240, 64, "LVGL 主线程", C_PRIMARY), (260, 0, 240, 64, "sound_task", C_DARK),
             (0, 78, 240, 64, "led_task", C_DARK), (260, 78, 240, 64, "key_task", C_DARK),
             (0, 156, 500, 64, "versus_rx_task · UDP 非阻塞", C_GOLD)]
    g = []
    for x, y, w, h, t, c in boxes:
        g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{c}"/>')
        g.append(f'<text x="{x+14}" y="{y+38}" font-family="{FONT}" font-size="15" font-weight="700" fill="#fff">{t}</text>')
    return "\n".join(g)


def diag_versus() -> str:
    return f"""
    <rect x="0" y="0" width="160" height="180" rx="14" fill="{C_PRIMARY}"/>
    <use href="#ico-chip" x="12" y="12" width="32" height="32"/>
    <text x="80" y="70" text-anchor="middle" font-family="{FONT}" font-size="17" font-weight="700" fill="#fff">设备 A</text>
    <text x="80" y="98" text-anchor="middle" font-family="{FONT}" font-size="12" fill="#E3F2FD">UDP :43045</text>
    <rect x="340" y="0" width="160" height="180" rx="14" fill="{C_PRIMARY}"/>
    <use href="#ico-chip" x="352" y="12" width="32" height="32"/>
    <text x="420" y="70" text-anchor="middle" font-family="{FONT}" font-size="17" font-weight="700" fill="#fff">设备 B</text>
    <text x="420" y="98" text-anchor="middle" font-family="{FONT}" font-size="12" fill="#E3F2FD">UDP :43046</text>
    <line x1="160" y1="90" x2="340" y2="90" stroke="{C_GOLD}" stroke-width="4" marker-end="url(#arr)"/>
    <line x1="340" y1="120" x2="160" y2="120" stroke="{C_GOLD}" stroke-width="3" stroke-dasharray="8 6" marker-end="url(#arr)"/>
    <rect x="120" y="200" width="260" height="36" rx="8" fill="{C_CLOUD}"/>
    <text x="250" y="223" text-anchor="middle" font-family="{FONT}" font-size="13" font-weight="600" fill="{C_INK}">START · SCORE · FINISH</text>
    <text x="250" y="260" text-anchor="middle" font-family="{FONT}" font-size="11" fill="{C_MUTED}">24B · CRC · 双板全屏</text>
    """


def diag_levels_panel() -> str:
    g = []
    levels = [("L1 基础 WhackMole", 100, C_OK), ("L2 多模态输入", 30, C_WARN), ("L3 闯关 + 联机", 70, C_OK),
              ("L4 声光 / 存储", 50, C_WARN), ("L5 UI + WiFi", 40, C_WARN)]
    y = 0
    for lab, pct, col in levels:
        g.append(progress_bar(0, y, 500, lab, pct, col))
        y += 46
    g.append(f'<rect x="0" y="250" width="500" height="64" rx="12" fill="{C_DARK}"/>')
    g.append(f'<text x="250" y="290" text-anchor="middle" font-family="{FONT}" font-size="24" font-weight="700" fill="{C_GOLD}">综合完成度约 60%</text>')
    return "\n".join(g)


def diag_event_flow() -> str:
    return f"""
    <text x="0" y="16" font-family="{FONT}" font-size="13" font-weight="700" fill="{C_OK}">✓ 已实现</text>
    <rect x="0" y="28" width="230" height="52" rx="10" fill="{C_OK}"/><text x="14" y="60" font-family="{FONT}" font-size="13" fill="#fff">触摸 → mole_click</text>
    <rect x="250" y="28" width="230" height="52" rx="10" fill="{C_OK}"/><text x="264" y="60" font-family="{FONT}" font-size="13" fill="#fff">K1 → START</text>
    <text x="0" y="110" font-family="{FONT}" font-size="13" font-weight="700" fill="{C_NO}">× 规划</text>
    <rect x="0" y="122" width="230" height="52" rx="10" fill="{C_NO}"/><text x="14" y="154" font-family="{FONT}" font-size="13" fill="#fff">统一事件队列</text>
    <rect x="250" y="122" width="230" height="52" rx="10" fill="{C_NO}"/><text x="264" y="154" font-family="{FONT}" font-size="13" fill="#fff">HC-SR04 映射</text>
    <rect x="60" y="200" width="380" height="80" rx="12" fill="{C_PRIMARY}" opacity="0.9"/>
    <text x="250" y="236" text-anchor="middle" font-family="{FONT}" font-size="15" font-weight="700" fill="#fff">versus 联机通道独立</text>
    <text x="250" y="262" text-anchor="middle" font-family="{FONT}" font-size="12" fill="#E3F2FD">报文与板内事件互不干扰</text>
    """


def diag_multimodal() -> str:
    modes = [("触摸屏", "9洞+锤子", C_OK), ("K1", "START", C_WARN), ("K2/超声/队列", "未实现", C_NO)]
    g = []
    y = 0
    for t, s, c in modes:
        g.append(f'<rect x="0" y="{y}" width="500" height="56" rx="10" fill="{c}"/>')
        g.append(f'<text x="16" y="{y+24}" font-family="{FONT}" font-size="15" font-weight="700" fill="#fff">{t}</text>')
        g.append(f'<text x="16" y="{y+44}" font-family="{FONT}" font-size="12" fill="#E3F2FD">{s}</text>')
        y += 66
    return "\n".join(g)


def diag_ip_lock() -> str:
    return f"""
    <rect x="0" y="0" width="500" height="100" rx="10" fill="#1E293B"/>
    <text x="16" y="36" font-family="Consolas, monospace" font-size="14" fill="#86EFAC">peer_ip = "192.168.137.91";</text>
    <text x="16" y="62" font-family="Consolas, monospace" font-size="14" fill="#86EFAC">ports 43046 / 43045</text>
    <text x="16" y="88" font-family="Consolas, monospace" font-size="12" fill="{C_MUTED}">MyWhackMole.c L1103</text>
    """ + "".join(
        f'<rect x="{i*125}" y="120" width="110" height="48" rx="8" fill="{C_PRIMARY if i<3 else C_GOLD}"/>'
        f'<text x="{i*125+55}" y="150" text-anchor="middle" font-family="{FONT}" font-size="11" fill="#fff">{s}</text>'
        for i, s in enumerate(["改宏", "编译", "烧录", "conf"])
    )


def diag_sound_led() -> str:
    return f"""
    <rect x="0" y="0" width="240" height="200" rx="12" fill="{C_PRIMARY}"/>
    <text x="20" y="36" font-family="{FONT}" font-size="16" font-weight="700" fill="#fff">sound_task</text>
    <text x="20" y="64" font-family="{FONT}" font-size="12" fill="#E3F2FD">hit.wav · aplay</text>
    <text x="20" y="88" font-family="{FONT}" font-size="11" fill="#E3F2FD">8 wav / 1 已挂钩</text>
    <rect x="260" y="0" width="240" height="200" rx="12" fill="{C_WARN}"/>
    <text x="280" y="36" font-family="{FONT}" font-size="16" font-weight="700" fill="#fff">led_task GPIO</text>
    <text x="280" y="64" font-family="{FONT}" font-size="12" fill="#FFF7ED">120ms 闪烁</text>
    <text x="280" y="88" font-family="{FONT}" font-size="11" fill="#FFF7ED">WS2812B 已降级</text>
    """


def diag_storage() -> str:
    return f"""
    <rect x="0" y="0" width="500" height="90" rx="12" fill="{C_PRIMARY}"/>
    <text x="18" y="36" font-family="{FONT}" font-size="16" font-weight="700" fill="#fff">/data/whackmole_stats.dat</text>
    <text x="18" y="62" font-family="{FONT}" font-size="12" fill="#E3F2FD">最高 · 连击 · 局数 · 联机统计</text>
    <rect x="0" y="110" width="500" height="70" rx="12" fill="{C_DARK}"/>
    <text x="18" y="152" font-family="{FONT}" font-size="14" fill="#fff">STATS 弹窗只读 · 替代排行榜 Tab</text>
    """


def diag_wifi_ui() -> str:
    return f"""
    <rect x="0" y="0" width="500" height="220" rx="14" fill="#fff" stroke="{C_PRIMARY}" stroke-width="2"/>
    <text x="20" y="36" font-family="{FONT}" font-size="18" font-weight="700" fill="{C_DARK}">Wi-Fi 配置</text>
    <rect x="20" y="52" width="460" height="32" rx="6" fill="{C_CLOUD}"/><text x="32" y="73" font-family="{FONT}" font-size="13" fill="{C_MUTED}">SSID</text>
    <rect x="20" y="94" width="460" height="32" rx="6" fill="{C_CLOUD}"/><text x="32" y="115" font-family="{FONT}" font-size="13" fill="{C_MUTED}">密码</text>
    <rect x="20" y="140" width="100" height="36" rx="8" fill="{C_PRIMARY}"/><text x="70" y="163" text-anchor="middle" font-family="{FONT}" font-size="12" fill="#fff">SCAN</text>
    <rect x="130" y="140" width="100" height="36" rx="8" fill="{C_OK}"/><text x="180" y="163" text-anchor="middle" font-family="{FONT}" font-size="12" fill="#fff">CONNECT</text>
    <use href="#ico-wifi" x="400" y="130" width="48" height="48"/>
    """


def diag_combo() -> str:
    items = [("黄金 +5", C_GOLD), ("炸弹 -2", C_NO), ("COMBO ×3 +1", C_PRIMARY), ("×10 +5", C_DARK)]
    g = []
    y = 0
    for t, c in items:
        g.append(f'<rect x="0" y="{y}" width="500" height="48" rx="10" fill="{c}"/>')
        g.append(f'<text x="18" y="{y+30}" font-family="{FONT}" font-size="15" font-weight="700" fill="#fff">{t}</text>')
        y += 56
    return "\n".join(g)


def diag_git() -> str:
    nodes = ["feature", "开发", "Review", "合并", "main"]
    g = []
    for i, n in enumerate(nodes):
        x = i * 98
        g.append(f'<rect x="{x}" y="40" width="88" height="44" rx="8" fill="{C_PRIMARY if i<4 else C_OK}"/>')
        g.append(f'<text x="{x+44}" y="67" text-anchor="middle" font-family="{FONT}" font-size="11" fill="#fff">{n}</text>')
        if i < 4:
            g.append(f'<line x1="{x+88}" y1="62" x2="{x+98}" y2="62" stroke="{C_GOLD}" stroke-width="3" marker-end="url(#arr)"/>')
    return "\n".join(g)


def slide_cover() -> str:
    body = f"""
    <polygon points="0,0 540,0 440,{H} 0,{H}" fill="url(#coverGrad)"/>
    <polygon points="520,0 {W},0 {W},{H} 380,{H}" fill="{C_DARK}" opacity="0.92"/>
    <rect x="515" y="72" width="6" height="440" fill="url(#goldGrad)" rx="3"/>
    {wave_bg(0.18)}
    <text x="560" y="188" font-family="{FONT}" font-size="54" font-weight="700" fill="#fff">SmartMole Pro</text>
    <text x="560" y="258" font-family="{FONT}" font-size="28" fill="{C_GOLD}">多模态感知智能打地鼠竞技系统</text>
    <text x="560" y="306" font-family="{FONT}" font-size="16" fill="#E3F2FD">OpenVela (NuttX RTOS) · 课程设计答辩 · 结题版</text>
    <rect x="560" y="334" rx="12" width="520" height="46" fill="{C_PRIMARY}" filter="url(#shadow)"/>
    <text x="820" y="364" text-anchor="middle" font-family="{FONT}" font-size="15" font-weight="700" fill="#fff">综合完成度约 60%  ·  ✓ / ⚠ / × 如实标注</text>
    <text x="44" y="548" font-family="{FONT}" font-size="16" fill="#fff">
      <tspan x="44" dy="0">第六组</tspan>
      <tspan x="44" dy="28">张恒基 · 曹佳轩 · 缪钰</tspan>
      <tspan x="44" dy="28">郭志罡 · 张耀辉 · 朱辰骏</tspan>
    </text>
    {diagram_frame(720, 130, 520, 380, illust_mole_board())}
    <circle cx="1180" cy="100" r="90" fill="{C_SKY}" opacity="0.12"/>
    """
    return wrap(body)


def slide_content(num, section, title, items, diagram_fn=None, split=False) -> str:
    body = header(title, section, num)
    if split and diagram_fn:
        body += bullets(52, 108, items, max_w=560)
        body += diagram_frame(668, 98, 560, 540, diagram_fn())
    elif diagram_fn:
        body += bullets(52, 108, items[:4])
        body += diagram_frame(52, 268, 1176, 370, diagram_fn())
    else:
        body += bullets(52, 108, items)
    return wrap(body)


def slide_highlights(num: int) -> str:
    cards_data = [
        ("五级闯关 ✓", "LEVEL 1–5", C_OK, None), ("Wi-Fi 联机 ✓", "UDP versus", C_OK, "ico-wifi"),
        ("特殊地鼠 ✓", "COMBO", C_GOLD, "ico-hammer"), ("游戏 UI ✓", "9洞+5按钮", C_PRIMARY, None),
        ("WiFi 菜单 ✓", "wifi_ui.c", C_PRIMARY, "ico-wifi"), ("声光反馈 ⚠", "GPIO降级", C_WARN, None),
    ]
    body = header("已实现技术亮点（结题视角）", "背景与目标", num)
    x0, y0, cw, ch, gx, gy = 52, 100, 360, 82, 24, 22
    for i, (t, d, c, ic) in enumerate(cards_data):
        r, col = divmod(i, 2)
        body += card(x0 + col * (cw + gx), y0 + r * (ch + gy), cw, ch, t, d, c, ic)
    body += f"""
    <g transform="translate(780,100)" filter="url(#shadow)">
      <rect width="448" height="520" rx="20" fill="url(#coverGrad)"/>
      <text x="224" y="48" text-anchor="middle" font-family="{FONT}" font-size="22" font-weight="700" fill="#fff">核心交付</text>
      <text x="224" y="78" text-anchor="middle" font-family="{FONT}" font-size="13" fill="#E3F2FD">闯关 · 联机 · UI · WiFi</text>
      {ring_chart(224, 280, 100, 60, "结题完成度")}
      <rect x="40" y="420" width="368" height="72" rx="10" fill="rgba(255,255,255,0.12)"/>
      <text x="224" y="452" text-anchor="middle" font-family="{FONT}" font-size="13" fill="#fff">✓ 联机可演示 · ⚠ 多模态/声光降级</text>
      <text x="224" y="476" text-anchor="middle" font-family="{FONT}" font-size="13" fill="#E3F2FD">× 超声 / WS2812B / 排行榜</text>
    </g>
    """
    return wrap(body)


def slide_table(num, section, title, headers, rows, accent_col=2) -> str:
    body = header(title, section, num)
    tx, ty = 52, 100
    col_w = [180, 200, 80, 280] if len(headers) == 4 else ([140, 380, 280] if len(headers) == 3 and headers[-1] == "备注" else [160, 520, 120])
    rh = 38
    tw = sum(col_w)
    body += f'<rect x="{tx-4}" y="{ty-4}" width="{tw+8}" height="{rh*(len(rows)+1)+8}" rx="12" fill="#fff" filter="url(#shadow)"/>'
    x = tx
    for i, h in enumerate(headers):
        body += f'<rect x="{x}" y="{ty}" width="{col_w[i]}" height="{rh}" fill="url(#hdrGrad)"/>'
        body += f'<text x="{x+14}" y="{ty+25}" font-family="{FONT}" font-size="12" font-weight="700" fill="#fff">{esc(h)}</text>'
        x += col_w[i]
    y = ty + rh
    for ri, row in enumerate(rows):
        bg = C_CLOUD if ri % 2 else "#fff"
        x = tx
        for ci, val in enumerate(row):
            fc = C_BODY
            if ci == accent_col and val in ("✓", "⚠", "×"):
                fc = {"✓": C_OK, "⚠": C_WARN, "×": C_NO}[val]
            body += f'<rect x="{x}" y="{y}" width="{col_w[ci]}" height="{rh}" fill="{bg}"/>'
            body += f'<text x="{x+14}" y="{y+25}" font-family="{FONT}" font-size="11" fill="{fc}">{esc(val)}</text>'
            x += col_w[ci]
        y += rh
    return wrap(body)


def slide_timeline(num: int) -> str:
    body = header("四周里程碑 · 实际达成", "团队与计划", num)
    items = [(120, "4/27", "基础 WhackMole", "✓", C_OK), (380, "5/11", "闯关+联机", "✓", C_OK),
             (640, "5/11", "全模块联调", "⚠", C_WARN), (900, "6/8", "结题+PPT", "…", C_PRIMARY)]
    body += f'<rect x="60" y="168" width="1060" height="160" rx="16" fill="url(#panelGrad)" filter="url(#shadow)"/>'
    body += f'<line x1="100" y1="248" x2="1080" y2="248" stroke="{C_PRIMARY}" stroke-width="4"/>'
    for x, date, tit, st, col in items:
        body += f'<circle cx="{x}" cy="248" r="18" fill="{col}" filter="url(#glow)"/>'
        body += f'<text x="{x}" y="288" text-anchor="middle" font-family="{FONT}" font-size="12" fill="{C_MUTED}">{date}</text>'
        body += f'<text x="{x}" y="312" text-anchor="middle" font-family="{FONT}" font-size="14" font-weight="600" fill="{C_INK}">{esc(tit)}</text>'
        body += f'<text x="{x}" y="340" text-anchor="middle" font-family="{FONT}" font-size="18" font-weight="700" fill="{col}">{st}</text>'
    body += bullets(80, 400, ["待补：IP外置 · 8音效 · 超声波 · 排行榜 Tab"], size=15)
    return wrap(body)


def slide_innovation(num: int) -> str:
    body = header("技术创新 · 与基础实验对比", "技术创新", num)
    pairs = [("输入", "单一触摸", "触摸+K1", 0.2, 0.65), ("难度", "固定", "五级闯关", 0.15, 0.8),
             ("模式", "单机", "Wi-Fi双板", 0.1, 0.9), ("反馈", "屏幕", "GPIO+音效", 0.2, 0.7),
             ("数据", "无", "storage", 0.05, 0.75), ("联机", "无", "UDP versus", 0.0, 0.95)]
    y = 108
    for label, base, pro, b_pct, p_pct in pairs:
        body += f'<text x="52" y="{y+18}" font-family="{FONT}" font-size="14" font-weight="600" fill="{C_INK}">{label}</text>'
        body += f'<rect x="160" y="{y}" width="220" height="20" rx="6" fill="{C_CLOUD}"/>'
        body += f'<rect x="160" y="{y}" width="{int(220*b_pct)}" height="20" rx="6" fill="{C_MUTED}"/>'
        body += f'<rect x="420" y="{y}" width="320" height="20" rx="6" fill="{C_CLOUD}"/>'
        body += f'<rect x="420" y="{y}" width="{int(320*p_pct)}" height="20" rx="6" fill="{C_PRIMARY}"/>'
        body += f'<text x="760" y="{y+15}" font-family="{FONT}" font-size="11" fill="{C_PRIMARY}">{esc(pro)}</text>'
        body += f'<path d="M382 {y+10} L408 {y+10}" stroke="{C_GOLD}" stroke-width="2" marker-end="url(#arr)"/>'
        y += 48
    body += f'<text x="160" y="400" font-family="{FONT}" font-size="11" fill="{C_MUTED}">基础 WhackMole</text>'
    body += f'<text x="420" y="400" font-family="{FONT}" font-size="11" font-weight="700" fill="{C_PRIMARY}">SmartMole Pro</text>'
    return wrap(body)


def slide_completion(num: int) -> str:
    body = header("开题目标 vs 实际交付（12 项）", "完成度对照", num)
    items = [("音效", "⚠"), ("LED", "⚠"), ("Wi-Fi 联机", "✓"), ("五级闯关", "✓"), ("特殊地鼠", "✓"), ("游戏 UI", "✓"),
             ("WiFi 菜单", "✓"), ("存储", "⚠"), ("HC-SR04", "×"), ("AI 难度", "×"), ("WS2812B", "×"), ("排行榜", "×")]
    for i, (name, st) in enumerate(items):
        r, c = divmod(i, 3)
        x, y = 52 + c * 396, 108 + r * 128
        col = {"✓": C_OK, "⚠": C_WARN, "×": C_NO}[st]
        body += f"""
        <g filter="url(#shadow)">
          <rect x="{x}" y="{y}" width="368" height="96" rx="14" fill="#fff" stroke="{col}" stroke-width="2"/>
          <rect x="{x}" y="{y}" width="6" height="96" fill="{col}" rx="3"/>
          <text x="{x+24}" y="{y+42}" font-family="{FONT}" font-size="17" font-weight="700" fill="{C_INK}">{esc(name)}</text>
          <circle cx="{x+310}" cy="{y+48}" r="26" fill="{col}" opacity="0.15"/>
          <text x="{x+310}" y="{y+56}" text-anchor="middle" font-family="{FONT}" font-size="26" font-weight="700" fill="{col}">{st}</text>
        </g>
        """
    return wrap(body)


def slide_closing() -> str:
    body = f"""
    <rect width="{W}" height="{H}" fill="url(#coverGrad)"/>
    {wave_bg(0.22)}
    <text x="640" y="110" text-anchor="middle" font-family="{FONT}" font-size="44" font-weight="700" fill="#fff">总结与展望</text>
    <rect x="590" y="128" width="100" height="5" fill="url(#goldGrad)" rx="2"/>
    """
    items = [("成果", "五级闯关 + 双板 Wi-Fi 联机可稳定演示"), ("沉淀", "NuttX · UDP · LVGL · wapi"),
             ("待补", "IP外置 · 音效 · 超声波 · 排行榜"), ("展望", "versus.conf · 云端排行 · AI微调")]
    y = 168
    for label, text in items:
        body += f"""
        <rect x="140" y="{y}" width="1000" height="76" rx="14" fill="#fff" filter="url(#shadow)"/>
        <rect x="140" y="{y}" width="8" height="76" fill="{C_GOLD}" rx="4"/>
        <text x="172" y="{y+30}" font-family="{FONT}" font-size="14" font-weight="700" fill="{C_PRIMARY}">{label}</text>
        <text x="260" y="{y+46}" font-family="{FONT}" font-size="16" fill="{C_INK}">{esc(text)}</text>
        """
        y += 92
    body += f'<text x="640" y="610" text-anchor="middle" font-family="{FONT}" font-size="26" font-weight="700" fill="{C_GOLD}">THANKS · SmartMole Pro 第六组</text>'
    return wrap(body)


def build_slides() -> list[tuple[str, str]]:
    s: list[tuple[str, str]] = []
    s.append(("01-cover.svg", slide_cover()))
    s.append(("02-motivation.svg", slide_content(2, "背景与目标", "项目背景与动机（起-痛-机-愿）", [
        "起：WhackMole + OpenVela/NuttX 可运行", "痛：无联机、无声光、无持久化",
        "机：T113S3 Wi-Fi/音频/GPIO", "愿：闯关 + 双板联机答辩系统"], illust_mole_board, True)))
    s.append(("03-levels.svg", slide_content(3, "背景与目标", "五层目标体系（结题对照）", [
        "L1 基础 — ✓ 100%", "L2 多模态 — ⚠ 30%", "L3 闯关联机 — ✓ 70%", "L4 声光 — ⚠ 50%", "L5 UI — ⚠ 40%"], diag_levels_panel, True)))
    s.append(("04-highlights.svg", slide_highlights(4)))
    s.append(("05-architecture.svg", slide_content(5, "系统架构", "三层架构（实际实现）", [
        "用户交互：触摸+K1+LVGL", "应用逻辑：状态机+storage+versus", "驱动层：NuttX/GPIO/wapi"], diag_layers, True)))
    s.append(("06-threads.svg", slide_content(6, "系统架构", "多线程并发模型", [
        "LVGL 主线程 UI+逻辑", "sound/led/key 独立任务", "versus_rx UDP 收包", "标志位不阻塞 GUI"], diag_threads, True)))
    s.append(("07-event-flow.svg", slide_content(7, "系统架构", "输入与事件流", [
        "✓ 触摸 → mole_click_event", "✓ K1 → start_game_request", "× 统一 hit_event_t 队列", "× HC-SR04 距离映射"], diag_event_flow, True)))
    s.append(("08-levels-game.svg", slide_content(8, "核心模块", "五级闯关系统 ✓", [
        "LEVEL 1–5 独立参数", "LEVEL 按钮循环选关", "黄金15%/炸弹5%", "level_configs L52–58"], illust_mole_board, True)))
    s.append(("09-multimodal.svg", slide_content(9, "核心模块", "多模态输入 ⚠", [
        "✓ 触摸屏 9洞+锤子", "⚠ K1 key_task START", "× K2 半区映射", "× HC-SR04/事件队列"], diag_multimodal, True)))
    s.append(("10-versus.svg", slide_content(10, "核心模块", "Wi-Fi 双板联机 ✓", [
        "versus（张耀辉）", "R528 UDP · START/SCORE/FINISH", "finish_from_peer · IP 外置", "双板各自全屏"], diag_versus, True)))
    s.append(("11-ip-lock.svg", slide_content(11, "核心模块", "联机 IP 锁定与方案", [
        "peer_ip 192.168.137.91", "43046/43045 端口", "换板：改宏→编译→烧录", "后续 versus.conf"], diag_ip_lock, True)))
    s.append(("12-sound-led.svg", slide_content(12, "核心模块", "声光反馈 ⚠（降级）", [
        "8 wav 仅 hit.wav 挂钩", "aplay hw:audiocodec", "GPIO LED 120ms", "WS2812B 时序未调通"], diag_sound_led, True)))
    s.append(("13-storage.svg", slide_content(13, "核心模块", "数据存储 ⚠", [
        "whackmole_stats.dat", "最高/连击/局数/联机", "STATS 弹窗只读", "未做 littlefs 排行榜"], diag_storage, True)))
    s.append(("14-wifi-ui.svg", slide_content(14, "核心模块", "WiFi 图形连接 ✓", [
        "wifi_ui.c LVGL 弹窗", "SCAN → wifi_scan.txt", "CONNECT wapi+renew", "演示镜像已就绪"], diag_wifi_ui, True)))
    s.append(("15-combo.svg", slide_content(15, "核心模块", "特殊地鼠 + COMBO ✓", [
        "黄金+5 炸弹-2", "COMBO 3/5/10 奖励", "联机简化计分", "L998–1048"], diag_combo, True)))
    s.append(("16-hardware.svg", slide_table(16, "硬件与成本", "硬件方案与降级矩阵", ["模块", "选型", "状态", "降级"], [
        ["超声波", "HC-SR04", "×", "触摸+K1"], ["灯效", "WS2812B", "×", "GPIO LED"], ["按键", "K1/K2", "⚠", "触摸为主"],
        ["Wi-Fi", "板载 STA", "✓", "wifi_ui"], ["存储", "文件", "⚠", "STATS"], ["开发板", "T113S3", "✓", "—"]])))
    s.append(("17-team.svg", slide_table(17, "团队与计划", "人员分工（开题方案）", ["成员", "负责模块", "备注"], [
        ["张恒基", "系统总架构+全局集成", "项目负责人"],
        ["曹佳轩", "多模态输入+驱动", "外设/辅助前端"],
        ["缪钰", "声光+GUI+UI", "UI 核心"],
        ["郭志罡", "关卡+AI+特殊地鼠", "核心框架"],
        ["张耀辉", "Wi-Fi联机+versus", "versus 核心"],
        ["朱辰骏", "存储+排行榜+成就", "联调+storage"],
    ])))
    s.append(("18-collab.svg", slide_content(18, "团队与计划", "协作机制", [
        "versus 核心冻结", "storage.h/wifi_ui.h 接入", "Git feature→review→合并", "文档四件套 docs/*.typ"], diag_git, True)))
    s.append(("19-timeline.svg", slide_timeline(19)))
    s.append(("20-completion.svg", slide_completion(20)))
    s.append(("21-innovation.svg", slide_innovation(21)))
    s.append(("22-closing.svg", slide_closing()))
    return s


def main():
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    slides = build_slides()
    for name, content in slides:
        (SVG_DIR / name).write_text(content, encoding="utf-8")
        print(f"  OK {name}")
    import json
    (SVG_DIR / "manifest.json").write_text(json.dumps([n for n, _ in slides], ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Generated {len(slides)} SVG → {SVG_DIR}")


if __name__ == "__main__":
    main()
