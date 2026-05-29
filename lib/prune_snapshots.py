"""
cc-deck: lossless snapshot pruning for oversized session jsonl files.

A Claude Code session jsonl accumulates `file-history-snapshot` entries (one per
file-changing turn). They power /rewind but are cumulative — each stores the FULL
tracked-file ledger — so they grow quadratically and can dominate file size
(observed: 60% of a 305MB session) while contributing nothing to the conversation.

Pruning keeps only the last K snapshots (default 3 → preserves undo of the last
few turns) and drops the rest. This is LOSSLESS for the conversation: only old
rewind checkpoints are lost. Safety is guaranteed by re-counting non-snapshot
lines before replacing the original — if a single conversation line would be
lost, the operation aborts and the original is untouched.

Usage:
  prune_snapshots.py prune   <file> [--keep K]
  prune_snapshots.py dry-run <file> [--keep K]
  prune_snapshots.py scan-prune [--keep K] [--threshold-mb N] [--root DIR] [files...]
      (file source: --root DIR > args > stdin; prunes only those >= threshold)
"""
import sys, os, json, glob

SNAPSHOT_TYPE = 'file-history-snapshot'
DEFAULT_KEEP = 3
DEFAULT_THRESHOLD_MB = 100
CACHE_FILE = os.path.join(os.path.expanduser('~'), '.claude', '.cc-deck-cache.json')


def _invalidate_cache(filepath):
    """Drop a file's entry from cc-deck's preview cache (best-effort).

    Pruning preserves mtime (to keep list ordering), so the mtime-keyed cache
    would otherwise serve a stale preview. Removing the entry forces a fresh
    re-extract on the next run. Safe: cc-deck calls prune and extract_all
    sequentially, never concurrently.
    """
    try:
        with open(CACHE_FILE, encoding='utf-8') as f:
            cache = json.load(f)
        if filepath in cache:
            del cache[filepath]
            with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump(cache, f)
    except Exception:
        pass


def _is_snapshot(raw):
    """Cheap check: only parse lines that could be a snapshot."""
    if b'file-history-snapshot' not in raw:
        return False
    try:
        return json.loads(raw).get('type') == SNAPSHOT_TYPE
    except Exception:
        return False


def analyze(filepath, keep=DEFAULT_KEEP):
    """Return (before_bytes, after_bytes, total_snaps, dropped, kept_nonsnap)."""
    snap_indices = []
    snap_sizes = []
    before = 0
    nonsnap = 0
    with open(filepath, 'rb') as f:
        for i, raw in enumerate(f):
            before += len(raw)
            if _is_snapshot(raw):
                snap_indices.append(i)
                snap_sizes.append(len(raw))
            else:
                nonsnap += 1
    total = len(snap_indices)
    drop = max(0, total - keep)
    dropped_bytes = sum(snap_sizes[:drop]) if drop else 0
    after = before - dropped_bytes
    return before, after, total, drop, nonsnap


def prune(filepath, keep=DEFAULT_KEEP):
    """Drop all but the last `keep` snapshots. Returns (before, after, dropped).

    Validated + atomic: writes to a temp file in the same dir, re-counts
    non-snapshot lines, and only os.replace()s if no conversation line was lost.
    Raises RuntimeError on validation failure (original left untouched).
    """
    before, _, total, drop, orig_nonsnap = analyze(filepath, keep)
    if drop <= 0:
        return before, before, 0

    # Preserve original timestamps: pruning is maintenance, not "use" — the
    # session must keep its position in cc-deck's recency-sorted list.
    orig_stat = os.stat(filepath)

    keep_from = total - keep  # snapshot ordinal at/after which we keep
    tmp = filepath + '.ccdeck-prune.tmp'
    written_nonsnap = 0
    written_bytes = 0
    snap_seen = 0
    try:
        with open(filepath, 'rb') as src, open(tmp, 'wb') as dst:
            for raw in src:
                if _is_snapshot(raw):
                    keepit = snap_seen >= keep_from
                    snap_seen += 1
                    if not keepit:
                        continue
                else:
                    written_nonsnap += 1
                dst.write(raw)
                written_bytes += len(raw)

        # Validation: every conversation/meta line must survive untouched.
        if written_nonsnap != orig_nonsnap:
            raise RuntimeError(
                f'validation failed: non-snapshot lines {orig_nonsnap} -> '
                f'{written_nonsnap} (aborting, original untouched)')

        os.replace(tmp, filepath)
        try:
            os.utime(filepath, (orig_stat.st_atime, orig_stat.st_mtime))
        except OSError:
            pass
        _invalidate_cache(filepath)
    except Exception:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise
    return before, written_bytes, drop


def _mb(n):
    return n / 1048576.0


def main(argv):
    if not argv:
        print(__doc__.strip())
        return 1

    cmd = argv[0]
    rest = argv[1:]

    keep = DEFAULT_KEEP
    threshold_mb = DEFAULT_THRESHOLD_MB
    root = None
    positional = []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == '--keep':
            keep = int(rest[i + 1]); i += 2; continue
        if a == '--threshold-mb':
            threshold_mb = float(rest[i + 1]); i += 2; continue
        if a == '--root':
            root = rest[i + 1]; i += 2; continue
        positional.append(a); i += 1

    if cmd in ('prune', 'dry-run'):
        if not positional:
            print('error: file path required', file=sys.stderr)
            return 1
        fp = positional[0]
        if not os.path.isfile(fp):
            print(f'error: not a file: {fp}', file=sys.stderr)
            return 1
        if cmd == 'dry-run':
            before, after, total, drop, _ = analyze(fp, keep)
            print(f'{os.path.basename(fp)}: {_mb(before):.1f}MB -> {_mb(after):.1f}MB '
                  f'(snapshots {total}, drop {drop}, keep {min(keep, total)}) [dry-run]')
        else:
            before, after, drop = prune(fp, keep)
            if drop == 0:
                print(f'{os.path.basename(fp)}: nothing to prune — '
                      f'{_mb(before):.0f}MB is conversation, not snapshots '
                      f'(snapshots already <= {keep})')
            else:
                print(f'{os.path.basename(fp)}: {_mb(before):.1f}MB -> {_mb(after):.1f}MB '
                      f'(dropped {drop} snapshots)')
        return 0

    if cmd == 'scan-prune':
        # Source order: --root <dir> (Python walks it) > positional args > stdin.
        # --root passes one argument (no command-line length limit) and avoids
        # relying on the shell to enumerate or pipe the file list — most robust,
        # especially on Windows/PowerShell. Depth-2 glob (projects/<enc>/<file>)
        # naturally excludes deeper subagents/*.jsonl files.
        if root:
            files = glob.glob(os.path.join(root, '*', '*.jsonl'))
        else:
            files = positional
            if not files:
                files = [ln.rstrip('\r\n') for ln in sys.stdin if ln.strip()]
        threshold = threshold_mb * 1048576
        pruned_any = False
        for fp in files:
            try:
                if not os.path.isfile(fp):
                    continue
                if os.path.getsize(fp) < threshold:
                    continue
                before, after, drop = prune(fp, keep)
                if drop > 0:
                    pruned_any = True
                    print(f'[cc-deck] pruned {os.path.basename(fp)[:8]}: '
                          f'{_mb(before):.0f}MB -> {_mb(after):.0f}MB '
                          f'({drop} old snapshots removed)')
            except Exception as e:
                print(f'[cc-deck] prune skipped {os.path.basename(fp)[:8]}: {e}',
                      file=sys.stderr)
        return 0 if pruned_any or not files else 0

    print(f'unknown command: {cmd}', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
