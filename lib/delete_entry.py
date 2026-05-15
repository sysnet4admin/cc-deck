"""
cc-deck: delete a TODO or PIN entry.
Usage: python delete_entry.py <raw_id> <pins_file>
  raw_id: TODO:<session_id> or PIN:<session_id>
"""
import json, os, sys, glob, re

raw_id = sys.argv[1]
pins_file = sys.argv[2]

if raw_id.startswith('TODO:'):
    session_id = raw_id[5:]
    pattern = os.path.join(os.path.expanduser('~'), '.claude', 'projects', '*', 'memory', '*.md')
    found = []
    for mf in glob.glob(pattern):
        try:
            with open(mf, encoding='utf-8') as f:
                content = f.read()
            if session_id and f'originSessionId: {session_id}' in content:
                found.append(mf)
        except Exception:
            pass
    if found:
        for mf in found:
            with open(mf, encoding='utf-8') as f:
                content = f.read()

            def remove_todo(m):
                name = m.group(1)
                cleaned = re.sub(r'(?i)TODO\s*[-–—:]?\s*', '', name).strip()
                if not cleaned:
                    cleaned = name
                return f'name: {cleaned} (completed)'

            new_content = re.sub(r'^name:(.+)$', remove_todo, content, flags=re.MULTILINE)
            with open(mf, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f'[cc-deck] marked done: {os.path.basename(mf)}')
    else:
        print('[cc-deck] memory file not found')

elif raw_id.startswith('PIN:'):
    session_id = raw_id[4:]
    try:
        with open(pins_file, encoding='utf-8') as f:
            pins = json.load(f)
    except Exception:
        pins = {}
    # Strip BOM and any duplicate PIN: prefixes from session_id (defensive)
    session_id = session_id.lstrip('﻿')
    for _p in ('TODO:', 'PIN:'):
        while session_id.startswith(_p):
            session_id = session_id[len(_p):]
    session_id = session_id.strip()

    # Find matching key (handles corrupted keys with BOM/duplicate prefixes)
    def _clean_key(k):
        k = k.lstrip('﻿')
        for _p in ('TODO:', 'PIN:'):
            while k.startswith(_p):
                k = k[len(_p):]
        return k.strip()

    matched = None
    if session_id in pins:
        matched = session_id
    else:
        for k in pins:
            if _clean_key(k) == session_id:
                matched = k
                break

    if matched is not None:
        del pins[matched]
        with open(pins_file, 'w', encoding='utf-8') as f:
            json.dump(pins, f)
        print('[cc-deck] PIN removed')
    else:
        print('[cc-deck] PIN not found')

else:
    print('[cc-deck] Ctrl-D deletes only TODO or PIN entries')
