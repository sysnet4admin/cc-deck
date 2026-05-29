# cc-deck: Claude Code session browser and task manager
# https://github.com/sysnet4admin/cc-deck
#
# Usage: source this file in ~/.bashrc
#   source ~/cc-deck/cc-deck.bash
#
# Requirements: fzf (apt/dnf install fzf), python3

# ── Internal file paths ────────────────────────────────────────────────────────
_CC_DECK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_cc_deck_mode_file="$HOME/.claude/.cc-deck-mode"
_cc_deck_pins_file="$HOME/.claude/.cc-deck-pins.json"
_CC_DECK_QUICK_DIR="$HOME/.cc-deck-quick"

# ── OS-specific helpers (BSD = macOS, GNU = Linux) ────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  _cc_deck_find_sessions() { # <dir>
    find "$1" -maxdepth 2 -name "*.jsonl" ! -path "*/subagents/*" \
      -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | awk '{print $2}' | head -100
  }
  _cc_deck_stat_mtime() { stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$1" 2>/dev/null; }
else
  _cc_deck_find_sessions() { # <dir>
    find "$1" -maxdepth 2 -name "*.jsonl" ! -path "*/subagents/*" \
      -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}' | head -100
  }
  _cc_deck_stat_mtime() { stat -c '%y' "$1" 2>/dev/null | cut -c1-16; }
fi

# ── Session file bulk parsing (with mtime cache) ───────────────────────────────
# Output: filepath\tcwd\tpreview\tsize
_cc_deck_extract_all() {
  python3 "$_CC_DECK_DIR/lib/extract_all.py" "$@"
}

# ── Snapshot pruning (lossless: drops old file-history-snapshot entries) ────────
_cc_deck_prune() {
  python3 "$_CC_DECK_DIR/lib/prune_snapshots.py" "$@"
}

# ── Tail-resume (lossy: keep recent turns, gzip-archive the full session) ───────
_cc_deck_tail() {
  python3 "$_CC_DECK_DIR/lib/tail_resume.py" "$@"
}

# ── Load pinned entries ────────────────────────────────────────────────────────
_cc_deck_load_pinned() {
  COLUMNS="${COLUMNS:-80}" python3 "$_CC_DECK_DIR/lib/load_pinned.py" "$_cc_deck_pins_file"
}

# ── Manual pin toggle ──────────────────────────────────────────────────────────
_cc_deck_toggle_pin() {
  local session_id="$1" cwd="$2" preview="$3"
  python3 "$_CC_DECK_DIR/lib/toggle_pin.py" "$session_id" "$cwd" "$_cc_deck_pins_file" "$preview"
}

# ── Delete TODO or PIN entry ───────────────────────────────────────────────────
_cc_deck_delete() {
  python3 "$_CC_DECK_DIR/lib/delete_entry.py" "$1" "$_cc_deck_pins_file"
}

# ── Mode persistence ───────────────────────────────────────────────────────────
_cc_deck_save_mode() { echo "$1" > "$_cc_deck_mode_file" 2>/dev/null; }
_cc_deck_load_mode() {
  local _raw
  _raw=$(cat "$_cc_deck_mode_file" 2>/dev/null)
  case "$_raw" in
    default|api|dangerous|api-dangerous) echo "$_raw" ;;
    claude+skip)     echo "dangerous" ;;
    claude-api+skip) echo "api-dangerous" ;;
    claude-api)      echo "api" ;;
    *)               echo "default" ;;
  esac
}

# ── API mode detection via shell rc files ──────────────────────────────────────
_cc_deck_api_in_rc() {
  local _patterns='ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_BASE_URL'
  local _rc
  for _rc in "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [[ -f "$_rc" ]] || continue
    grep -v '^\s*#' "$_rc" | grep -qE "$_patterns" 2>/dev/null && return 0
  done
  return 1
}

