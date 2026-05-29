"""
cc-deck help screen. Invoked via fzf execute binding (F1).
"""
import sys, os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')

_available_raw = os.environ.get('_CC_DECK_AVAILABLE_MODES', 'default,api,dangerous,api-dangerous')
_available = {m.strip() for m in _available_raw.split(',')}

_mode_lines = []
if 'default' in _available:
    _mode_lines.append("  Ctrl-O      Resume with: claude (default)")
if 'api' in _available:
    _mode_lines.append("  Ctrl-A      Resume with: claude-api")
if 'dangerous' in _available:
    _mode_lines.append("  Ctrl-S      Resume with: claude --dangerously-skip-permissions")
if 'api-dangerous' in _available:
    _mode_lines.append("  Ctrl-X      Resume with: claude-api --dangerously-skip-permissions")

HELP = """
  cc-deck key bindings
  ──────────────────────────────────────────────────────
  Enter       Resume with current mode
  Tab         Cycle resume mode
""" + "\n".join(_mode_lines) + """
  ──────────────────────────────────────────────────────
  Ctrl-K      Pin / unpin session
  Ctrl-R      Delete selected TODO or PIN
  Ctrl-Q      Quick query (no session saved)
  Ctrl-G      Prune old snapshots (lossless, shrink size)
  Ctrl-E      Trim to recent turns (lossy; archives full first)
  F1          Show this help
  ESC         Quit

  "sessions to manage": oversized sessions, shown below
  [Quick] with a [NNM] size badge (orange 50MB+, red 100MB+).
  Ctrl-G removes snapshots (lossless); Ctrl-E trims old
  conversation when snapshots alone aren't enough (lossy,
  full session archived to ~/.claude/_archive first).
"""

sys.stdout.write(HELP)
sys.stdout.write("  Press any key to return...\n")
sys.stdout.flush()

try:
    if sys.platform == 'win32':
        import msvcrt
        msvcrt.getch()
    else:
        import tty, termios
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
except Exception:
    try:
        input()
    except Exception:
        pass
