#!/bin/bash

# cc-deck installer
# https://github.com/sysnet4admin/cc-deck
#
# Usage:
#   ./install.sh           auto-detect shell (zsh or bash)
#   ./install.sh --zsh     install for zsh  (~/.zshrc)
#   ./install.sh --bash    install for bash (~/.bashrc)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check dependencies
if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "Warning: fzf not found. Install it for TUI support:"
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "  brew install fzf"
  else
    echo "  sudo apt install fzf   # Debian/Ubuntu"
    echo "  sudo dnf install fzf   # Fedora/RHEL"
  fi
  echo ""
fi

# Determine target shell
TARGET=""
case "${1:-}" in
  --zsh)  TARGET="zsh" ;;
  --bash) TARGET="bash" ;;
  "")
    CURRENT_SHELL="$(basename "$SHELL")"
    case "$CURRENT_SHELL" in
      zsh)  TARGET="zsh" ;;
      bash) TARGET="bash" ;;
      *)
        echo "Error: unsupported shell '$CURRENT_SHELL'. Use --zsh or --bash."
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Usage: $0 [--zsh|--bash]"
    exit 1
    ;;
esac

if [[ "$TARGET" == "zsh" ]]; then
  RC_FILE="$HOME/.zshrc"
  SOURCE_LINE="source $SCRIPT_DIR/cc-deck.zsh"
  RELOAD_CMD="source ~/.zshrc"
else
  RC_FILE="$HOME/.bashrc"
  SOURCE_LINE="source $SCRIPT_DIR/cc-deck.bash"
  RELOAD_CMD="source ~/.bashrc"
fi

echo "Installing cc-deck for $TARGET..."

if grep -qF "$SOURCE_LINE" "$RC_FILE" 2>/dev/null; then
  echo "Already installed in $RC_FILE"
else
  echo "" >> "$RC_FILE"
  echo "# cc-deck: Claude Code session browser and task manager" >> "$RC_FILE"
  echo "$SOURCE_LINE" >> "$RC_FILE"
  echo "Added to $RC_FILE"
fi

echo ""
echo "Done! Run '$RELOAD_CMD' or open a new terminal."
echo "Then type: cc-deck"
