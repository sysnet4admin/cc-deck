"""
cc-deck help screen. Invoked via fzf execute binding (F1).
"""
import sys, os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')

HELP = """
  cc-deck key bindings
  ──────────────────────────────────────────────────────
  Enter       Resume with current mode
  Tab         Cycle resume mode (default > api > skip > api+skip)
  Ctrl-O      Resume with: claude (default)
  Ctrl-A      Resume with: claude-api
  Ctrl-S      Resume with: claude --dangerously-skip-permissions
  Ctrl-X      Resume with: claude-api --dangerously-skip-permissions
  ──────────────────────────────────────────────────────
  Ctrl-K      Pin / unpin session
  Ctrl-R      Delete selected TODO or PIN
  F1          Show this help
  ESC         Quit
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
