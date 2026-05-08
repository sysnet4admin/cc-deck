# cc-deck: Claude Code session browser and task manager
# https://github.com/sysnet4admin/cc-deck
#
# Usage: source this file in ~/.zshrc
#   source ~/11.Github/cc-deck/cc-deck.zsh
#
# Requirements: fzf (brew install fzf), python3

# ── Internal file paths ────────────────────────────────────────────────────────
_cc_deck_mode_file="$HOME/.claude/.cc-deck-mode"
_cc_deck_pins_file="$HOME/.claude/.cc-deck-pins.json"

# ── Session file bulk parsing (with mtime cache) ───────────────────────────────
# Output: filepath\tcwd\tpreview
_cc_deck_extract_all() {
  python3 - "$@" <<'PYEOF'
import sys, json, os

CACHE_FILE = os.path.expanduser('~/.claude/.cc-deck-cache.json')

def extract(filepath):
    size = os.path.getsize(filepath)
    cwd = ''
    first_preview = ''

    with open(filepath, 'r', errors='ignore') as f:
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
            except:
                pass

    last_prompt = ''
    with open(filepath, 'rb') as f:
        f.seek(max(0, size - 20480))
        tail = f.read().decode('utf-8', errors='ignore')
    for line in reversed(tail.split('\n')):
        try:
            d = json.loads(line.strip())
            if d.get('type') == 'last-prompt':
                p = d.get('lastPrompt', '')
                if p and not p.startswith('<'):
                    last_prompt = p.split('\n')[0][:80]
                    break
        except:
            pass

    return cwd, last_prompt or first_preview

def load_cache():
    try:
        with open(CACHE_FILE) as f:
            return json.load(f)
    except:
        return {}

def save_cache(cache):
    try:
        with open(CACHE_FILE, 'w') as f:
            json.dump(cache, f)
    except:
        pass

cache = load_cache()
new_cache = {}

for f in sys.argv[1:]:
    try:
        mtime = os.path.getmtime(f)
        entry = cache.get(f)
        if entry and entry.get('mtime') == mtime:
            cwd, preview = entry['cwd'], entry['preview']
        else:
            cwd, preview = extract(f)
        new_cache[f] = {'mtime': mtime, 'cwd': cwd, 'preview': preview}
        print(f'{f}\t{cwd}\t{preview}', flush=True)
    except:
        print(f'{f}\t\t', flush=True)

save_cache(new_cache)
PYEOF
}

# ── Load pinned entries (memory TODOs + manual pins) ───────────────────────────
# Output: TODO:<session_id>\t<cwd>\t[TODO] <short_cwd>: <desc>
#         PIN:<session_id>\t<cwd>\t[PIN]  <short_cwd>: <desc>
_cc_deck_load_pinned() {
  python3 - "$_cc_deck_pins_file" <<'PYEOF'
import json, os, glob, sys

PINS_FILE = sys.argv[1]
HOME = os.path.expanduser('~')

def get_cwd_from_session(session_id):
    for f in glob.glob(os.path.expanduser(f'~/.claude/projects/*/{session_id}.jsonl')):
        try:
            with open(f, 'r', errors='ignore') as fp:
                for i, line in enumerate(fp):
                    if i > 50:
                        break
                    try:
                        d = json.loads(line.strip())
                        if d.get('type') == 'user':
                            return d.get('cwd', '')
                    except:
                        pass
        except:
            pass
    return ''

# 1. Memory TODOs (type: project, name starts with TODO)
for mf in sorted(
    glob.glob(os.path.expanduser('~/.claude/projects/*/memory/*.md')),
    key=os.path.getmtime, reverse=True
):
    try:
        with open(mf, 'r') as f:
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
        if not meta.get('name', '').upper().startswith('TODO'):
            continue
        desc = meta.get('description', '') or meta.get('name', '')
        session_id = meta.get('originSessionId', '')
        cwd = get_cwd_from_session(session_id) if session_id else ''
        short_cwd = cwd.replace(HOME, '~') if cwd else '?'
        print(f'TODO:{session_id}\t{cwd}\t\033[1;33m[TODO]\033[0m {short_cwd}: {desc[:70]}')
    except:
        pass

# 2. Manual pins
try:
    with open(PINS_FILE) as f:
        pins = json.load(f)
    for sid, info in sorted(pins.items(), key=lambda x: x[1].get('pinned_at', 0), reverse=True):
        cwd = info.get('cwd', '')
        note = info.get('note', '')
        short_cwd = cwd.replace(HOME, '~') if cwd else '?'
        label = note if note else short_cwd
        print(f'PIN:{sid}\t{cwd}\t\033[1;35m[PIN] \033[0m {short_cwd}: {label[:70]}')
except:
    pass
PYEOF
}

