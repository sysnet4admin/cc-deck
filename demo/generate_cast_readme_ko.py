#!/usr/bin/env python3
"""cc-deck demo — fuzzy search + TODO/PIN + Tab mode cycle (Korean, README size)"""
import json, sys

W, H = 130, 17
events = []
t = 0.0

R    = "\033[0m"
REV  = "\033[7m"
GRN  = "\033[32m"
YLW  = "\033[1;33m"
MAG  = "\033[1;35m"
WHT  = "\033[97m"
GRY  = "\033[90m"
CYN  = "\033[36m"
BLU  = "\033[1;34m"
RED  = "\033[1;31m"
ORG  = "\033[1;38;2;217;119;87m"   # Claude Code brand orange

MODES = [
    ("claude",          ORG),
    ("claude-api",      BLU),
    ("claude+skip",     RED),
    ("claude-api+skip", CYN),
]

def make_header(mode_label="claude", mode_color=None):
    mc = mode_color or ORG
    return (
        f"{YLW}[TODO]{R}=auto-pinned  {MAG}[PIN]{R}=manual | "
        f"^K: pin  ^R: rm  Tab: cycle  F1: help  ESC: quit | "
        f"{mc}[{mode_label}]{R}"
    )

def out(data, dt=0.04):
    global t
    t += dt
    events.append([round(t, 4), "o", data])

def pause(dt): global t; t += dt
def nl(): out("\r\n", 0.01)
def type_chars(text, delay=0.09):
    for c in text:
        out(c, delay)

GRN2       = "\033[1;32m"
TODO_ITEM  = f"{YLW}[TODO] {R}/tmp/projects/infra/k8s: 3Gi 적용 후 2주간 OOMKill 재발 여부 모니터링                    "
PIN_ITEM   = f"{MAG}[PIN]  {R}/tmp/projects/api-server: 배포 이후 메모리 사용량 계속 증가 — 원인 찾아줘               "
QUICK_ITEM = f"{GRN2}[Quick]{R} ▶ 2 sessions                                                                           "
SEP_ITEM   = f"{GRY}────────────────────────────────────────────────────────────────────────────────────────{R}         "

ALL_SESSIONS = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}배포 이후 메모리 사용량 계속 증가 — 원인 찾아줘{R}",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}스케일 업 후 pod OOMKill 계속 남 — 로그 분석해줘{R}",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}로그인 폼 validation이 Safari에서만 깨짐 — 수정해줘{R}",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}세션 토큰을 JWT로 리팩토링 — 미들웨어부터 시작{R}",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}결제 API용 Grafana SLO 알림 설정{R}",
]

OOM_SESSIONS = [
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}스케일 업 후 pod OOMKill 계속 남 — 로그 분석해줘{R}",
]

def draw_fzf(items, query="", selected=0, info_count=None, mode_label="claude", mode_color=None):
    mc = mode_color or ORG
    out("\033[2J\033[H", 0.01)
    out(f"  {GRN}cc-deck>{R} {CYN}{query}{R}\033[?25l", 0.01); nl()
    out(make_header(mode_label, mc), 0.01); nl()
    count = info_count or len(items)
    info_left = f"  {count}/100"
    mode_tag  = f"[{mode_label}]"
    pad = max(0, W - len(info_left) - len(mode_tag) - 2)
    out(f"{GRY}{info_left}{R}{' ' * pad}{mc}{mode_tag}{R}", 0.01); nl()
    for i, item in enumerate(items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

def draw_fzf_pinned(pinned, sep, sessions, query="", selected=0, mode_label="claude", mode_color=None):
    mc = mode_color or ORG
    out("\033[2J\033[H", 0.01)
    out(f"  {GRN}cc-deck>{R} {CYN}{query}{R}\033[?25l", 0.01); nl()
    out(make_header(mode_label, mc), 0.01); nl()
    all_items = pinned + [sep] + sessions
    info_left = f"  {len(all_items)}/100"
    mode_tag  = f"[{mode_label}]"
    pad = max(0, W - len(info_left) - len(mode_tag) - 2)
    out(f"{GRY}{info_left}{R}{' ' * pad}{mc}{mode_tag}{R}", 0.01); nl()
    for i, item in enumerate(all_items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

def comment(text, pre=1.0, post=1.2):
    pause(pre)
    out("\033[2J\033[H", 0.01)
    out(f"{GRY}# {text}{R}\r\n", 0.01)
    pause(post)

# ── SCENE 0: TODO ─────────────────────────────────────────────────────────────
comment("0. Claude에게 TODO 기록 요청 → cc-deck 상단에 자동 고정", pre=0.5, post=1.2)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01)
pause(0.3); type_chars("claude", 0.08); pause(0.3)
out("\r\n", 0.04); pause(0.4)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R}\r\n", 0.02)
out(f"{GRY}╭─{R} User\r\n{GRY}│{R}  ", 0.01)
type_chars("3Gi 적용했어. 2주간 OOMKill 재발 여부 모니터링 — TODO로 기록해줘", 0.04)
out(f"\r\n{GRY}╰─{R}\r\n", 0.02); pause(0.5)
out(f"{GRY}╭─{R} Claude\r\n{GRY}│{R}  기록했습니다. {GRY}메모리 1개 저장됨 (ctrl+o로 확인){R}\r\n{GRY}╰─{R}\r\n", 0.03)
pause(0.6)
out(f"\r\n{GRY}❯ /quit{R}\r\n", 0.03); pause(0.5)

