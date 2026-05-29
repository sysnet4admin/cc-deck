"""
cc-deck: tail-resume — shrink a conversation-heavy session by keeping only the
last N user turns of the active conversation, archiving the full file first.

Snapshot pruning (prune_snapshots.py) is lossless but only removes file-history
snapshots. When a session is large because of conversation bulk (messages +
tool output), this is the lever that helps: keep the most recent N turns so you
can pick up where you left off, and gzip-archive the complete original first so
nothing is truly lost.

LOSSY. Always archives the full file (gzip) before truncating. The truncated
file keeps the same session id (resume continues normally) and original mtime.

The active conversation is the parentUuid chain from the last message back to a
root. We cut at the Nth-last real user prompt (not a tool_result message), keep
every line at/after that point, drop older turns and all but the last K
snapshots, and re-root any kept node whose parent was dropped. A full backup
makes this safe even if the cut is imperfect — restore from the archive.

Usage:
  tail_resume.py trim    <file> [--keep-turns N] [--keep-snaps K]
  tail_resume.py dry-run <file> [--keep-turns N] [--keep-snaps K]
"""
import sys, os, json, gzip, shutil, datetime

CHAIN_TYPES = {'user', 'assistant', 'attachment', 'system'}
SNAPSHOT_TYPE = 'file-history-snapshot'
DEFAULT_KEEP_TURNS = 10
DEFAULT_KEEP_SNAPS = 3
HOME = os.path.expanduser('~')
ARCHIVE_DIR = os.path.join(HOME, '.claude', '_archive')
CACHE_FILE = os.path.join(HOME, '.claude', '.cc-deck-cache.json')


def _invalidate_cache(filepath):
    """Drop a file's entry from cc-deck's preview cache (best-effort)."""
    try:
        with open(CACHE_FILE, encoding='utf-8') as f:
            cache = json.load(f)
        if filepath in cache:
            del cache[filepath]
            with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump(cache, f)
    except Exception:
        pass


def _is_user_turn(d):
    """A real user prompt (turn boundary) — not a tool_result / system message."""
    if not d or d.get('type') != 'user':
        return False
    c = d.get('message', {}).get('content')
    if isinstance(c, str):
        return bool(c.strip()) and not c.startswith('<')
    if isinstance(c, list):
        return any(isinstance(b, dict) and b.get('type') == 'text' for b in c)
    return False


def _plan(filepath, keep_turns, keep_snaps):
    """Compute which lines to keep. Returns a dict with stats and indices.

    keys: lines, objs, kept_idxs (set or None if nothing to trim), reroot (set
    of uuids to null), before, after, n_turns.
    """
    lines, objs = [], []
    with open(filepath, 'rb') as f:
        for raw in f:
            lines.append(raw)
            try:
                objs.append(json.loads(raw))
            except Exception:
                objs.append(None)
    before = sum(len(x) for x in lines)

    uuid_index, parent = {}, {}
    last_chain = None
    snap_idxs = []
    for i, d in enumerate(objs):
        if d is None:
            continue
        t = d.get('type')
        if t == SNAPSHOT_TYPE:
            snap_idxs.append(i)
        elif t in CHAIN_TYPES and 'uuid' in d:
            uuid_index[d['uuid']] = i
            parent[d['uuid']] = d.get('parentUuid')
            last_chain = d['uuid']

    # Active path: leaf -> root
    path, cur, seen = [], last_chain, set()
    while cur in parent and cur not in seen:
        seen.add(cur)
        path.append(cur)
        cur = parent[cur]
    path.reverse()

    turn_uuids = [u for u in path if _is_user_turn(objs[uuid_index[u]])]
    keep_snap_set = set(snap_idxs[-keep_snaps:]) if keep_snaps > 0 else set()

    if len(turn_uuids) <= keep_turns:
        return dict(lines=lines, objs=objs, kept_idxs=None, reroot=set(),
                    before=before, after=before, n_turns=len(turn_uuids))

    cut_idx = uuid_index[turn_uuids[-keep_turns]]
    kept_chain = {u for u, idx in uuid_index.items() if idx >= cut_idx}

    kept_idxs, reroot = set(), set()
    for i, d in enumerate(objs):
        if d is None:
            if i >= cut_idx:
                kept_idxs.add(i)
            continue
        t = d.get('type')
        if t == SNAPSHOT_TYPE:
            if i in keep_snap_set:
                kept_idxs.add(i)
        elif t in CHAIN_TYPES and 'uuid' in d:
            if d['uuid'] in kept_chain:
                kept_idxs.add(i)
                p = d.get('parentUuid')
                if p is not None and p not in kept_chain:
                    reroot.add(d['uuid'])
        else:
            kept_idxs.add(i)  # small session-meta lines — keep all

    after = sum(len(lines[i]) for i in kept_idxs)
    return dict(lines=lines, objs=objs, kept_idxs=kept_idxs, reroot=reroot,
                before=before, after=after, n_turns=len(turn_uuids))