# ── Session resume ─────────────────────────────────────────────────────────────
_cc_deck_resume() {
  local session_id="$1" cwd="$2" mode="${3:-default}"
  local current_dir
  current_dir="$(pwd)"

  if [[ -n "$cwd" && "$cwd" != "$current_dir" ]]; then
    if [[ -d "$cwd" ]]; then
      echo "cd ${cwd/#$HOME/~}"
      cd "$cwd" || return
    else
      echo "[cc-deck] WARNING: '$cwd' is not accessible."
      echo "[cc-deck] claude --resume requires the original directory to be reachable."
      echo "[cc-deck] Mount the drive or navigate there manually, then run:"
      echo "          claude --resume $session_id"
      return
    fi
  fi

  _cc_deck_save_mode "$mode"

  case "$mode" in
    api)           claude-api --resume "$session_id" ;;
    dangerous)     claude --dangerously-skip-permissions --resume "$session_id" ;;
    api-dangerous) claude-api --dangerously-skip-permissions --resume "$session_id" ;;
    *)             ${CLAUDE_DECK_CMD:-claude} --resume "$session_id" ;;
  esac
}

# ── cc-deck ────────────────────────────────────────────────────────────────────
# Browse all Claude Code sessions via fzf TUI and resume selected.
# TODOs from Claude memory and manually pinned sessions appear at the top.
#
# Keys:
#   Enter    resume with last saved mode
#   Ctrl-K   pin / unpin current session (toggle)
#   Ctrl-R   delete selected TODO or PIN entry
#   Ctrl-O   resume with: claude
#   Ctrl-A   resume with: claude-api
#   Ctrl-S   resume with: claude --dangerously-skip-permissions
#   Ctrl-X   resume with: claude-api --dangerously-skip-permissions
#   F1       show key bindings help
#
# Env:
#   CLAUDE_DECK_CMD   override default resume command
cc-deck() {
  # 'cc-deck -q/--quick [prompt]' — ephemeral query, no session kept after exit
  if [[ "$1" == "-q" || "$1" == "--quick" ]]; then
    shift
    if [[ -n "$*" ]]; then
      claude -p --no-session-persistence "$@"
    else
      mkdir -p "$_CC_DECK_QUICK_DIR"
      python3 "$_CC_DECK_DIR/lib/quick_sessions.py" cleanup
      local _marker _old_dir _q_mode
      _marker=$(mktemp)
      _old_dir="$(pwd)"
      _q_mode="$(_cc_deck_load_mode)"
      cd "$_CC_DECK_QUICK_DIR"
      case "$_q_mode" in
        api)           claude-api ;;
        dangerous)     claude --dangerously-skip-permissions ;;
        api-dangerous) claude-api --dangerously-skip-permissions ;;
        *)             ${CLAUDE_DECK_CMD:-claude} ;;
      esac
      cd "$_old_dir"
      python3 "$_CC_DECK_DIR/lib/quick_sessions.py" register "$_marker"
      rm -f "$_marker"
    fi
    return
  fi

  # 'cc-deck update' — manual update trigger
  if [[ "$1" == "update" ]]; then
    echo "[cc-deck] Checking for updates..."
    python3 "$_CC_DECK_DIR/lib/auto_update.py" "$_CC_DECK_DIR" --force
    local flag="$HOME/.claude/.cc-deck-updated"
    if [[ -f "$flag" ]]; then
      local info
      info=$(<"$flag")
      rm -f "$flag"
      echo "[cc-deck] Updated ($info). Reload with: source ~/.bashrc"
    else
      echo "[cc-deck] Already up to date."
    fi
    return
  fi

  # Show pending update notification
  local update_flag="$HOME/.claude/.cc-deck-updated"
  if [[ -f "$update_flag" ]]; then
    local info
    info=$(<"$update_flag")
    rm -f "$update_flag"
    echo "[cc-deck] Updated ($info). Reload with: source ~/.bashrc"
  fi

  # Background auto-update check (24h TTL, non-blocking)
  if [[ -z "$CC_DECK_DISABLE_AUTOUPDATER" ]]; then
    python3 "$_CC_DECK_DIR/lib/auto_update.py" "$_CC_DECK_DIR" >/dev/null 2>&1 &
    disown $!
  fi

  local current_dir
  current_dir="$(pwd)"
  local default_cmd="${CLAUDE_DECK_CMD:-claude}"

  # Compute available modes: CC_DECK_MODES > ANTHROPIC_API_KEY > default only
  local _available_modes
  if [[ -n "$CC_DECK_MODES" ]]; then
    _available_modes="$CC_DECK_MODES"
  elif [[ -n "$ANTHROPIC_API_KEY" || -n "$ANTHROPIC_AUTH_TOKEN" ]] || _cc_deck_api_in_rc; then
    _available_modes="default,api,dangerous,api-dangerous"
  else
    _available_modes="default,dangerous"
  fi
  export _CC_DECK_AVAILABLE_MODES="$_available_modes"

  # Collect recent 100 session files sorted by mtime
  local files=()
  while IFS= read -r f; do
    [[ -f "$f" ]] && files+=("$f")
  done < <(_cc_deck_find_sessions "$HOME/.claude/projects")

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "[cc-deck] no sessions found"
    return
  fi

  # Auto snapshot-prune: losslessly shrink oversized sessions before listing.
  # Scans ALL sessions (not just the recent 100 shown) — bloated files are
  # usually old/unlisted. Conversation lines and original mtime are preserved.
  if [[ -z "$CC_DECK_DISABLE_AUTOPRUNE" ]]; then
    _cc_deck_prune scan-prune --root "$HOME/.claude/projects" \
      --keep "${CC_DECK_SNAPSHOT_KEEP:-3}" \
      --threshold-mb "${CC_DECK_SIZE_CRIT_MB:-100}"
  fi

  # Session entries are (re)built lazily — once up front and again after a
  # Ctrl-G prune, so the list reflects the new state. Oversized sessions are
  # surfaced separately via load_pinned ([S_L]/[S_XL] group), so regular rows
  # carry no size marker.
  local session_entries=()
  local _sess_dirty=1

  # Resolve saved/default mode; reset if saved mode is no longer available
  local saved_mode
  if [[ -n "$CLAUDE_DECK_CMD" ]]; then
    saved_mode="default"
  else
    saved_mode="$(_cc_deck_load_mode)"
    if [[ ",$_available_modes," != *",$saved_mode,"* ]]; then
      saved_mode="${_available_modes%%,*}"
      _cc_deck_save_mode "$saved_mode"
    fi
  fi
  local mode="$saved_mode"

  local session_id cwd
  local _sepline
  _sepline=$(printf '─%.0s' $(seq 1 $(( ${COLUMNS:-80} - 4 ))))

  if command -v fzf &>/dev/null; then
    while true; do
      # Sync mode from file at each iteration (Tab updates file in-place)
      if [[ -n "$CLAUDE_DECK_CMD" ]]; then
        mode="default"
      else
        mode="$(_cc_deck_load_mode)"
      fi

      # (Re)build session entries when dirty (first run or after a prune)
      if (( _sess_dirty )); then
        session_entries=()
        local _f _c _p _sz _sid _mt _scwd _mk
        while IFS=$'\t' read -r _f _c _p _sz; do
          _sid="$(basename "$_f" .jsonl)"
          _mt="$(_cc_deck_stat_mtime "$_f")"
          _scwd="${_c/#$HOME/~}"
          _mk="  "
          [[ "$_c" == "$current_dir" ]] && _mk=$'\033[32m*\033[0m '
          session_entries+=("${_sid}	${_c}	${_mk}${_mt}  ${_scwd}: ${_p:-(no preview)}")
        done < <(_cc_deck_extract_all "${files[@]}")
        if [[ ${#session_entries[@]} -eq 0 ]]; then
          echo "[cc-deck] no sessions found"
          return
        fi
        _sess_dirty=0
      fi

      # Rebuild pinned entries each loop
      local pinned_entries=()
      while IFS=$'\t' read -r raw_id cwd_p display; do
        pinned_entries+=("${raw_id}	${cwd_p}	${display}")
      done < <(_cc_deck_load_pinned)

      local all_entries=()
      if [[ ${#pinned_entries[@]} -gt 0 ]]; then
        for e in "${pinned_entries[@]}"; do all_entries+=("$e"); done
        all_entries+=("SEP:		${_sepline}")
      fi
      for e in "${session_entries[@]}"; do all_entries+=("$e"); done

      local E=$'\033'
      local mcolor mlabel
      case "$mode" in
        api)           mcolor="${E}[1;34m"; mlabel="claude-api" ;;
        dangerous)     mcolor="${E}[1;31m"; mlabel="claude+skip" ;;
        api-dangerous) mcolor="${E}[1;36m"; mlabel="claude-api+skip" ;;
        *)             mcolor="${E}[1;38;2;217;119;87m"; mlabel="$default_cmd" ;;
      esac
      local header="${E}[1;33m[TODO]${E}[0m=auto-pinned  ${E}[1;35m[PIN]${E}[0m=manual | ^K: pin  ^R: rm  ^Q: ask  ^G: prune  ^E: trim  Tab: cycle  F1: help | ${mcolor}[${mlabel}]${E}[0m"

      local result
      result=$(printf '%s\n' "${all_entries[@]}" \
        | fzf \
          --ansi \
          --delimiter=$'\t' \
          --with-nth=3 \
          --height=60% \
          --reverse \
          --prompt="cc-deck> " \
          "--header=$header" \
          "--bind=tab:transform:python3 \"$_CC_DECK_DIR/lib/cycle_mode.py\"" \
          "--bind=f1:execute(python3 \"$_CC_DECK_DIR/lib/show_help.py\")" \
          --expect=ctrl-o,ctrl-a,ctrl-s,ctrl-x,ctrl-k,ctrl-r,ctrl-q,ctrl-g,ctrl-e,ctrl-m)

      [[ -z "$result" ]] && return

      local key selected
      key="$(echo "$result" | head -1)"
      selected="$(echo "$result" | tail -1)"
      # ctrl-m is Enter (0x0D); normalize to empty string
      [[ "$key" == "ctrl-m" ]] && key=""
      [[ -z "$selected" ]] && return

      local raw_id
      raw_id="$(echo "$selected" | cut -f1)"
      cwd="$(echo "$selected" | cut -f2)"

      [[ "$raw_id" == "SEP:" ]] && continue

      # [Quick] entry: open quick session list
      if [[ "$raw_id" == "QUICK:" ]]; then
        local q_result q_key q_selected q_sid
        q_result=$(python3 "$_CC_DECK_DIR/lib/quick_sessions.py" list \
          | fzf --ansi --delimiter=$'\t' --with-nth=3 \
                --height=60% --reverse \
                --prompt="quick> " \
                --header=$'\033[1;32m[Quick]\033[0m sessions | Enter: resume  Ctrl-R: delete  ESC: back' \
                --expect=ctrl-r)
        if [[ -z "$q_result" ]]; then
          continue
        fi
        q_key=$(echo "$q_result" | head -1)
        q_selected=$(echo "$q_result" | tail -1)
        if [[ "$q_key" == "ctrl-r" && -n "$q_selected" ]]; then
          q_sid=$(echo "$q_selected" | cut -f1)
          python3 "$_CC_DECK_DIR/lib/quick_sessions.py" delete-by-id "$q_sid"
          sleep 0.3
          continue
        fi
        if [[ -n "$q_selected" ]]; then
          session_id=$(echo "$q_selected" | cut -f1)
          cwd="$_CC_DECK_QUICK_DIR"
          break
        fi
        continue
      fi

      # Ctrl-Q: instant query (runs in shell, not fzf execute — avoids Bun TTY issue)
      if [[ "$key" == "ctrl-q" ]]; then
        stty sane 2>/dev/null
        clear
        echo ""
        local _qq=""
        read -e -p "  Quick query: " _qq
        if [[ -n "$_qq" ]]; then
          echo ""
          claude -p --no-session-persistence "$_qq"
          echo ""
          printf "  Press any key to return..."
          read -rsn1
        fi
        clear
        continue
      fi

      # Ctrl-G: prune old snapshots on the selected session (lossless, silent).
      # Works on TODO/PIN/large rows too (strip prefix → underlying session).
      # No output — the refreshed size in the manage group is the feedback.
      if [[ "$key" == "ctrl-g" ]]; then
        local _gid=""
        case "$raw_id" in
          QUICK:*|SEP:) ;;  # not a single prunable session
          TODO:*) _gid="${raw_id#TODO:}" ;;
          PIN:*)  _gid="${raw_id#PIN:}" ;;
          *)      _gid="$raw_id" ;;
        esac
        if [[ -n "$_gid" ]]; then
          local _fp
          _fp=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${_gid}.jsonl" \
            ! -path "*/subagents/*" 2>/dev/null | head -1)
          [[ -n "$_fp" ]] && _cc_deck_prune prune "$_fp" --keep "${CC_DECK_SNAPSHOT_KEEP:-3}" >/dev/null 2>&1 && _sess_dirty=1
        fi
        continue
      fi

      # Ctrl-E: tail-resume — trim to recent turns (LOSSY; archives full first).
      # Works on TODO/PIN/large rows too (strip prefix → underlying session).
      if [[ "$key" == "ctrl-e" ]]; then
        local _tid=""
        case "$raw_id" in
          QUICK:*|SEP:) ;;
          TODO:*) _tid="${raw_id#TODO:}" ;;
          PIN:*)  _tid="${raw_id#PIN:}" ;;
          *)      _tid="$raw_id" ;;
        esac
        if [[ -n "$_tid" ]]; then
          local _tfp
          _tfp=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${_tid}.jsonl" \
            ! -path "*/subagents/*" 2>/dev/null | head -1)
          if [[ -n "$_tfp" ]]; then
            stty sane 2>/dev/null; clear; echo ""
            _cc_deck_tail dry-run "$_tfp" --keep-turns "${CC_DECK_TAIL_KEEP:-10}"
            echo ""
            local _ans=""
            read -e -p "  Trim to recent turns? Full session is gzip-archived first. [y/N] " _ans
            if [[ "$_ans" == [yY]* ]]; then
              _cc_deck_tail trim "$_tfp" --keep-turns "${CC_DECK_TAIL_KEEP:-10}" >/dev/null 2>&1
              _sess_dirty=1
            fi
          fi
        fi
        clear
        continue
      fi

      # Ctrl-K: toggle pin and reopen
      if [[ "$key" == "ctrl-k" ]]; then
        local display preview
        display="$(echo "$selected" | cut -f3)"
        preview="${display#*: }"
        case "$raw_id" in
          TODO:*) echo "[cc-deck] TODO is managed by Claude memory" ; sleep 1 ;;
          PIN:*)  _cc_deck_toggle_pin "${raw_id#PIN:}" "$cwd" "$preview" ; sleep 0.8 ;;
          *)      _cc_deck_toggle_pin "$raw_id" "$cwd" "$preview" ; sleep 0.8 ;;
        esac
        clear
        continue
      fi

      # Ctrl-R: delete TODO or PIN only
      if [[ "$key" == "ctrl-r" ]]; then
        case "$raw_id" in
          TODO:*|PIN:*)
            _cc_deck_delete "$raw_id"
            sleep 0.5
            ;;
        esac
        clear
        continue
      fi

      # Mode switch: only apply if mode is available
      case "$key" in
        ctrl-o) [[ ",$_available_modes," == *,default,* ]] && mode="default" ;;
        ctrl-a) [[ ",$_available_modes," == *,api,* ]] && mode="api" ;;
        ctrl-s) [[ ",$_available_modes," == *,dangerous,* ]] && mode="dangerous" ;;
        ctrl-x) [[ ",$_available_modes," == *,api-dangerous,* ]] && mode="api-dangerous" ;;
        *)      [[ -z "$CLAUDE_DECK_CMD" ]] && mode="$(_cc_deck_load_mode)" ;;
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
    echo "[cc-deck] install fzf for TUI: sudo apt install fzf"
    echo "[cc-deck] sessions:"
    local i=1
    local all_entries=()
    for e in "${session_entries[@]}"; do all_entries+=("$e"); done
    for entry in "${all_entries[@]}"; do
      echo "  [$i] $(echo "$entry" | cut -f3)"
      ((i++))
    done
    echo ""
    read -rp "select number (q to quit): " pick
    [[ -z "$pick" || "$pick" == "q" ]] && return
    if ! [[ "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#all_entries[@]} )); then
      echo "invalid number"
      return 1
    fi
    local target="${all_entries[$((pick - 1))]}"
    raw_id="$(echo "$target" | cut -f1)"
    cwd="$(echo "$target" | cut -f2)"
    [[ "$raw_id" == "SEP:" ]] && return
    case "$raw_id" in
      TODO:*) session_id="${raw_id#TODO:}" ;;
      PIN:*)  session_id="${raw_id#PIN:}" ;;
      *)      session_id="$raw_id" ;;
    esac
  fi

  _cc_deck_resume "$session_id" "$cwd" "$mode"
}
