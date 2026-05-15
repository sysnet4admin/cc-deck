"""
Cycle cc-deck resume mode and output fzf change-header action.
Called from: fzf --bind "tab:transform:python cycle_mode.py"
Reads current mode from ~/.claude/.cc-deck-mode, advances to next,
writes it back, and prints a fzf change-header(...) action to stdout.
"""
import os, sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

HOME = os.path.expanduser('~')
MODE_FILE = os.path.join(HOME, '.claude', '.cc-deck-mode')
DEFAULT_CMD = os.environ.get('CLAUDE_DECK_CMD', 'claude')

CYCLE = ['default', 'api', 'dangerous', 'api-dangerous']
LABELS = {
    'default':       DEFAULT_CMD,
    'api':           'claude-api',
    'dangerous':     'skip-permissions',
    'api-dangerous': 'api+skip',
}

try:
    m = open(MODE_FILE, encoding='utf-8').read().strip()
    current = m if m in CYCLE else 'default'
except Exception:
    current = 'default'

next_mode = CYCLE[(CYCLE.index(current) + 1) % len(CYCLE)]

try:
    with open(MODE_FILE, 'w', encoding='utf-8') as f:
        f.write(next_mode)
except Exception:
    pass

label = LABELS[next_mode]
ESC = '\033'
header = (
    f'{ESC}[1;33m[TODO]{ESC}[0m=auto-pinned  '
    f'{ESC}[1;35m[PIN]{ESC}[0m=manual | '
    f'Enter: {label}  Tab: >  '
    f'^K: pin  ^R: rm  ^/: help  ESC: quit'
)
print(f'change-header({header})')