out(f"\r\n{GRN}~/projects/infra/k8s{R} $ ", 0.01); pause(0.4)
type_chars("cc-deck"); pause(0.3); out("\r\n", 0.05); pause(0.2)
draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0); pause(1.2)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/projects/infra/k8s{R} $ cc-deck\r\ncd /tmp/projects/infra/k8s\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — 세션 재개\r\n{GRY}✓{R} 3Gi 적용했어. 2주간 OOMKill 재발 여부...\r\n", 0.03)
pause(1.0)

# ── SCENE 1: 퍼지 검색 ───────────────────────────────────────────────────────
comment("1. 퍼지 검색 — 입력하면 실시간으로 세션 필터링", pre=1.2, post=1.2)

out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ ", 0.01); pause(0.5)
type_chars("cc-deck"); pause(0.3); out("\r\n", 0.05); pause(0.2)
draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0); pause(0.8)
draw_fzf([TODO_ITEM] + ALL_SESSIONS, query="O", selected=0); pause(0.25)
draw_fzf([TODO_ITEM] + ALL_SESSIONS, query="OO", selected=0); pause(0.2)
draw_fzf([TODO_ITEM] + OOM_SESSIONS, query="OOM", selected=0, info_count=2); pause(1.0)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ cc-deck\r\ncd /tmp/projects/infra/k8s\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — 세션 재개\r\n{GRY}✓{R} 스케일 업 후 pod OOMKill 계속 남...\r\n", 0.03)
pause(1.0)

# ── SCENE 2: Tab 모드 순환 ────────────────────────────────────────────────────
comment("2. Tab으로 실행 모드 순환 — 헤더에 현재 모드 표시", pre=1.2, post=1.2)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01); pause(0.4)
type_chars("cc-deck"); pause(0.3); out("\r\n", 0.05); pause(0.2)
for label, color in MODES:
    draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0, mode_label=label, mode_color=color)
    pause(0.9)
draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0); pause(0.8)

# ── SCENE 3: TODO + PIN + Quick 상단 고정 ────────────────────────────────────
comment("3. TODO + PIN + Quick 세션 모두 상단 고정", pre=1.2, post=1.2)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01); pause(0.4)
type_chars("cc-deck"); pause(0.3); out("\r\n", 0.05); pause(0.2)
draw_fzf_pinned(pinned=[TODO_ITEM, PIN_ITEM, QUICK_ITEM], sep=SEP_ITEM, sessions=ALL_SESSIONS, selected=2)
pause(1.2)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/projects/infra/k8s{R} $ cc-deck\r\ncd /tmp/projects/api-server\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — 세션 재개\r\n{GRY}✓{R} 배포 이후 메모리 사용량 계속 증가...\r\n", 0.03)
pause(1.0)

# ── SCENE 4: cc-deck -q 빠른 질문 ────────────────────────────────────────────
comment("4. cc-deck -q — 세션 기록 없이 즉시 질문", pre=1.2, post=1.2)

out(f"{GRN}~/projects{R} $ ", 0.01); pause(0.4)
type_chars('cc-deck -q "SIGTERM이 뭐야?"', 0.07)
pause(0.3); out("\r\n", 0.05); pause(0.8)
out(f"SIGTERM(15)은 프로세스에 정상 종료를 요청하는 신호입니다.\r\n", 0.02)
out(f"SIGKILL과 달리 프로세스가 처리하거나 무시할 수 있습니다.\r\n", 0.02)
pause(1.5)
nl()
out(f"{GRN}~/projects{R} $ ", 0.04); pause(0.4)
out(f"{GRY}│{R}", 0.04); pause(2.0)

# ── Output ────────────────────────────────────────────────────────────────────
header = {
    "version": 2, "width": W, "height": H,
    "timestamp": 1746691200,
    "title": "cc-deck 데모",
    "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}
}

out_file = sys.argv[1] if len(sys.argv) > 1 else "demo_readme_ko.cast"
with open(out_file, "w") as f:
    f.write(json.dumps(header) + "\n")
    for event in events:
        f.write(json.dumps(event) + "\n")

print(f"cast: {out_file} ({len(events)} events, {t:.1f}s)")
