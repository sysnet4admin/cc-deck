"""
Generate the fzf info line with a right-aligned colored mode indicator.
Called by fzf --info-command; FZF_INFO env var contains the raw match count string.
"""
import os, sys

# Windows: prevent \n -> \r\n translation so fzf doesn't get a stray \r
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')

HOME = os.path.expanduser('~')
MODE_FILE = os.path.join(HOME, '.claude', '.cc-deck-mode')
DEFAULT_CMD = os.environ.get('CLAUDE_DECK_CMD', 'claude')

LABELS = {
    'default':       DEFAULT_CMD,
    'api':           'claude-api',
    'dangerous':     'skip-perm',
    'api-dangerous': 'api+skip',
}
COLORS = {
    'default':       '\033[1;32m',   # bold green
    'api':           '\033[1;34m',   # bold blue
    'dangerous':     '\033[1;31m',   # bold red
    'api-dangerous': '\033[1;35m',   # bold magenta
}

try:
    m = open(MODE_FILE, encoding='utf-8').read().strip()
    current = m if m in LABELS else 'default'
except Exception:
    current = 'default'

fzf_info = os.environ.get('FZF_INFO', '')
label     = LABELS[current]
color     = COLORS[current]
ESC       = '\033'
colored_mode = f'{color}[{label}]{ESC}[0m'

# Terminal width: prefer shell-provided value (_CC_DECK_COLS set before fzf launch),
# then try fd-based detection, then fall back to 100
cols = int(os.environ.get('_CC_DECK_COLS', '0') or '0')
if not cols:
    for fd in (2, 1, 0):
        try:
            cols = os.get_terminal_size(fd).columns
            if cols:
                break
        except Exception:
            continue
if not cols:
    cols = 100

info_left = f'  {fzf_info}' if fzf_info else '  '
mode_tag  = f'[{label}]'
pad = max(1, cols - len(info_left) - len(mode_tag) - 2)
sys.stdout.write(f'{info_left}{" " * pad}{colored_mode}\n')
