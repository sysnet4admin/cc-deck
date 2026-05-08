#!/usr/bin/env python3
"""Generate asciinema v2 cast file simulating cc-deck demo (Korean)."""
import json, sys

W, H = 100, 30
events = []
t = 0.0

R    = "\033[0m"
BOLD = "\033[1m"
REV  = "\033[7m"
GRN  = "\033[32m"
YLW  = "\033[33m"
MAG  = "\033[35m"
WHT  = "\033[97m"
GRY  = "\033[90m"

def out(data, dt=0.04):
    global t
    t += dt
    events.append([round(t, 4), "o", data])

def pause(dt): global t; t += dt

def type_chars(text, delay=0.09):
    for c in text:
        out(c, delay)

def nl(): out("\r\n", 0.01)

HEADER  = f"{GRY}[TODO]{R}=자동고정  {GRY}[PIN]{R}=수동고정 | Enter: {GRN}claude{R}  ^K: 고정토글  ^O/A/D/X: 모드  ESC: 종료"
INFO    = f"{GRY}  7/100{R}"
PROMPT  = f"  {GRN}cc-deck>{R} "
SEP_ITEM = f"{GRY}────────────────────────────────────────────────────────────────────────────{R}        "

TODO_ITEM = f"{YLW}[TODO]{R} /tmp/projects/infra/k8s: 3Gi 적용 후 2주간 OOMKill 재발 여부 모니터링           "
PIN_ITEM  = f"{MAG}[PIN] {R} /tmp/projects/api-server: 롤백 없이 어떻게 수정해?                              "

SESSIONS = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}롤백 없이 어떻게 수정해?{R}                          ",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}적용했어 — OOMKill 다시 나면 알려줘{R}                ",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}수정 방법이 뭐야?{R}                                   ",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}토큰 폐기는 어떻게 해? 즉시 로그아웃이 필요해{R}      ",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}에러율 알림도 추가해줘 — 0.1% 이상이면 알림{R}         ",
    f"  {GRY}2026-05-08 05:18{R}  /tmp/projects/data-pipeline:{WHT}DB 조회를 배치로 처리해줘{R}                           ",
]

SESSIONS_WITH_PIN = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}롤백 없이 어떻게 수정해?{R}                          ",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}적용했어 — OOMKill 다시 나면 알려줘{R}                ",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}수정 방법이 뭐야?{R}                                   ",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}토큰 폐기는 어떻게 해?{R}                              ",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}에러율 알림도 추가해줘{R}                              ",
]

def draw_fzf(items, selected=0, query=""):
    out("\033[2J\033[H", 0.01)
    out(f"{PROMPT}{query}\033[?25l", 0.01); nl()
    out(HEADER, 0.01); nl()
    out(INFO, 0.01); nl()
    for i, item in enumerate(items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

def draw_fzf2(pinned_items, sep, session_items, selected=0):
    out("\033[2J\033[H", 0.01)
    out(f"{PROMPT}\033[?25l", 0.01); nl()
    out(HEADER, 0.01); nl()
    out(f"{GRY}  {len(pinned_items)+1+len(session_items)}/100{R}", 0.01); nl()
    all_items = pinned_items + [sep] + session_items
    for i, item in enumerate(all_items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

# ─── SCENE 1: 프롬프트 ────────────────────────────────────────────────────────
pause(0.5)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ ", 0.01)
pause(0.6)
type_chars("cc-deck")
pause(0.4)
out("\r\n", 0.05)
pause(0.3)

# ─── SCENE 2: fzf 열림, TODO 상단 ─────────────────────────────────────────────
items_1 = [TODO_ITEM] + SESSIONS
draw_fzf(items_1, selected=0)
pause(1.0)

# ─── SCENE 3: api-server로 이동 ───────────────────────────────────────────────
draw_fzf(items_1, selected=1)
pause(0.8)

# ─── SCENE 4: Ctrl-K 핀 추가 ──────────────────────────────────────────────────
out("\033[2J\033[H", 0.01)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ cc-deck\r\n", 0.01)
out(f"{GRY}[cc-deck]{R} 고정됨: /tmp/projects/api-server\r\n", 0.05)
pause(1.0)

# ─── SCENE 5: 두 번째 cc-deck 실행 ───────────────────────────────────────────
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ ", 0.01)
pause(0.5)
type_chars("cc-deck")
pause(0.4)
out("\r\n", 0.05)
pause(0.3)

# ─── SCENE 6: TODO + PIN 상단 고정 ────────────────────────────────────────────
draw_fzf2(
    pinned_items=[TODO_ITEM, PIN_ITEM],
    sep=SEP_ITEM,
    session_items=SESSIONS_WITH_PIN,
    selected=0,
)
pause(1.0)

# ─── SCENE 7: PIN 항목으로 이동 ───────────────────────────────────────────────
draw_fzf2(
    pinned_items=[TODO_ITEM, PIN_ITEM],
    sep=SEP_ITEM,
    session_items=SESSIONS_WITH_PIN,
    selected=1,
)
pause(1.0)

# ─── SCENE 8: 선택 후 재개 ────────────────────────────────────────────────────
out("\033[2J\033[H", 0.01)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ cc-deck\r\n", 0.01)
out(f"cd /tmp/projects/api-server\r\n", 0.05)
pause(0.4)
out(f"\r\n", 0.01)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R}", 0.02); nl()
out(f"{GRY}✓ 세션 재개: {WHT}롤백 없이 어떻게 수정해?{R}", 0.03); nl()
nl()
out(f"{GRN}~/projects/api-server{R} $ ", 0.05)
pause(0.5)
out(f"{GRY}│{R}", 0.05)
pause(2.0)

# ─── cast 출력 ────────────────────────────────────────────────────────────────
header = {
    "version": 2,
    "width": W,
    "height": H,
    "timestamp": 1746691200,
    "title": "cc-deck 데모",
    "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}
}

out_file = sys.argv[1] if len(sys.argv) > 1 else "demo_ko.cast"
with open(out_file, "w") as f:
    f.write(json.dumps(header) + "\n")
    for event in events:
        f.write(json.dumps(event) + "\n")

print(f"cast 생성 완료: {out_file} ({len(events)} events, {t:.1f}s)")
