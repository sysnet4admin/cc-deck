#!/usr/bin/env python3
"""cc-deck demo v2 — fuzzy search + TODO/PIN (Korean)"""
import json, sys

W, H = 100, 32
events = []
t = 0.0

R    = "\033[0m"
REV  = "\033[7m"
GRN  = "\033[32m"
YLW  = "\033[33m"
MAG  = "\033[35m"
WHT  = "\033[97m"
GRY  = "\033[90m"
CYN  = "\033[36m"

def out(data, dt=0.04):
    global t
    t += dt
    events.append([round(t, 4), "o", data])

def pause(dt): global t; t += dt
def nl(): out("\r\n", 0.01)
def type_chars(text, delay=0.09):
    for c in text:
        out(c, delay)

HEADER = f"{GRY}[TODO]{R}=auto-pinned  {GRY}[PIN]{R}=manual | Enter: {GRN}claude{R}  ^K: pin  ^D: delete(TODO/PIN)  ^O/A/S/X: mode  ESC: quit"
TODO_ITEM = f"{YLW}[TODO]{R} /tmp/projects/infra/k8s: Watch for OOMKill recurrence over the next 2 weeks              "
PIN_ITEM  = f"{MAG}[PIN] {R} /tmp/projects/api-server: memory usage keeps climbing after the last deploy — find the leak"
SEP_ITEM  = f"{GRY}────────────────────────────────────────────────────────────────────────────────────────{R}          "

ALL_SESSIONS = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}memory usage keeps climbing after the last deploy — find the leak{R}",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}pod keeps OOMKilling after we scaled up, pull the logs and diagnose{R}",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}login form validation breaks only on Safari — reproduce and fix{R}",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}refactor session tokens to JWT — start with the middleware layer{R}",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}set up Grafana SLO alerts for the payment API — p99 latency threshold{R}",
    f"  {GRY}2026-05-08 05:18{R}  /tmp/projects/data-pipeline:{WHT}Kafka consumer lag growing — find bottleneck in processing step{R}",
]

OOM_SESSIONS = [
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}pod keeps OOMKilling after we scaled up, pull the logs and diagnose{R}",
]

def draw_fzf(items, query="", selected=0, info_count=None):
    out("\033[2J\033[H", 0.01)
    out(f"  {GRN}cc-deck>{R} {CYN}{query}{R}\033[?25l", 0.01); nl()
    out(HEADER, 0.01); nl()
    count = info_count or len(items)
    out(f"{GRY}  {count}/100{R}", 0.01); nl()
    for i, item in enumerate(items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

def draw_fzf_pinned(pinned, sep, sessions, query="", selected=0):
    out("\033[2J\033[H", 0.01)
    out(f"  {GRN}cc-deck>{R} {CYN}{query}{R}\033[?25l", 0.01); nl()
    out(HEADER, 0.01); nl()
    all_items = pinned + [sep] + sessions
    out(f"{GRY}  {len(all_items)}/100{R}", 0.01); nl()
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

# ── SCENE 0: Claude 세션에서 TODO 기록 ───────────────────────────────────────
comment("0. Claude에게 TODO 기록 요청 → cc-deck 상단에 자동 고정",
        pre=0.5, post=1.2)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01)
pause(0.3)
type_chars("claude", 0.08)
pause(0.3)
out("\r\n", 0.04)
pause(0.4)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R}\r\n", 0.02)
out(f"{GRY}╭─{R} User\r\n", 0.02)
out(f"{GRY}│{R}  ", 0.01)
type_chars("3Gi 적용했어. 2주간 OOMKill 재발 여부 모니터링 — TODO로 기록해줘", 0.04)
out(f"\r\n{GRY}╰─{R}\r\n", 0.02)
pause(0.5)
out(f"{GRY}╭─{R} Claude\r\n", 0.02)
out(f"{GRY}│{R}  기록했습니다. {GRY}메모리 1개 저장됨 (ctrl+o로 확인){R}\r\n", 0.03)
out(f"{GRY}╰─{R}\r\n", 0.02)
pause(0.6)
out(f"\r\n{GRY}❯ /quit{R}\r\n", 0.03)
pause(0.5)

