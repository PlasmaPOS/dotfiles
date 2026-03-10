#!/bin/bash
set -e

echo "=== Installing dotfiles ==="

# Bun
if [ ! -f "$HOME/.bun/bin/bun" ]; then
  echo "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
fi

# Ensure bun PATH in all shell profiles (including .profile for non-interactive SSH)
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if ! grep -q 'BUN_INSTALL' "$rc" 2>/dev/null; then
    echo '' >> "$rc"
    echo '# Bun' >> "$rc"
    echo 'export BUN_INSTALL="$HOME/.bun"' >> "$rc"
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> "$rc"
  fi
done

# Source bun for this session
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Symlink bun into system PATH for non-interactive SSH sessions
if [ -f "$HOME/.bun/bin/bun" ] && [ ! -f /usr/local/bin/bun ]; then
  sudo ln -sf "$HOME/.bun/bin/bun" /usr/local/bin/bun 2>/dev/null || true
  sudo ln -sf "$HOME/.bun/bin/bunx" /usr/local/bin/bunx 2>/dev/null || true
fi

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

# ─── Environment tokens ───────────────────────────────────────────────
# Tokens are stored in ~/.config/devpod-env and sourced from all shell profiles.
# This file is the single source of truth — no tokens scattered across rc files.
#
# How to inject tokens:
#   Option A: Set GH_TOKEN env var before workspace creation
#   Option B: Place a .gh-token file in the dotfiles repo (gitignored)
#   Option C: After workspace creation, run: echo 'export GH_TOKEN=ghp_xxx' >> ~/.config/devpod-env

ENV_FILE="$HOME/.config/devpod-env"
mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"

# Source the env file from all shell profiles (idempotent)
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  if ! grep -q 'devpod-env' "$rc" 2>/dev/null; then
    echo '' >> "$rc"
    echo '# DevPod environment tokens' >> "$rc"
    echo '[ -f "$HOME/.config/devpod-env" ] && source "$HOME/.config/devpod-env"' >> "$rc"
  fi
done

# Populate GH_TOKEN if available from env or file
if [ -n "$GH_TOKEN" ] && ! grep -q 'GH_TOKEN' "$ENV_FILE" 2>/dev/null; then
  echo "export GH_TOKEN=\"$GH_TOKEN\"" >> "$ENV_FILE"
  echo "GH_TOKEN saved to $ENV_FILE"
elif [ -f "$DOTFILES_DIR/.gh-token" ] && ! grep -q 'GH_TOKEN' "$ENV_FILE" 2>/dev/null; then
  echo "export GH_TOKEN=\"$(cat "$DOTFILES_DIR/.gh-token")\"" >> "$ENV_FILE"
  echo "GH_TOKEN saved from .gh-token file"
fi

# Configure gh + git credential helper if token is available
source "$ENV_FILE" 2>/dev/null || true
if [ -n "$GH_TOKEN" ]; then
  gh auth setup-git 2>/dev/null || true
  echo "gh CLI configured with token auth"
else
  echo "No GH_TOKEN found — run: echo 'export GH_TOKEN=ghp_xxx' >> ~/.config/devpod-env"
fi

# ─── Project env auto-detection ──────────────────────────────────────
# Detect which project this workspace is for and load its env config.
# Public values (Convex URLs, Clerk publishable keys) are stored directly.
# Secret values are marked with OP_ITEM comments for manual or 1Password setup.

PROJECT_NAME=""
# DevPod sets the workspace source as the repo name in /workspaces/<name>
if [ -d "/workspaces" ]; then
  PROJECT_NAME="$(ls /workspaces/ 2>/dev/null | head -1)"
fi
# Fallback: check current directory name
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="$(basename "$(pwd)")"
fi

PROJECT_ENV="$DOTFILES_DIR/projects/$PROJECT_NAME.env"
if [ -f "$PROJECT_ENV" ]; then
  echo "Found project config: $PROJECT_NAME"

  # Load public values into devpod-env (skip comments and OP_ITEM lines)
  while IFS= read -r line; do
    # Skip empty lines, comments, and OP_ITEM references
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Extract var name
    var_name="${line%%=*}"
    # Only add if not already in env file
    if ! grep -q "^export $var_name=" "$ENV_FILE" 2>/dev/null; then
      echo "export $line" >> "$ENV_FILE"
    fi
  done < "$PROJECT_ENV"

  # Report which secrets still need manual setup
  missing_secrets=""
  while IFS= read -r line; do
    if [[ "$line" == "# OP_ITEM:"* ]]; then
      secret_name="$(echo "$line" | sed 's/# OP_ITEM: //' | cut -d' ' -f1)"
      if ! grep -q "^export $secret_name=" "$ENV_FILE" 2>/dev/null; then
        missing_secrets="$missing_secrets  $line\n"
      fi
    fi
  done < "$PROJECT_ENV"

  if [ -n "$missing_secrets" ]; then
    echo ""
    echo "⚠ Missing secrets for $PROJECT_NAME (add to ~/.config/devpod-env):"
    echo -e "$missing_secrets"
    echo "  Run: echo 'export VAR_NAME=value' >> ~/.config/devpod-env"
  else
    echo "All env vars configured for $PROJECT_NAME"
  fi
else
  echo "No project config found for '$PROJECT_NAME' — skipping env auto-setup"
fi

# Re-source env file to pick up project vars
source "$ENV_FILE" 2>/dev/null || true

echo "=== Dotfiles installed ==="
