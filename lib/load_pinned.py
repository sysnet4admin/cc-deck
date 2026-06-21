"""
cc-deck: load pinned entries (TODO memory entries + manual PINs + large sessions).
Usage: python load_pinned.py <pins_file>
Output: raw_id<TAB>cwd<TAB>display_line  (with ANSI colors)
"""
import json, os, glob, sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')

PINS_FILE = sys.argv[1]
HOME = os.path.expanduser('~')
CACHE_FILE = os.path.join(HOME, '.claude', '.cc-deck-cache.json')

# Size marker thresholds (MB) — mirror the shell defaults / env overrides.
_WARN_MB = int(os.environ.get('CC_DECK_SIZE_WARN_MB') or 50)
_CRIT_MB = int(os.environ.get('CC_DECK_SIZE_CRIT_MB') or 100)
# Cap on surfaced large sessions (avoid flooding the top of the list).
_LARGE_MAX = int(os.environ.get('CC_DECK_LARGE_MAX') or 15)




def replace_home(path):
    """Case-insensitive home replacement for Windows compatibility."""
    if not path:
        return '?'
    try:
        rel = os.path.relpath(path, HOME)
        if not rel.startswith('..'):
            return '~' + os.sep + rel if rel != '.' else '~'
    except ValueError:
        pass
    return path


def detect_encoding(filepath):
    try:
        with open(filepath, 'rb') as f:
            sample = f.read(4096)
        if sample.startswith(b'\xef\xbb\xbf'):
            return 'utf-8-sig'
        sample.decode('utf-8')
        return 'utf-8'
    except (UnicodeDecodeError, OSError):
        return 'cp949'


def get_cwd_from_session(session_id):
    pattern = os.path.join(HOME, '.claude', 'projects', '*', session_id + '.jsonl')
    for f in glob.glob(pattern):
        try:
            enc = detect_encoding(f)
            with open(f, 'r', encoding=enc, errors='replace') as fp:
                for i, line in enumerate(fp):
                    if i > 50:
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


def get_latest_session_in_proj(memory_file):
    proj_dir = os.path.dirname(os.path.dirname(memory_file))
    jsonl_files = sorted(
        glob.glob(os.path.join(proj_dir, '*.jsonl')),
        key=os.path.getmtime, reverse=True
    )
    for f in jsonl_files:
        sid = os.path.splitext(os.path.basename(f))[0]
        cwd = get_cwd_from_session(sid)
        if cwd:
            return sid, cwd
    return '', ''


# 1. Memory TODOs (type: project, name contains TODO)
pattern = os.path.join(HOME, '.claude', 'projects', '*', 'memory', '*.md')
for mf in sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True):
    try:
        with open(mf, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if not content.startswith('---'):
            continue
        end = content.find('---', 3)
        if end == -1:
            continue
        meta = {}
        for line in content[3:end].strip().split('\n'):
            if ':' in line:
                k, v = line.split(':', 1)
                meta[k.strip()] = v.strip()
        if meta.get('type') != 'project':
            continue
        name = meta.get('name', '')
        if 'TODO' not in name.upper():
            continue
        if '(completed)' in name.lower():
            continue

        desc = meta.get('description', '') or name
        session_id = meta.get('originSessionId', '')
        if session_id:
            cwd = get_cwd_from_session(session_id)
        else:
            session_id, cwd = get_latest_session_in_proj(mf)
        short_cwd = replace_home(cwd)
        print(f'TODO:{session_id}\t{cwd}\t\033[1;33m[TODO]\033[0m {short_cwd}: {desc[:70]}')
    except Exception:
        pass

# 2. Manual pins
def load_preview_from_cache(sid):
    try:
        with open(CACHE_FILE, encoding='utf-8') as f:
            cache = json.load(f)
        for filepath, entry in cache.items():
            if os.path.splitext(os.path.basename(filepath))[0] == sid:
                return entry.get('preview', '')
    except Exception:
        pass
    return ''

try:
    with open(PINS_FILE, encoding='utf-8') as f:
        pins = json.load(f)
    for sid, info in sorted(pins.items(), key=lambda x: x[1].get('pinned_at', 0), reverse=True):
        cwd = info.get('cwd', '')
        note = info.get('note', '')
        short_cwd = replace_home(cwd)
        preview = note or load_preview_from_cache(sid) or short_cwd
        print(f'PIN:{sid}\t{cwd}\t\033[1;35m[PIN] \033[0m {short_cwd}: {preview[:70]}')
except Exception:
    pass

# 3. Quick sessions entry (always shown — hints feature when empty)
QUICK_REGISTRY = os.path.join(HOME, '.claude', '.cc-deck-quick.json')
try:
    with open(QUICK_REGISTRY, encoding='utf-8') as f:
        qreg = json.load(f)
    count = sum(1 for p in qreg if os.path.exists(p))
except Exception:
    count = 0

if count > 0:
    label = 'sessions' if count > 1 else 'session'
    print(f'QUICK:\t-\t\033[1;32m[Quick]\033[0m ▶ {count} {label}')
else:
    print(f'QUICK:\t-\t\033[1;32m[Quick]\033[0m ▶ no sessions yet  (cc-deck -q)')

# 4. Large sessions (>= warn) — their own "to manage" group below [Quick],
# behind a labeled separator. Duplication is allowed (a session shows here even
# if it's also TODO/PIN), so those rows stay clean and need no size info.
# Size is a simple [NNM] badge, colored by severity (red >= crit, orange >= warn).
# raw_id is the bare session_id, so the shell treats these like normal session
# rows (Enter resumes, Ctrl-G prunes).
try:
    _cache = {}
    try:
        with open(CACHE_FILE, encoding='utf-8') as f:
            _raw = json.load(f)
        for _fp, _ent in _raw.items():
            _cache[os.path.splitext(os.path.basename(_fp))[0]] = _ent
    except Exception:
        pass

    _large = []
    for f in glob.glob(os.path.join(HOME, '.claude', 'projects', '*', '*.jsonl')):
        try:
            sz = os.path.getsize(f)
        except OSError:
            continue
        if sz < _WARN_MB * 1048576:
            continue
        sid = os.path.splitext(os.path.basename(f))[0]
        _large.append((sz, f, sid))
    _large.sort(reverse=True)
    _large = _large[:_LARGE_MAX]

    if _large:
        # Labeled separator (non-selectable). The '-' placeholder in the cwd
        # field prevents the shell's IFS=tab read from collapsing empty fields.
        # Width follows COLUMNS (exported by the shell) so it spans the list.
        try:
            _cols = int(os.environ.get('COLUMNS') or 80)
        except ValueError:
            _cols = 80
        _lbl = ' sessions to manage (large) '
        _fill = max(6, _cols - 4 - len(_lbl))
        print(f'SEP:\t-\t\033[90m──{_lbl}{"─" * _fill}\033[0m')
        _w = max(len(f'[{sz // 1048576}M]') for sz, _, _ in _large)  # align size column
        for sz, f, sid in _large:
            ent = _cache.get(sid, {})
            cwd = ent.get('cwd') or get_cwd_from_session(sid)
            preview = ent.get('preview') or ''
            short_cwd = replace_home(cwd)
            plain = f'[{sz // 1048576}M]'
            pad = ' ' * (_w - len(plain))
            color = '\033[1;31m' if sz >= _CRIT_MB * 1048576 else '\033[38;5;208m'  # red / orange
            label = f'{short_cwd}: {preview[:60]}' if preview else short_cwd
            print(f'{sid}\t{cwd}\t{pad}{color}{plain}\033[0m {label}')
except Exception:
    pass
