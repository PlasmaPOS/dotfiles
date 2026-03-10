#!/bin/bash
set -e

echo "=== Installing dotfiles ==="

# Bun
if [ ! -f "$HOME/.bun/bin/bun" ]; then
  echo "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
fi

# Ensure bun PATH in all shell profiles
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if [ -f "$rc" ] || [ "$rc" = "$HOME/.bashrc" ]; then
    if ! grep -q 'BUN_INSTALL' "$rc" 2>/dev/null; then
      echo '' >> "$rc"
      echo '# Bun' >> "$rc"
      echo 'export BUN_INSTALL="$HOME/.bun"' >> "$rc"
      echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> "$rc"
    fi
  fi
done

# Source bun for this session
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Install global tools via bun
echo "Installing global tools..."
bun add -g convex 2>/dev/null || true

# Link dotfiles
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

for file in .gitconfig .aliases; do
  if [ -f "$DOTFILES_DIR/$file" ]; then
    ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
    echo "Linked $file"
  fi
done

# Source aliases in bashrc
if ! grep -q '.aliases' "$HOME/.bashrc" 2>/dev/null; then
  echo '' >> "$HOME/.bashrc"
  echo '# Custom aliases' >> "$HOME/.bashrc"
  echo '[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"' >> "$HOME/.bashrc"
fi

echo "=== Dotfiles installed ==="