# ── Manual pin toggle ──────────────────────────────────────────────────────────
_cc_deck_toggle_pin() {
  local session_id="$1"
  local cwd="$2"
  python3 - "$session_id" "$cwd" "$_cc_deck_pins_file" <<'PYEOF'
import json, os, sys, time
sid, cwd, pins_file = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(pins_file) as f:
        pins = json.load(f)
except:
    pins = {}
if sid in pins:
    del pins[sid]
    print('[cc-deck] unpinned')
else:
    pins[sid] = {'cwd': cwd, 'pinned_at': int(time.time())}
    short = cwd.replace(os.path.expanduser('~'), '~')
    print(f'[cc-deck] pinned: {short}')
with open(pins_file, 'w') as f:
    json.dump(pins, f)
PYEOF
}

# ── Mode persistence ───────────────────────────────────────────────────────────
_cc_deck_save_mode() { echo "$1" > "$_cc_deck_mode_file" 2>/dev/null }
_cc_deck_load_mode() { cat "$_cc_deck_mode_file" 2>/dev/null || echo "default" }

# ── Session resume ─────────────────────────────────────────────────────────────
# CLAUDE_DECK_CMD env var overrides default command
# e.g. export CLAUDE_DECK_CMD="claude-api"
#      export CLAUDE_DECK_CMD="claude --dangerously-skip-permissions"
_cc_deck_resume() {
  local session_id="$1"
  local cwd="$2"
  local mode="${3:-default}"
  local current_dir="$(pwd)"

  if [[ -n "$cwd" && -d "$cwd" && "$cwd" != "$current_dir" ]]; then
    echo "cd ${cwd/#$HOME/~}"
    cd "$cwd"
  fi

  _cc_deck_save_mode "$mode"

  case "$mode" in
    api)           claude-api --resume "$session_id" ;;
    dangerous)     claude --dangerously-skip-permissions --resume "$session_id" ;;
    api-dangerous) claude-api --dangerously-skip-permissions --resume "$session_id" ;;
    *)             ${=CLAUDE_DECK_CMD:-claude} --resume "$session_id" ;;
  esac
}

