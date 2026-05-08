#!/usr/bin/env python3
"""Generate asciinema v2 cast file simulating cc-deck demo."""
import json, sys

W, H = 100, 30
events = []
t = 0.0

R  = "\033[0m"
BOLD = "\033[1m"
DIM  = "\033[2m"
REV  = "\033[7m"        # reverse (highlight)
BLD  = "\033[1m"
CYN  = "\033[36m"
GRN  = "\033[32m"
YLW  = "\033[33m"
MAG  = "\033[35m"
BLU  = "\033[34m"
RED  = "\033[31m"
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
def clear(): out("\033[2J\033[H", 0.02)

HEADER  = f"{GRY}[TODO]{R}=auto-pinned  {GRY}[PIN]{R}=manual | Enter: {GRN}claude{R}  ^K: pin toggle  ^O/A/D/X: mode  ESC: quit"
HEADER2 = f"{GRY}[TODO]{R}=auto-pinned  {GRY}[PIN]{R}=manual | Enter: {GRN}claude{R}  ^K: pin toggle  ^O/A/D/X: mode  ESC: quit"
SEP     = f"{GRY}──────────────────────────────────────────────────────────────────────────────────────────{R}"
INFO    = f"{GRY}  7/100{R}"
PROMPT  = f"  {GRN}cc-deck>{R} "

TODO_ITEM = f"{YLW}[TODO]{R} /tmp/projects/infra/k8s: Watch for OOMKill recurrence over the next 2 weeks  "
PIN_ITEM  = f"{MAG}[PIN] {R} /tmp/projects/api-server: how do we fix it without rolling back?            "
SEP_ITEM  = f"{GRY}────────────────────────────────────────────────────────────────────────────{R}        "

SESSIONS = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}how do we fix it without rolling back?{R}  ",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}applied — monitor it and let me know if OOMKills again{R}  ",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}what's the fix?{R}  ",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}what about token revocation? we need immediate logout to work{R}  ",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}also add an error rate alert — anything above 0.1% should page{R}  ",
    f"  {GRY}2026-05-08 05:18{R}  /tmp/projects/data-pipeline:{WHT}batch the DB lookups{R}  ",
]

SESSIONS_WITH_PIN = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}how do we fix it without rolling back?{R}  ",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}applied — monitor it and let me know if OOMKills again{R}  ",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}what's the fix?{R}  ",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}what about token revocation?{R}  ",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}also add an error rate alert{R}  ",
]

def draw_fzf(items, selected=0, query="", pinned_section=False):
    """Draw fzf-like TUI."""
    out("\033[2J\033[H", 0.01)
    # Prompt
    out(f"{PROMPT}{query}\033[?25l", 0.01)
    nl()
    # Header
    out(HEADER, 0.01); nl()
    # Info
    out(INFO, 0.01); nl()
    # Items
    for i, item in enumerate(items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

def draw_fzf2(pinned_items, sep, session_items, selected=0):
    """Draw fzf with pinned section."""
    out("\033[2J\033[H", 0.01)
    out(f"{PROMPT}\033[?25l", 0.01); nl()
    out(HEADER2, 0.01); nl()
    out(f"{GRY}  {len(pinned_items) + 1 + len(session_items)}/100{R}", 0.01); nl()
    all_items = pinned_items + [sep] + session_items
    for i, item in enumerate(all_items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

# ─── SCENE 1: Prompt ──────────────────────────────────────────────────────────
pause(0.5)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ ", 0.01)
pause(0.6)
type_chars("cc-deck")
pause(0.4)
out("\r\n", 0.05)
pause(0.3)

# ─── SCENE 2: fzf opens, cursor on TODO ───────────────────────────────────────
items_1 = [TODO_ITEM] + SESSIONS
draw_fzf(items_1, selected=0)
pause(1.0)

# ─── SCENE 3: navigate down to api-server (index 1) ──────────────────────────
draw_fzf(items_1, selected=1)
pause(0.8)

# ─── SCENE 4: Ctrl-K to pin ───────────────────────────────────────────────────
out("\033[2J\033[H", 0.01)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ cc-deck\r\n", 0.01)
out(f"{GRY}[cc-deck]{R} pinned: /tmp/projects/api-server\r\n", 0.05)
pause(1.0)

# ─── SCENE 5: second cc-deck run ─────────────────────────────────────────────
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ ", 0.01)
pause(0.5)
type_chars("cc-deck")
pause(0.4)
out("\r\n", 0.05)
pause(0.3)

# ─── SCENE 6: fzf with TODO + PIN pinned ─────────────────────────────────────
draw_fzf2(
    pinned_items=[TODO_ITEM, PIN_ITEM],
    sep=SEP_ITEM,
    session_items=SESSIONS_WITH_PIN,
    selected=0,
)
pause(1.0)

# ─── SCENE 7: navigate to PIN item ───────────────────────────────────────────
draw_fzf2(
    pinned_items=[TODO_ITEM, PIN_ITEM],
    sep=SEP_ITEM,
    session_items=SESSIONS_WITH_PIN,
    selected=1,
)
pause(1.0)

# ─── SCENE 8: select and resume ──────────────────────────────────────────────
out("\033[2J\033[H", 0.01)
out(f"{GRN}~/11.Github/kuberneteslab.dev{R} $ cc-deck\r\n", 0.01)
out(f"cd /tmp/projects/api-server\r\n", 0.05)
pause(0.4)
out(f"\r\n", 0.01)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R}", 0.02); nl()
out(f"{GRY}✓ resuming session: {WHT}how do we fix it without rolling back?{R}", 0.03); nl()
nl()
out(f"{GRN}~/projects/api-server{R} $ ", 0.05)
pause(0.5)
out(f"{GRY}│{R}", 0.05)
pause(2.0)

# ─── Output cast ─────────────────────────────────────────────────────────────
header = {
    "version": 2,
    "width": W,
    "height": H,
    "timestamp": 1746691200,
    "title": "cc-deck demo",
    "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}
}

out_file = sys.argv[1] if len(sys.argv) > 1 else "demo.cast"
with open(out_file, "w") as f:
    f.write(json.dumps(header) + "\n")
    for event in events:
        f.write(json.dumps(event) + "\n")

print(f"cast file written: {out_file} ({len(events)} events, {t:.1f}s)")
