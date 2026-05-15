"""
cc-deck: session bulk parser with mtime cache.
Reads file list from stdin (one per line) or from sys.argv[1:].
Output: filepath<TAB>cwd<TAB>preview
"""
import sys, json, os

CACHE_FILE = os.path.expanduser('~/.claude/.cc-deck-cache.json')


def detect_encoding(filepath):
    """Try UTF-8 first, fall back to CP949 for older Korean Windows session files."""
    try:
        with open(filepath, 'rb') as f:
            sample = f.read(4096)
        if sample.startswith(b'\xef\xbb\xbf'):
            return 'utf-8-sig'
        sample.decode('utf-8')
        return 'utf-8'
    except (UnicodeDecodeError, OSError):
        return 'cp949'


def extract(filepath):
    enc = detect_encoding(filepath)
    size = os.path.getsize(filepath)
    cwd = ''
    first_preview = ''

    with open(filepath, 'r', encoding=enc, errors='replace') as f:
        for i, line in enumerate(f):
            if i > 50:
                break
            try:
                d = json.loads(line.strip())
                if d.get('type') == 'user' and not cwd:
                    cwd = d.get('cwd', '')
                    content = d.get('message', {}).get('content', '')
                    if isinstance(content, str) and not content.startswith('<'):
                        first_preview = content.split('\n')[0][:80]
            except Exception:
                pass

    last_prompt = ''
    with open(filepath, 'rb') as f:
        f.seek(max(0, size - 102400))
        raw_tail = f.read()
    try:
        tail = raw_tail.decode(enc, errors='replace')
    except Exception:
        tail = raw_tail.decode('utf-8', errors='replace')

    for line in reversed(tail.split('\n')):
        try:
            d = json.loads(line.strip())
            if d.get('type') == 'last-prompt':
                p = d.get('lastPrompt', '')
                if p and not p.startswith('<'):
                    last_prompt = p.split('\n')[0][:80]
                    break
        except Exception:
            pass

    return cwd, last_prompt or first_preview


def load_cache():
    try:
        with open(CACHE_FILE, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def save_cache(cache):
    try:
        with open(CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(cache, f)
    except Exception:
        pass


# Accept file list from args or stdin
if len(sys.argv) > 1:
    file_list = sys.argv[1:]
else:
    file_list = [line.rstrip('\r\n') for line in sys.stdin if line.strip()]

cache = load_cache()
new_cache = {}

for filepath in file_list:
    try:
        mtime = os.path.getmtime(filepath)
        entry = cache.get(filepath)
        if entry and entry.get('mtime') == mtime:
            cwd, preview = entry['cwd'], entry['preview']
        else:
            cwd, preview = extract(filepath)
        new_cache[filepath] = {'mtime': mtime, 'cwd': cwd, 'preview': preview}
        print(f'{filepath}\t{cwd}\t{preview}', flush=True)
    except Exception:
        print(f'{filepath}\t\t', flush=True)

merged = {k: v for k, v in cache.items() if k not in new_cache and os.path.exists(k)}
merged.update(new_cache)
save_cache(merged)
