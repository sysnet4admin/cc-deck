#!/usr/bin/env python3
"""cc-deck demo — fuzzy search + TODO/PIN + Tab mode cycle + Quick (English)"""
import json, sys

W, H = 140, 31
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
ORG2 = "\033[38;5;208m"            # size-warn orange (50-100MB)

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
        f"^K: pin  ^R: rm  ^G: prune  ^E: trim  Tab: cycle  F1: help | "
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

GRN2      = "\033[1;32m"
TODO_ITEM  = f"{YLW}[TODO] {R}/tmp/projects/infra/k8s: Watch for OOMKill recurrence over the next 2 weeks             "
PIN_ITEM   = f"{MAG}[PIN]  {R}/tmp/projects/api-server: memory usage keeps climbing after the last deploy — find the leak"
QUICK_ITEM = f"{GRN2}[Quick]{R} ▶ 1 session                                                                           "
SEP_ITEM   = f"{GRY}────────────────────────────────────────────────────────────────────────────────────────{R}         "

ALL_SESSIONS = [
    f"  {GRY}2026-05-08 09:14{R}  /tmp/projects/api-server:    {WHT}memory usage keeps climbing after the last deploy{R}",
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}pod keeps OOMKilling after we scaled up, pull the logs{R}",
    f"  {GRY}2026-05-08 08:38{R}  /tmp/projects/frontend:     {WHT}login form validation breaks only on Safari — fix it{R}",
    f"  {GRY}2026-05-08 08:17{R}  /tmp/projects/auth-service: {WHT}refactor session tokens to JWT — start with middleware{R}",
    f"  {GRY}2026-05-08 07:59{R}  /tmp/projects/monitoring:   {WHT}set up Grafana SLO alerts for the payment API{R}",
    f"  {GRY}2026-05-08 05:18{R}  /tmp/projects/data-pipeline:{WHT}Kafka consumer lag growing — find the bottleneck{R}",
]

OOM_SESSIONS = [
    f"  {GRY}2026-05-08 08:59{R}  /tmp/projects/infra/k8s:    {WHT}pod keeps OOMKilling after we scaled up, pull the logs{R}",
]

MLBL_SEP   = f"{GRY}──────────────── sessions to manage (large) ──────────────────────────────────────────────────{R}"
MANAGE_122 = f"{RED}[122M]{R} /tmp/projects/books:    {WHT}chapter draft review and rewrite{R}"
MANAGE_77  = f"{ORG2} [77M]{R} /tmp/projects/research: {WHT}keep-alive tuning results{R}"

def draw_fzf_manage(pinned, manage, sessions, selected=0, mode_label="claude", mode_color=None):
    mc = mode_color or ORG
    out("\033[2J\033[H", 0.01)
    out(f"  {GRN}cc-deck>{R} {CYN}{R}\033[?25l", 0.01); nl()
    out(make_header(mode_label, mc), 0.01); nl()
    items = pinned + [MLBL_SEP] + manage + [SEP_ITEM] + sessions
    info_left = f"  {len(items)}/100"
    mode_tag  = f"[{mode_label}]"
    pad = max(0, W - len(info_left) - len(mode_tag) - 2)
    out(f"{GRY}{info_left}{R}{' ' * pad}{mc}{mode_tag}{R}", 0.01); nl()
    for i, item in enumerate(items):
        if i == selected:
            out(f"{REV}>{R} {item}{R}", 0.01)
        else:
            out(f"  {item}", 0.01)
        nl()

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