# ── cc-deck ────────────────────────────────────────────────────────────────────
# Browse all Claude Code sessions via fzf TUI and resume selected.
# TODOs from Claude memory and manually pinned sessions appear at the top.
#
# Keys:
#   Enter    resume with last saved mode
#   Ctrl-K   pin / unpin current session (toggle)
#   Ctrl-O   resume with: claude
#   Ctrl-A   resume with: claude-api
#   Ctrl-D   resume with: claude --dangerously-skip-permissions
#   Ctrl-X   resume with: claude-api --dangerously-skip-permissions
#
# Env:
#   CLAUDE_DECK_CMD   override default resume command (e.g. "claude-api")
cc-deck() {
  local current_dir="$(pwd)"
  local default_cmd="${CLAUDE_DECK_CMD:-claude}"

  # Collect recent 100 session files
  local files=()
  while IFS= read -r f; do
    [[ -f "$f" ]] && files+=("$f")
  done < <(find "$HOME/.claude/projects" -maxdepth 2 -name "*.jsonl" ! -path "*/subagents/*" \
    -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | awk '{print $2}' | head -100)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "[cc-deck] no sessions found"
    return
  fi

  # Build session entries (parsed once)
  local session_entries=()
  while IFS=$'\t' read -r filepath cwd preview; do
    local session_id=$(basename "$filepath" .jsonl)
    local mtime=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$filepath")
    local short_cwd="${cwd/#$HOME/~}"
    local marker="  "
    [[ "$cwd" == "$current_dir" ]] && marker=$'\033[32m*\033[0m '
    session_entries+=("${session_id}	${cwd}	${marker}${mtime}  ${short_cwd}: ${preview:-(no preview)}")
  done < <(_cc_deck_extract_all "${files[@]}")

  if [[ ${#session_entries[@]} -eq 0 ]]; then
    echo "[cc-deck] no sessions found"
    return
  fi

  # Resolve saved/default mode
  local saved_mode
  if [[ -n "$CLAUDE_DECK_CMD" ]]; then
    saved_mode="default"
  else
    saved_mode=$(_cc_deck_load_mode)
  fi
  local mode="$saved_mode"

  local enter_label
  case "$saved_mode" in
    api)           enter_label="claude-api" ;;
    dangerous)     enter_label="skip-permissions" ;;
    api-dangerous) enter_label="api+skip" ;;
    *)             enter_label="$default_cmd" ;;
  esac

  local session_id cwd

  if command -v fzf &>/dev/null; then
    # Ctrl-K reopens fzf after toggling pin
    while true; do
      # Rebuild pinned entries each loop (reflects pin state changes)
      local pinned_entries=()
      while IFS=$'\t' read -r raw_id cwd_p display; do
        pinned_entries+=("${raw_id}	${cwd_p}	${display}")
      done < <(_cc_deck_load_pinned)

      local all_entries=()
      if [[ ${#pinned_entries[@]} -gt 0 ]]; then
        for e in "${pinned_entries[@]}"; do all_entries+=("$e"); done
        all_entries+=("SEP:		────────────────────────────────────────────────────")
      fi
      for e in "${session_entries[@]}"; do all_entries+=("$e"); done

      local result
      result=$(printf '%s\n' "${all_entries[@]}" \
        | fzf \
          --ansi \
          --delimiter=$'\t' \
          --with-nth=3 \
          --height=60% \
          --reverse \
          --prompt="cc-deck> " \
          --header=$'\033[1;33m[TODO]\033[0m=auto-pinned  \033[1;35m[PIN]\033[0m=manual | Enter: '"${enter_label}"'  ^K: pin toggle  ^O/A/D/X: mode  ESC: quit' \
          --expect=ctrl-o,ctrl-a,ctrl-d,ctrl-x,ctrl-k)

      [[ -z "$result" ]] && return

      local key selected
      key=$(echo "$result" | head -1)
      selected=$(echo "$result" | tail -1)
      [[ -z "$selected" ]] && return

      local raw_id=$(echo "$selected" | cut -f1)
      cwd=$(echo "$selected" | cut -f2)

      [[ "$raw_id" == "SEP:" ]] && continue

      # Ctrl-K: toggle pin and reopen
      if [[ "$key" == "ctrl-k" ]]; then
        case "$raw_id" in
          TODO:*) echo "[cc-deck] TODO is managed by Claude memory" ; sleep 1 ;;
          PIN:*)  _cc_deck_toggle_pin "${raw_id#PIN:}" "$cwd" ; sleep 0.5 ;;
          *)      _cc_deck_toggle_pin "$raw_id" "$cwd" ; sleep 0.5 ;;
        esac
        continue
      fi

      # Mode keys
      case "$key" in
        ctrl-o) mode="default" ;;
        ctrl-a) mode="api" ;;
        ctrl-d) mode="dangerous" ;;
        ctrl-x) mode="api-dangerous" ;;
      esac

      # Strip prefix and break
      case "$raw_id" in
        TODO:*) session_id="${raw_id#TODO:}" ;;
        PIN:*)  session_id="${raw_id#PIN:}" ;;
        *)      session_id="$raw_id" ;;
      esac
      break
    done

  else
    # Fallback: numbered list (fzf not installed)
    echo "[cc-deck] install fzf for TUI: brew install fzf"
    echo "[cc-deck] sessions:"
    local i=1
    local all_entries=()
    for e in "${session_entries[@]}"; do all_entries+=("$e"); done
    for entry in "${all_entries[@]}"; do
      echo "  [$i] $(echo "$entry" | cut -f3)"
      ((i++))
    done
    echo ""
    printf "select number (q to quit): "
    read -r pick
    [[ -z "$pick" || "$pick" == "q" ]] && return
    if ! [[ "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#all_entries[@]} )); then
      echo "invalid number"
      return 1
    fi
    local target="${all_entries[$((pick - 1))]}"
    local raw_id=$(echo "$target" | cut -f1)
    cwd=$(echo "$target" | cut -f2)
    [[ "$raw_id" == "SEP:" ]] && return
    case "$raw_id" in
      TODO:*) session_id="${raw_id#TODO:}" ;;
      PIN:*)  session_id="${raw_id#PIN:}" ;;
      *)      session_id="$raw_id" ;;
    esac
  fi

  _cc_deck_resume "$session_id" "$cwd" "$mode"
}
