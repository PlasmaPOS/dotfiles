#!/bin/bash
# ─── Inject Secrets from .env.local into DevPod Workspace ────────────
# Scrapes secret keys from the project's local .env.local files and
# injects them into the remote DevPod workspace's ~/.config/devpod-env.
#
# Usage:
#   ./inject-secrets.sh <project> [secrets-file]
#
# Examples:
#   ./inject-secrets.sh pile                          # auto-finds .env.local
#   ./inject-secrets.sh pile ~/Projects/pile/apps/backend/.env.local
#   ./inject-secrets.sh pile --dry-run                 # preview without injecting
# ──────────────────────────────────────────────────────────────────────
set -e

PROJECT="${1:-}"
SECRETS_FILE="${2:-}"
DRY_RUN=false

if [ "$PROJECT" = "--dry-run" ]; then
  echo "Usage: inject-secrets.sh <project> [secrets-file] [--dry-run]"
  exit 1
fi

# Check for --dry-run flag in any position
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

if [ -z "$PROJECT" ]; then
  echo "Usage: inject-secrets.sh <project> [secrets-file] [--dry-run]"
  echo ""
  echo "Projects: dev-agent, plasma, pile, roster, veil, seal, aqua"
  exit 1
fi

# Auto-find .env.local if not specified
if [ -z "$SECRETS_FILE" ]; then
  # Try common locations
  for candidate in \
    "$HOME/Projects/$PROJECT/apps/backend/.env.local" \
    "$HOME/Projects/$PROJECT/.env.local" \
    "$HOME/Projects/$PROJECT/apps/web/.env.local"; do
    if [ -f "$candidate" ]; then
      SECRETS_FILE="$candidate"
      break
    fi
  done
fi

if [ -z "$SECRETS_FILE" ] || [ ! -f "$SECRETS_FILE" ]; then
  echo "ERROR: No .env.local found for $PROJECT"
  echo "Specify path: ./inject-secrets.sh $PROJECT /path/to/.env.local"
  exit 1
fi

echo "=== Injecting secrets for $PROJECT ==="
echo "Source: $SECRETS_FILE"
echo ""

# Common secret key patterns (sk_test_*, whsec_*, re_*, etc.)
SECRET_PATTERNS=(
  "CLERK_SECRET_KEY"
  "STRIPE_SECRET_KEY"
  "STRIPE_WEBHOOK_SECRET"
  "PLAID_CLIENT_ID"
  "PLAID_SECRET"
  "RESEND_API_KEY"
  "SENTRY_AUTH_TOKEN"
  "SENTRY_DSN"
  "OPENAI_API_KEY"
)

# Also read keys from the project .env file's OP_ITEM comments
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ENV="$DOTFILES_DIR/projects/$PROJECT.env"
if [ -f "$PROJECT_ENV" ]; then
  while IFS= read -r line; do
    if [[ "$line" == "# OP_ITEM:"* ]]; then
      key=$(echo "$line" | sed 's/# OP_ITEM: //' | cut -d' ' -f1)
      SECRET_PATTERNS+=("$key")
    fi
  done < "$PROJECT_ENV"
fi

injected=0
skipped=0

for key in "${SECRET_PATTERNS[@]}"; do
  val=$(grep "^${key}=" "$SECRETS_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)
  if [ -n "$val" ]; then
    # Check if already in workspace env
    existing=$(ssh "$PROJECT.devpod" "grep \"^export ${key}=\" ~/.config/devpod-env 2>/dev/null" || true)
    if [ -n "$existing" ]; then
      echo "  ⊙ $key (already present)"
      skipped=$((skipped + 1))
    else
      if [ "$DRY_RUN" = true ]; then
        echo "  + $key=${val:0:10}... (dry run)"
      else
        ssh "$PROJECT.devpod" "echo 'export ${key}=${val}' >> ~/.config/devpod-env" 2>/dev/null
        echo "  ✓ $key=${val:0:10}..."
      fi
      injected=$((injected + 1))
    fi
  fi
done

# Also inject GH_TOKEN if available
GH_TOKEN_VAL=$(gh auth token 2>/dev/null || echo "")
if [ -n "$GH_TOKEN_VAL" ]; then
  existing=$(ssh "$PROJECT.devpod" "grep \"^export GH_TOKEN=\" ~/.config/devpod-env 2>/dev/null" || true)
  if [ -z "$existing" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  + GH_TOKEN=${GH_TOKEN_VAL:0:10}... (dry run)"
    else
      ssh "$PROJECT.devpod" "echo 'export GH_TOKEN=${GH_TOKEN_VAL}' >> ~/.config/devpod-env" 2>/dev/null
      echo "  ✓ GH_TOKEN=${GH_TOKEN_VAL:0:10}..."
    fi
    injected=$((injected + 1))
  else
    echo "  ⊙ GH_TOKEN (already present)"
    skipped=$((skipped + 1))
  fi
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "=== Dry run: $injected would be injected, $skipped already present ==="
else
  echo "=== Done: $injected injected, $skipped already present ==="
fi