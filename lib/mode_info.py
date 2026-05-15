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
    'dangerous':     'claude+skip',
    'api-dangerous': 'claude-api+skip',
}
COLORS = {
    'default':       '\033[1;38;2;217;119;87m',  # Claude Code brand orange #d97757
    'api':           '\033[1;34m',                # bold blue
    'dangerous':     '\033[1;31m',                # bold red
    'api-dangerous': '\033[1;36m',                # bold cyan
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

# Terminal width — priority determines how much right-margin safety we add:
#   FZF_COLUMNS (fzf 0.55+): exact fzf window width  → 1-char margin
#   _CC_DECK_COLS (shell):   [Console]::WindowWidth   → 4-char margin (Windows offset)
#   fd-based / fallback:     may be inaccurate         → 8-char margin
fzf_cols   = int(os.environ.get('FZF_COLUMNS', '') or 0)
shell_cols  = int(os.environ.get('_CC_DECK_COLS', '') or 0)

if fzf_cols:
    cols, margin = fzf_cols, 1
elif shell_cols:
    cols, margin = shell_cols, 4
else:
    cols = 0
    for fd in (2, 1, 0):
        try:
            cols = os.get_terminal_size(fd).columns
            if cols:
                break
        except Exception:
            continue
    if not cols:
        cols = 100
    margin = 8

info_left = f'  {fzf_info}' if fzf_info else '  '
mode_tag  = f'[{label}]'
pad = max(0, cols - len(info_left) - len(mode_tag) - margin)
sys.stdout.write(f'{info_left}{" " * pad}{colored_mode}\n')
