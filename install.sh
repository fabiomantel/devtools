#!/usr/bin/env zsh
# install.sh — wire devtools into your shell
#
# Run once after cloning:  zsh install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVTOOLS_BIN="$REPO_DIR/devtools"
BIN_DIR="$HOME/bin"
LINK="$BIN_DIR/devtools"
ZSHRC="$HOME/.zshrc"

echo "==> devtools installer"

# 1. Create ~/bin if needed
if [[ ! -d "$BIN_DIR" ]]; then
  mkdir -p "$BIN_DIR"
  echo "  created $BIN_DIR"
fi

# 2. Symlink devtools into ~/bin
[[ -x "$DEVTOOLS_BIN" ]] || { echo "Error: $DEVTOOLS_BIN not found or not executable" >&2; exit 1 }
if [[ -L "$LINK" || -e "$LINK" ]]; then
  rm "$LINK"
fi
ln -s "$DEVTOOLS_BIN" "$LINK"
echo "  symlinked $LINK -> $DEVTOOLS_BIN"

# 3. Add ~/bin to PATH in .zshrc if not already there
if ! grep -qF 'export PATH="$HOME/bin:$PATH"' "$ZSHRC"; then
  printf '\n# devtools\nexport PATH="$HOME/bin:$PATH"\n' >> "$ZSHRC"
  echo "  added ~/bin to PATH in $ZSHRC"
else
  echo "  ~/bin already on PATH in $ZSHRC (skipped)"
fi

echo ""
echo "Done. Run:  source ~/.zshrc"
echo "Then test:  devtools"
