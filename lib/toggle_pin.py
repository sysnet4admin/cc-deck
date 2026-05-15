"""
cc-deck: toggle pin for a session.
Usage: python toggle_pin.py <session_id> <cwd> <pins_file> [preview]
"""
import json, os, sys, time

sid = sys.argv[1]
cwd = sys.argv[2]
pins_file = sys.argv[3]
preview = sys.argv[4] if len(sys.argv) > 4 else ''

# Strip BOM and any TODO:/PIN: prefixes that may leak from fzf output
sid = sid.lstrip('﻿')
for _prefix in ('TODO:', 'PIN:'):
    while sid.startswith(_prefix):
        sid = sid[len(_prefix):]
sid = sid.strip()

try:
    with open(pins_file, encoding='utf-8') as f:
        pins = json.load(f)
except Exception:
    pins = {}

if sid in pins:
    del pins[sid]
    print('[cc-deck] unpinned')
else:
    pins[sid] = {'cwd': cwd, 'pinned_at': int(time.time()), 'note': preview}
    home = os.path.expanduser('~')
    try:
        rel = os.path.relpath(cwd, home)
        short = '~' + os.sep + rel if not rel.startswith('..') else cwd
    except ValueError:
        short = cwd
    print(f'[cc-deck] pinned: {short}')

with open(pins_file, 'w', encoding='utf-8') as f:
    json.dump(pins, f)