# ── SCENE 0: TODO recorded in Claude session ──────────────────────────────────
comment("0. ask Claude to track something → auto-pinned as TODO in cc-deck",
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
type_chars("applied 3Gi limit. monitor for OOMKill next 2 weeks — add as TODO", 0.04)
out(f"\r\n{GRY}╰─{R}\r\n", 0.02)
pause(0.5)
out(f"{GRY}╭─{R} Claude\r\n", 0.02)
out(f"{GRY}│{R}  Recorded 1 memory {GRY}(ctrl+o to expand){R}\r\n", 0.03)
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
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — resuming session\r\n", 0.03)
out(f"{GRY}✓{R} applied 3Gi limit. monitor for OOMKill...\r\n", 0.03)
pause(1.0)

# ── SCENE 1: fuzzy search ─────────────────────────────────────────────────────
comment("1. fuzzy search — type to filter sessions instantly",
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
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — resuming session\r\n", 0.03)
out(f"{GRY}✓{R} pod keeps OOMKilling after we scaled up...\r\n", 0.03)
pause(1.0)

# ── SCENE 2: Tab mode cycling ─────────────────────────────────────────────────
comment("2. Tab cycles resume mode — current mode shown in header",
        pre=1.2, post=1.2)

out(f"{GRN}~/projects/infra/k8s{R} $ ", 0.01)
pause(0.4)
type_chars("cc-deck")
pause(0.3)
out("\r\n", 0.05)
pause(0.2)

for label, color in MODES:
    draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0, mode_label=label, mode_color=color)
    pause(0.9)

# back to default
draw_fzf([TODO_ITEM] + ALL_SESSIONS, selected=0)
pause(0.8)

# ── SCENE 3: PIN ──────────────────────────────────────────────────────────────
comment("3. pin a session for quick access with Ctrl-K",
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
out(f"{MAG}[cc-deck]{R} pinned: /tmp/projects/api-server — memory usage keeps climbing...\r\n", 0.04)
pause(1.0)

# ── SCENE 4: cc-deck -q → 2+ exchanges → [Quick] appears ─────────────────────
comment("4. cc-deck -q — ephemeral session, preserved after 2+ exchanges",
        pre=1.5, post=1.2)

out(f"{GRN}~/projects{R} $ ", 0.01)
pause(0.4)
type_chars("cc-deck -q")
pause(0.3)
out("\r\n", 0.05)
pause(0.4)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R}\r\n", 0.02)

# exchange 1
out(f"{GRY}╭─{R} User\r\n{GRY}│{R}  ", 0.01)
type_chars("what does SIGTERM do?", 0.06)
out(f"\r\n{GRY}╰─{R}\r\n", 0.02); pause(0.5)
out(f"{GRY}╭─{R} Claude\r\n", 0.02)
out(f"{GRY}│{R}  SIGTERM asks a process to terminate gracefully.\r\n", 0.02)
out(f"{GRY}│{R}  Unlike SIGKILL, the process can catch and handle it.\r\n", 0.02)
out(f"{GRY}╰─{R}\r\n", 0.02); pause(0.5)

# exchange 2
out(f"{GRY}╭─{R} User\r\n{GRY}│{R}  ", 0.01)
type_chars("and SIGKILL?", 0.06)
out(f"\r\n{GRY}╰─{R}\r\n", 0.02); pause(0.5)
out(f"{GRY}╭─{R} Claude\r\n", 0.02)
out(f"{GRY}│{R}  SIGKILL immediately forces termination — cannot be caught or ignored.\r\n", 0.02)
out(f"{GRY}╰─{R}\r\n", 0.02); pause(0.4)

out(f"\r\n{GRY}❯ /quit{R}\r\n", 0.03); pause(0.6)
out(f"{GRN}~/projects{R} $ ", 0.01); pause(1.0)

# Now show [Quick] entry appearing in cc-deck TUI
comment("→ session preserved — [Quick] appears in cc-deck",
        pre=0.5, post=0.8)

type_chars("cc-deck"); pause(0.3); out("\r\n", 0.05); pause(0.2)

draw_fzf_pinned(
    pinned=[TODO_ITEM, PIN_ITEM, QUICK_ITEM],
    sep=SEP_ITEM,
    sessions=ALL_SESSIONS,
    selected=2,
)
pause(1.5)

# Enter on [Quick] → nested quick session list
out("\033[2J\033[H", 0.01)
out(f"  {GRN}quick>{R} \033[?25l", 0.01); nl()
out(f"{GRY}[Quick] sessions | Enter: resume  Ctrl-R: delete  ESC: back{R}", 0.01); nl()
out(f"{GRY}  1/1{R}", 0.01); nl()
out(f"{REV}> {GRY}2026-05-22 10:30{R}  {WHT}what does SIGTERM do?{R}          ", 0.01); nl()
pause(1.5)

# Select → resume quick session
out("\033[2J\033[H", 0.01)
out(f"{GRN}~/projects{R} $ cc-deck\r\n", 0.01)
out(f"cd ~/.cc-deck-quick\r\n", 0.04)
pause(0.3)
out(f"{GRY}Claude Code{R} {GRN}v2.1.128{R} — resuming session\r\n", 0.03)
out(f"{GRY}✓{R} what does SIGTERM do?\r\n", 0.03)
nl()
out(f"{GRN}~/.cc-deck-quick{R} $ ", 0.04)
pause(0.4)
out(f"{GRY}│{R}", 0.04)
pause(2.0)

# ── SCENE 5: session size management ─────────────────────────────────────────
comment("5. large sessions surfaced below [Quick] — Ctrl-E trims, keeps recent turns", pre=1.2, post=0.8)

out(f"{GRN}~/projects{R} $ ", 0.01); pause(0.3)
type_chars("cc-deck"); pause(0.3); out("\r\n", 0.05); pause(0.2)
draw_fzf_manage([TODO_ITEM, PIN_ITEM, QUICK_ITEM], [MANAGE_122, MANAGE_77], ALL_SESSIONS, selected=4)
pause(1.8)

# Ctrl-E on the 122M session → preview + confirm + trim
out("\033[2J\033[H", 0.01)
out(f"{GRY}# Ctrl-E — trim to recent turns (full session archived first){R}\r\n", 0.02); pause(0.4)
out(f"7fd77d56-…jsonl: {RED}122.1MB{R} → {GRN}5.2MB{R} (keep last 10 of 50 turns) {GRY}[dry-run]{R}\r\n", 0.02); pause(0.7)
out("  Trim to recent turns? Full session is gzip-archived first. [y/N] ", 0.02)
type_chars("y", 0.12); out("\r\n", 0.05); pause(0.3)
out(f"{GRY}✓{R} archived full session → ~/.claude/_archive/7fd77d56_…jsonl.gz\r\n", 0.02); pause(1.1)

# back to list — 122M trimmed away, only 77M remains in the manage group
draw_fzf_manage([TODO_ITEM, PIN_ITEM, QUICK_ITEM], [MANAGE_77], ALL_SESSIONS, selected=4)
pause(2.0)

# ── Output ────────────────────────────────────────────────────────────────────
header = {
    "version": 2, "width": W, "height": H,
    "timestamp": 1746691200,
    "title": "cc-deck demo",
    "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}
}

out_file = sys.argv[1] if len(sys.argv) > 1 else "demo_social.cast"
with open(out_file, "w") as f:
    f.write(json.dumps(header) + "\n")
    for event in events:
        f.write(json.dumps(event) + "\n")

print(f"cast: {out_file} ({len(events)} events, {t:.1f}s)")
