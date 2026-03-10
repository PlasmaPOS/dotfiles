#!/bin/bash
# ─── DevPod Provider Setup ────────────────────────────────────────────
# Run this on a fresh machine to recreate the full DevPod + GCP config.
# Prerequisites: DevPod CLI installed (https://devpod.sh/docs/getting-started/install)
#
# Usage:
#   chmod +x setup-devpod.sh
#   ./setup-devpod.sh
# ──────────────────────────────────────────────────────────────────────
set -e

echo "=== Setting up DevPod with GCP provider ==="

# 1. Add GCP provider (will prompt for gcloud auth if needed)
if ! devpod provider list 2>/dev/null | grep -q gcloud; then
  echo "Adding GCP provider..."
  devpod provider add gcloud
else
  echo "GCP provider already configured"
fi

# 2. Configure GCP provider options
echo "Configuring GCP provider..."
devpod provider set-options gcloud \
  -o PROJECT=plasma-429815 \
  -o ZONE=us-central1-a \
  -o MACHINE_TYPE=n2d-standard-4 \
  -o DISK_SIZE=80 \
  -o INACTIVITY_TIMEOUT=30m

# 3. Set dotfiles URL (auto-applied to all new workspaces)
echo "Configuring dotfiles..."
devpod context set-options -o DOTFILES_URL=https://github.com/PlasmaPOS/dotfiles

# 4. Set GCP as default provider
devpod provider use gcloud

# 5. Configure git identity
# Create a local .git-identity file (gitignored) so install.sh picks it up automatically
echo ""
read -rp "Git user name (e.g. Shlomo Kabareti): " git_name
read -rp "Git user email (e.g. shlomo@plasmapos.com): " git_email

DOTFILES_LOCAL="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$git_name" ] && [ -n "$git_email" ]; then
  cat > "$DOTFILES_LOCAL/.git-identity" <<EOF
GIT_USER_NAME=$git_name
GIT_USER_EMAIL=$git_email
EOF
  echo "Saved git identity to .git-identity (gitignored, local only)"
fi

echo ""
echo "=== DevPod setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Create a workspace:  devpod up <repo>"
echo "  2. SSH into it:         ssh <repo>.devpod"
echo "  3. Auth CLIs once:      claude (device code), codex (device code), gh auth login"
echo ""
echo "For full image (Playwright + Android), override machine type:"
echo "  devpod up <repo> --provider-option MACHINE_TYPE=n2d-standard-8"
echo ""
echo "Projects: dev-agent, plasma, pile, roster, veil, seal, aqua"
