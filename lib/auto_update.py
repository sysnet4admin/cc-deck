"""
cc-deck auto-updater.
Usage: python auto_update.py <install_dir> [--force]
  --force  skip 24h TTL check (used by 'cc-deck update')
"""
import os, sys, subprocess, time

INSTALL_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORCE = '--force' in sys.argv

HOME = os.path.expanduser('~')
CHECK_FILE  = os.path.join(HOME, '.claude', '.cc-deck-last-update')
UPDATE_FLAG = os.path.join(HOME, '.claude', '.cc-deck-updated')
LOCK_FILE   = os.path.join(HOME, '.claude', '.cc-deck-update.lock')
TTL = 86400  # 24 hours


def run(args, timeout=10):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout)


def get_version(sha, install_dir):
    """Return tag name for the given commit, or nearest ancestor tag as fallback."""
    try:
        r = run(['git', '-C', install_dir, 'describe', '--tags', '--exact-match', sha])
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    except Exception:
        pass
    try:
        r = run(['git', '-C', install_dir, 'describe', '--tags', '--abbrev=0', sha])
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip() + '+'
    except Exception:
        pass
    return sha[:7]


def is_clean():
    try:
        r = run(['git', '-C', INSTALL_DIR, 'status', '--porcelain'])
        return r.returncode == 0 and not r.stdout.strip()
    except Exception:
        return False


def main():
    if os.environ.get('CC_DECK_DISABLE_AUTOUPDATER'):
        return

    # TTL check
    if not FORCE:
        try:
            last = float(open(CHECK_FILE).read().strip())
            if time.time() - last < TTL:
                return
        except Exception:
            pass

    # Lock: prevent concurrent updates
    try:
        fd = os.open(LOCK_FILE, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(fd, str(os.getpid()).encode())
        os.close(fd)
    except OSError:
        return  # another update in progress

    try:
        # Update timestamp immediately to prevent duplicate runs
        try:
            with open(CHECK_FILE, 'w') as f:
                f.write(str(time.time()))
        except Exception:
            pass

        # Fetch from remote
        try:
            run(['git', '-C', INSTALL_DIR, 'fetch', '--quiet', 'origin'], timeout=10)
        except Exception:
            return

        # Compare HEAD with origin/main
        try:
            local  = run(['git', '-C', INSTALL_DIR, 'rev-parse', 'HEAD']).stdout.strip()
            remote = run(['git', '-C', INSTALL_DIR, 'rev-parse', 'origin/main']).stdout.strip()
        except Exception:
            return

        if local == remote:
            return  # already up to date

        # Don't touch dirty working tree
        if not is_clean():
            return

        # Pull
        prev_sha = local
        try:
            r = run(['git', '-C', INSTALL_DIR, 'pull', '--ff-only', '--quiet'], timeout=30)
        except Exception:
            return

        if r.returncode != 0:
            # Rollback on failure
            try:
                run(['git', '-C', INSTALL_DIR, 'reset', '--hard', prev_sha])
            except Exception:
                pass
            return

        # Signal success
        try:
            with open(UPDATE_FLAG, 'w') as f:
                f.write(f'{get_version(prev_sha, INSTALL_DIR)} → {get_version(remote, INSTALL_DIR)}')
        except Exception:
            pass

    finally:
        try:
            os.unlink(LOCK_FILE)
        except Exception:
            pass


if __name__ == '__main__':
    main()
