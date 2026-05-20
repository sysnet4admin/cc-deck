"""
cc-deck quick query — instant one-shot Claude query, no session saved.
Called via fzf --bind=ctrl-q:execute(python3 quick_query.py)
"""
import os, sys, subprocess

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')

sys.stdout.write("\n  Quick query: ")
sys.stdout.flush()

try:
    query = input()
except (EOFError, KeyboardInterrupt):
    sys.exit(0)

if not query.strip():
    sys.exit(0)

print()
subprocess.run(['claude', '-p', '--no-session-persistence', query])
print()
sys.stdout.write("  Press any key to return...")
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