def _reroot_bytes(raw, obj):
    obj = dict(obj)
    obj['parentUuid'] = None
    nl = b'\n' if raw.endswith(b'\n') else b''
    return json.dumps(obj, ensure_ascii=False).encode('utf-8') + nl


def trim(filepath, keep_turns=DEFAULT_KEEP_TURNS, keep_snaps=DEFAULT_KEEP_SNAPS):
    """Archive (gzip) then truncate. Returns (before, after, n_turns, archive).

    archive is None when there was nothing to trim (<= keep_turns turns).
    """
    plan = _plan(filepath, keep_turns, keep_snaps)
    if plan['kept_idxs'] is None:
        return plan['before'], plan['before'], plan['n_turns'], None

    os.makedirs(ARCHIVE_DIR, exist_ok=True)
    sid = os.path.splitext(os.path.basename(filepath))[0]
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    archive = os.path.join(ARCHIVE_DIR, f'{sid}_{stamp}.jsonl.gz')
    with open(filepath, 'rb') as src, gzip.open(archive, 'wb') as dst:
        shutil.copyfileobj(src, dst)

    orig_stat = os.stat(filepath)
    lines, objs = plan['lines'], plan['objs']
    kept_idxs, reroot = plan['kept_idxs'], plan['reroot']
    tmp = filepath + '.ccdeck-tail.tmp'
    try:
        with open(tmp, 'wb') as out:
            for i, raw in enumerate(lines):
                if i not in kept_idxs:
                    continue
                if objs[i] is not None and objs[i].get('uuid') in reroot:
                    out.write(_reroot_bytes(raw, objs[i]))
                else:
                    out.write(raw)
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
    return plan['before'], plan['after'], plan['n_turns'], archive


def _mb(n):
    return n / 1048576.0


def main(argv):
    if not argv:
        print(__doc__.strip())
        return 1
    cmd, rest = argv[0], argv[1:]
    keep_turns, keep_snaps, positional = DEFAULT_KEEP_TURNS, DEFAULT_KEEP_SNAPS, []
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == '--keep-turns':
            keep_turns = int(rest[i + 1]); i += 2; continue
        if a == '--keep-snaps':
            keep_snaps = int(rest[i + 1]); i += 2; continue
        positional.append(a); i += 1

    if cmd not in ('trim', 'dry-run') or not positional:
        print('usage: tail_resume.py trim|dry-run <file> [--keep-turns N] [--keep-snaps K]',
              file=sys.stderr)
        return 1
    fp = positional[0]
    if not os.path.isfile(fp):
        print(f'error: not a file: {fp}', file=sys.stderr)
        return 1
    name = os.path.basename(fp)

    if cmd == 'dry-run':
        p = _plan(fp, keep_turns, keep_snaps)
        if p['kept_idxs'] is None:
            print(f'{name}: nothing to trim — only {p["n_turns"]} turns (<= {keep_turns})')
        else:
            print(f'{name}: {_mb(p["before"]):.1f}MB -> {_mb(p["after"]):.1f}MB '
                  f'(keep last {keep_turns} of {p["n_turns"]} turns) [dry-run]')
        return 0

    before, after, n_turns, archive = trim(fp, keep_turns, keep_snaps)
    if archive is None:
        print(f'{name}: nothing to trim — only {n_turns} turns (<= {keep_turns})')
    else:
        print(f'{name}: {_mb(before):.1f}MB -> {_mb(after):.1f}MB '
              f'(kept last {keep_turns} of {n_turns} turns)')
        print(f'  archived full session: {archive.replace(HOME, "~")}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
