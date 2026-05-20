# cc-deck: Claude Code session browser and task manager
# https://github.com/sysnet4admin/cc-deck
#
# Usage: source this file in ~/.zshrc
#   source ~/cc-deck/cc-deck.zsh
#
# Requirements: fzf (brew install fzf), python3

# ── Internal file paths ────────────────────────────────────────────────────────
_CC_DECK_DIR="${0:A:h}"
_cc_deck_mode_file="$HOME/.claude/.cc-deck-mode"
_cc_deck_pins_file="$HOME/.claude/.cc-deck-pins.json"

# ── Session file bulk parsing (with mtime cache) ───────────────────────────────
# Output: filepath\tcwd\tpreview
_cc_deck_extract_all() {
  python3 "$_CC_DECK_DIR/lib/extract_all.py" "$@"
}

# ── Load pinned entries (memory TODOs + manual pins) ───────────────────────────
# Output: TODO:<session_id>\t<cwd>\t[TODO] <short_cwd>: <desc>
#         PIN:<session_id>\t<cwd>\t[PIN]  <short_cwd>: <desc>
_cc_deck_load_pinned() {
  python3 "$_CC_DECK_DIR/lib/load_pinned.py" "$_cc_deck_pins_file"
}

# ── Manual pin toggle ──────────────────────────────────────────────────────────
_cc_deck_toggle_pin() {
  local session_id="$1"
  local cwd="$2"
  local preview="$3"
  python3 "$_CC_DECK_DIR/lib/toggle_pin.py" "$session_id" "$cwd" "$_cc_deck_pins_file" "$preview"
}

# ── Delete TODO or PIN entry ───────────────────────────────────────────────────
_cc_deck_delete() {
  local raw_id="$1"
  python3 "$_CC_DECK_DIR/lib/delete_entry.py" "$raw_id" "$_cc_deck_pins_file"
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

  if [[ -n "$cwd" && "$cwd" != "$current_dir" ]]; then
    if [[ -d "$cwd" ]]; then
      echo "cd ${cwd/#$HOME/~}"
      cd "$cwd"
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
#   Ctrl-R   delete selected TODO or PIN entry
#   Ctrl-O   resume with: claude
#   Ctrl-A   resume with: claude-api
#   Ctrl-S   resume with: claude --dangerously-skip-permissions
#   Ctrl-X   resume with: claude-api --dangerously-skip-permissions
#   F1       show key bindings help
#
# Env:
#   CLAUDE_DECK_CMD   override default resume command (e.g. "claude-api")
cc-deck() {
  # 'cc-deck update' — manual update trigger
  if [[ "$1" == "update" ]]; then
    echo "[cc-deck] Checking for updates..."
    python3 "$_CC_DECK_DIR/lib/auto_update.py" "$_CC_DECK_DIR" --force
    local flag="$HOME/.claude/.cc-deck-updated"
    if [[ -f "$flag" ]]; then
      local info=$(<"$flag")
      rm -f "$flag"
      echo "[cc-deck] Updated ($info). Reload with: source ~/.zshrc"
    else
      echo "[cc-deck] Already up to date."
    fi
    return
  fi

  # Show pending update notification
  local update_flag="$HOME/.claude/.cc-deck-updated"
  if [[ -f "$update_flag" ]]; then
    local info=$(<"$update_flag")
    rm -f "$update_flag"
    echo "[cc-deck] Updated ($info). Reload with: source ~/.zshrc"
  fi

  # Background auto-update check (24h TTL, non-blocking)
  if [[ -z "$CC_DECK_DISABLE_AUTOUPDATER" ]]; then
    python3 "$_CC_DECK_DIR/lib/auto_update.py" "$_CC_DECK_DIR" >/dev/null 2>&1 &!
  fi

  local current_dir="$(pwd)"
  local default_cmd="${CLAUDE_DECK_CMD:-claude}"

  # Compute available modes: CC_DECK_MODES > ANTHROPIC_API_KEY > default only
  local _available_modes
  if [[ -n "$CC_DECK_MODES" ]]; then
    _available_modes="$CC_DECK_MODES"
  elif [[ -n "$ANTHROPIC_API_KEY" ]]; then
    _available_modes="default,api,dangerous,api-dangerous"
  else
    _available_modes="default,dangerous"
  fi
  export _CC_DECK_AVAILABLE_MODES="$_available_modes"

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

  # Resolve saved/default mode; reset if saved mode is no longer available
  local saved_mode
  if [[ -n "$CLAUDE_DECK_CMD" ]]; then
    saved_mode="default"
  else
    saved_mode=$(_cc_deck_load_mode)
    if [[ ",$_available_modes," != *",$saved_mode,"* ]]; then
      saved_mode="${_available_modes%%,*}"
      _cc_deck_save_mode "$saved_mode"
    fi
  fi
  local mode="$saved_mode"

  local session_id cwd

  if command -v fzf &>/dev/null; then
    while true; do
      # Sync mode from file at each iteration (Tab updates file in-place)
      if [[ -n "$CLAUDE_DECK_CMD" ]]; then
        mode="default"
      else
        mode=$(_cc_deck_load_mode)
      fi
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

      local E=$'\033'
      local mcolor mlabel
      case "$mode" in
        api)           mcolor="${E}[1;34m"; mlabel="claude-api" ;;
        dangerous)     mcolor="${E}[1;31m"; mlabel="claude+skip" ;;
        api-dangerous) mcolor="${E}[1;36m"; mlabel="claude-api+skip" ;;
        *)             mcolor="${E}[1;38;2;217;119;87m"; mlabel="$default_cmd" ;;
      esac
      local header="${E}[1;33m[TODO]${E}[0m=auto-pinned  ${E}[1;35m[PIN]${E}[0m=manual | ^K: pin  ^R: rm  Tab: cycle  F1: help  ESC: quit | ${mcolor}[${mlabel}]${E}[0m"

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
          --expect=ctrl-o,ctrl-a,ctrl-s,ctrl-x,ctrl-k,ctrl-r,ctrl-m)

      [[ -z "$result" ]] && return

      local key selected
      key=$(echo "$result" | head -1)
      selected=$(echo "$result" | tail -1)
      # ctrl-m is Enter (0x0D); normalize to empty string
      [[ "$key" == "ctrl-m" ]] && key=""
      [[ -z "$selected" ]] && return

      local raw_id=$(echo "$selected" | cut -f1)
      cwd=$(echo "$selected" | cut -f2)

      [[ "$raw_id" == "SEP:" ]] && continue

      # Ctrl-K: toggle pin and reopen
      if [[ "$key" == "ctrl-k" ]]; then
        local display=$(echo "$selected" | cut -f3)
        local preview="${display#*: }"
        case "$raw_id" in
          TODO:*) echo "[cc-deck] TODO is managed by Claude memory" ; sleep 1 ;;
          PIN:*)  _cc_deck_toggle_pin "${raw_id#PIN:}" "$cwd" "$preview" ; sleep 0.8 ;;
          *)      _cc_deck_toggle_pin "$raw_id" "$cwd" "$preview" ; sleep 0.8 ;;
        esac
        clear
        continue
      fi

      # Ctrl-R: delete TODO or PIN only (silently ignore regular sessions)
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
        *)      [[ -z "$CLAUDE_DECK_CMD" ]] && mode=$(_cc_deck_load_mode) ;;
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
