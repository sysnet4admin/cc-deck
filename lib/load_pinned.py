"""
cc-deck: load pinned entries (TODO memory entries + manual PINs).
Usage: python load_pinned.py <pins_file>
Output: raw_id<TAB>cwd<TAB>display_line  (with ANSI colors)
"""
import json, os, glob, sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')

PINS_FILE = sys.argv[1]
HOME = os.path.expanduser('~')


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
CACHE_FILE = os.path.join(HOME, '.claude', '.cc-deck-cache.json')

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
        preview = load_preview_from_cache(sid) or note or short_cwd
        print(f'PIN:{sid}\t{cwd}\t\033[1;35m[PIN] \033[0m {short_cwd}: {preview[:70]}')
except Exception:
    pass
