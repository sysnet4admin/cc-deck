#!/bin/zsh

# cc-deck installer
# https://github.com/sysnet4admin/cc-deck

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source $SCRIPT_DIR/cc-deck.zsh"

echo "Installing cc-deck..."

# Check dependencies
if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "Warning: fzf not found. Install it for TUI support:"
  echo "  brew install fzf"
  echo ""
fi

# Add source line to ~/.zshrc
if grep -qF "$SOURCE_LINE" "$ZSHRC" 2>/dev/null; then
  echo "Already installed in $ZSHRC"
else
  echo "" >> "$ZSHRC"
  echo "# cc-deck: Claude Code session browser and task manager" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  echo "Added to $ZSHRC"
fi

echo ""
echo "Done! Run 'source ~/.zshrc' or open a new terminal."
echo "Then type: cc-deck"