out(f"\r\n{GRN}~/projects/infra/k8s{R} $ ", 0.01)
pause(0.4)
type_chars("cc-deck")
pause(0.3)
out("\r\n", 0.05)
pause(0.2)

draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0)
pause(1.2)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/projects/infra/k8s{R} $ cc-deck\r\n", 0.01)
out(f"cd /tmp/projects/infra/k8s\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — 세션 재개\r\n", 0.03)
out(f"{GRY}✓{R} 3Gi 적용했어. 2주간 OOMKill 재발 여부 모니터링...\r\n", 0.03)
pause(1.0)

# ── SCENE 1: 퍼지 검색 ───────────────────────────────────────────────────────
comment("1. 퍼지 검색 — 입력하면 실시간으로 세션 필터링",
        pre=1.2, post=1.2)

out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ ", 0.01)
pause(0.5)
type_chars("cc-deck")
pause(0.3)
out("\r\n", 0.05)
pause(0.2)

draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0)
pause(0.8)

draw_fzf([TODO_ITEM] + ALL_SESSIONS, query="O", selected=0)
pause(0.25)
draw_fzf([TODO_ITEM] + ALL_SESSIONS, query="OO", selected=0)
pause(0.2)
draw_fzf([TODO_ITEM] + OOM_SESSIONS, query="OOM", selected=0, info_count=2)
pause(1.0)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ cc-deck\r\n", 0.01)
out(f"cd /tmp/projects/infra/k8s\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — 세션 재개\r\n", 0.03)
out(f"{GRY}✓{R} 스케일 업 후 pod OOMKill 계속 남...\r\n", 0.03)
pause(1.0)

# ── SCENE 2: Ctrl-K 핀 ───────────────────────────────────────────────────────
comment("2. Ctrl-K로 세션 고정 — 빠르게 돌아오고 싶은 세션 북마크",
        pre=1.2, post=1.2)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01)
pause(0.4)
type_chars("cc-deck")
pause(0.3)
out("\r\n", 0.05)
pause(0.2)

draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=1)
pause(1.0)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/projects/infra/k8s{R} $ cc-deck\r\n", 0.01)
out(f"{MAG}[cc-deck]{R} 고정됨: /tmp/projects/api-server — 배포 이후 메모리 사용량 계속 증가...\r\n", 0.04)
pause(1.0)

# ── SCENE 3: TODO + PIN 상단 고정 확인 ───────────────────────────────────────
comment("3. TODO(자동) + PIN(수동) 항상 상단 고정 — 중요한 것부터",
        pre=1.5, post=1.5)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01)
pause(0.4)
type_chars("cc-deck")
pause(0.3)
out("\r\n", 0.05)
pause(0.2)

draw_fzf_pinned(
    pinned=[TODO_ITEM, PIN_ITEM],
    sep=SEP_ITEM,
    sessions=ALL_SESSIONS,
    selected=1,
)
pause(1.2)

out("\033[2J\033[H", 0.01)
out(f"{GRN}~/projects/infra/k8s{R} $ cc-deck\r\n", 0.01)
out(f"cd /tmp/projects/api-server\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — 세션 재개\r\n", 0.03)
out(f"{GRY}✓{R} 배포 이후 메모리 사용량 계속 증가...\r\n", 0.03)
nl()
out(f"{GRN}~/projects/api-server{R} $ ", 0.04)
pause(0.4)
out(f"{GRY}│{R}", 0.04)
pause(2.0)

# ── Output ────────────────────────────────────────────────────────────────────
header = {
    "version": 2, "width": W, "height": H,
    "timestamp": 1746691200,
    "title": "cc-deck 데모 v2",
    "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}
}

out_file = sys.argv[1] if len(sys.argv) > 1 else "demo_v2_ko.cast"
with open(out_file, "w") as f:
    f.write(json.dumps(header) + "\n")
    for event in events:
        f.write(json.dumps(event) + "\n")

print(f"cast: {out_file} ({len(events)} events, {t:.1f}s)")
