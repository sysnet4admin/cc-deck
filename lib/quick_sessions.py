"""
cc-deck quick session registry.

Commands:
  register <marker_file>  — find sessions created since marker, add to registry
  cleanup                 — remove expired/invalid sessions from registry
  count                   — print number of valid sessions
  list                    — print sessions as fzf entries (session_id<TAB>cwd<TAB>display)
  delete-by-id <sid>      — remove session by UUID
"""
import os, sys, json, glob, time, datetime

HOME          = os.path.expanduser('~')
QUICK_DIR     = os.path.join(HOME, '.cc-deck-quick')
REGISTRY_FILE = os.path.join(HOME, '.claude', '.cc-deck-quick.json')
TTL           = 7 * 86400   # 7 days
MIN_EXCHANGES = 2            # minimum user messages to keep


def load_registry():
    try:
        with open(REGISTRY_FILE, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def save_registry(registry):
    try:
        with open(REGISTRY_FILE, 'w', encoding='utf-8') as f:
            json.dump(registry, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def get_session_cwd(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for i, line in enumerate(f):
                if i > 10:
                    break
                try:
                    d = json.loads(line.strip())
                    if d.get('type') == 'user':
                        return d.get('cwd', '')
                except Exception:
                    pass
    except Exception:
        pass
    return ''


def _is_real_content(text):
    """Filter out system-injected messages (e.g. <local-command-caveat>)."""
    return bool(text and text.strip() and not text.lstrip().startswith('<'))


def get_preview(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                try:
                    d = json.loads(line.strip())
                    if d.get('type') == 'user':
                        content = d.get('message', {}).get('content', '')
                        if isinstance(content, str) and _is_real_content(content):
                            return content.split('\n')[0][:80]
                        elif isinstance(content, list):
                            for item in content:
                                if isinstance(item, dict) and item.get('type') == 'text':
                                    text = item.get('text', '')
                                    if _is_real_content(text):
                                        return text.split('\n')[0][:80]
                except Exception:
                    pass
    except Exception:
        pass
    return '(no preview)'


def count_user_messages(filepath):
    """Count real user messages, excluding system-injected content."""
    count = 0
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                try:
                    d = json.loads(line.strip())
                    if d.get('type') == 'user':
                        content = d.get('message', {}).get('content', '')
                        if isinstance(content, str) and _is_real_content(content):
                            count += 1
                        elif isinstance(content, list):
                            if any(isinstance(i, dict) and _is_real_content(i.get('text', ''))
                                   for i in content if i.get('type') == 'text'):
                                count += 1
                except Exception:
                    pass
    except Exception:
        pass
    return count


cmd = sys.argv[1] if len(sys.argv) > 1 else 'count'

# ── register ───────────────────────────────────────────────────────────────────
if cmd == 'register':
    marker = sys.argv[2] if len(sys.argv) > 2 else None
    if not marker or not os.path.exists(marker):
        sys.exit(0)

    marker_time = os.path.getmtime(marker)
    registry    = load_registry()

    pattern = os.path.join(HOME, '.claude', 'projects', '*', '*.jsonl')
    for filepath in glob.glob(pattern):
        if 'subagents' in filepath:
            continue
        if filepath in registry:
            continue
        try:
            mtime = os.path.getmtime(filepath)
        except Exception:
            continue
        if mtime <= marker_time:
            continue

        cwd = get_session_cwd(filepath)
        if cwd != QUICK_DIR:
            continue

        n = count_user_messages(filepath)
        if n < MIN_EXCHANGES:
            try:
                os.unlink(filepath)
            except Exception:
                pass
            continue

        registry[filepath] = {
            'created': mtime,
            'preview': get_preview(filepath),
            'preserved': False,
        }

    save_registry(registry)

# ── cleanup ────────────────────────────────────────────────────────────────────
elif cmd == 'cleanup':
    registry = load_registry()
    now      = time.time()
    remove   = []

    for path, info in registry.items():
        if not os.path.exists(path):
            remove.append(path)
            continue
        age = now - info.get('created', 0)
        if age > TTL and not info.get('preserved', False):
            try:
                os.unlink(path)
            except Exception:
                pass
            remove.append(path)

    for path in remove:
        del registry[path]
    save_registry(registry)

# ── count ──────────────────────────────────────────────────────────────────────
elif cmd == 'count':
    registry = load_registry()
    print(sum(1 for p in registry if os.path.exists(p)))

# ── list ───────────────────────────────────────────────────────────────────────
elif cmd == 'list':
    registry = load_registry()
    valid = {p: v for p, v in registry.items() if os.path.exists(p)}
    for path, info in sorted(valid.items(), key=lambda x: x[1].get('created', 0), reverse=True):
        sid      = os.path.splitext(os.path.basename(path))[0]
        mtime    = datetime.datetime.fromtimestamp(info.get('created', 0)).strftime('%Y-%m-%d %H:%M')
        preview  = info.get('preview', '(no preview)')
        print(f'{sid}\t{QUICK_DIR}\t{mtime}  {preview}')

# ── delete-by-id ───────────────────────────────────────────────────────────────
elif cmd == 'delete-by-id':
    sid      = sys.argv[2] if len(sys.argv) > 2 else ''
    registry = load_registry()
    remove   = [p for p in registry if os.path.splitext(os.path.basename(p))[0] == sid]
    for path in remove:
        del registry[path]
        try:
            os.unlink(path)
        except Exception:
            pass
    save_registry(registry)
