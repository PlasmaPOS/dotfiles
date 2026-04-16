#!/bin/bash
# ─── Sync Local Env to DevPod Workspace ──────────────────────────────
# Your laptop is the source of truth. This script:
#   1. Copies all .env.local files from local project → workspace (frameworks read these)
#   2. Scrapes cross-cutting vars into ~/.config/devpod-env (SSH non-interactive)
#   3. Injects GH_TOKEN if available
#
# Usage:
#   sync-env.sh <project>            # full sync
#   sync-env.sh <project> --dry-run  # preview only
# ──────────────────────────────────────────────────────────────────────
set -e

PROJECT="${1:-}"
DRY_RUN=false

for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then DRY_RUN=true; fi
done

if [ -z "$PROJECT" ] || [ "$PROJECT" = "--dry-run" ]; then
  echo "Usage: sync-env.sh <project> [--dry-run]"
  echo ""
  echo "Syncs .env.local files + secrets from ~/Projects/<project> → DevPod workspace."
  echo "Projects: dev-agent, plasma, pile, roster, veil, seal, aqua"
  exit 1
fi

LOCAL_ROOT="$HOME/Projects/$PROJECT"
WORKSPACE="/workspaces/$PROJECT"

# ── Preflight ────────────────────────────────────────────────────────
if [ ! -d "$LOCAL_ROOT" ]; then
  echo "ERROR: $LOCAL_ROOT not found"
  exit 1
fi

if ! ssh "$PROJECT.devpod" "true" 2>/dev/null; then
  echo "ERROR: Can't reach $PROJECT.devpod — is the workspace running?"
  echo "  Run: devpod up $PROJECT"
  exit 1
fi

echo "=== Syncing env for $PROJECT ==="
echo "Local:   $LOCAL_ROOT"
echo "Remote:  $PROJECT.devpod:$WORKSPACE"
echo ""

# ── Step 1: Copy .env.local files ────────────────────────────────────
# These are gitignored locally. Frameworks (Vite, Convex, Expo) read
# them by convention. We push the whole file, not individual vars.

ENV_FILES=""
while IFS= read -r f; do
  relpath="${f#$LOCAL_ROOT/}"
  ENV_FILES="$ENV_FILES$relpath "
done < <(find "$LOCAL_ROOT" -name ".env.local" -not -path "*/node_modules/*" | sort)

if [ -z "$ENV_FILES" ]; then
  echo "⚠ No .env.local files found in $LOCAL_ROOT"
else
  echo "── .env.local files ──"
  for relpath in $ENV_FILES; do
    [ -z "$relpath" ] && continue
    local_file="$LOCAL_ROOT/$relpath"
    line_count=$(grep -cv '^#\|^$' "$local_file" 2>/dev/null || echo 0)
    if [ "$DRY_RUN" = true ]; then
      echo "  + $relpath ($line_count vars) — dry run"
    else
      ssh "$PROJECT.devpod" "mkdir -p $WORKSPACE/$(dirname "$relpath")" 2>/dev/null
      cat "$local_file" | ssh "$PROJECT.devpod" "cat > $WORKSPACE/$relpath" 2>/dev/null
      echo "  ✓ $relpath ($line_count vars)"
    fi
  done
fi

echo ""

# ── Step 2: Scrape cross-cutting vars into ~/.config/devpod-env ───────
# The .env.local files are scoped per-app. devpod-env is the unified
# source for SSH non-interactive sessions. We only scrape keys that
# need to be available outside framework context (secrets + deployment refs).

echo "── devpod-env sync ──"

# Patterns to include in devpod-env (secrets + cross-app refs)
SCRAPE_PATTERN="^(CLERK_SECRET|CLERK_WEBHOOK|STRIPE_SECRET|STRIPE_WEBHOOK|PLAID_CLIENT|PLAID_SECRET|RESEND|SENTRY_AUTH|SENTRY_DSN|OPENAI|CONVEX_DEPLOYMENT|CONVEX_URL|CONVEX_SITE|VITE_CONVEX|VITE_CLERK_PUBLISHABLE|EXPO_PUBLIC_CONVEX|EXPO_PUBLIC_CLERK|GH_TOKEN)"

# Collect all key=value pairs into a temp file (one per line)
# Handles inline comments by cutting at first # after the value
TMP_KEYS=$(mktemp)
for relpath in $ENV_FILES; do
  [ -z "$relpath" ] && continue
  env_file="$LOCAL_ROOT/$relpath"
  [ ! -f "$env_file" ] && continue
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    [ -z "$key" ] && continue
    val="${line#*=}"
    val="${val%%#*}"
    val=$(echo "$val" | sed 's/[[:space:]]*$//')
    echo "$key=$val" >> "$TMP_KEYS"
  done < "$env_file"
done

# Dedup: last occurrence of each key wins
TMP_DEDUP=$(mktemp)
awk -F= '{a[$1]=$0} END {for(k in a) print a[k]}' "$TMP_KEYS" | sort > "$TMP_DEDUP"

# Filter to scrape pattern and inject into devpod-env
injected=0
skipped=0
while IFS='=' read -r key val; do
  [ -z "$key" ] && continue
  if ! echo "$key" | grep -qE "$SCRAPE_PATTERN" 2>/dev/null; then
    continue
  fi
  existing=$(ssh "$PROJECT.devpod" "grep \"^export ${key}=\" ~/.config/devpod-env 2>/dev/null" </dev/null || true)
  if [ -n "$existing" ]; then
    echo "  ⊙ $key (already present)"
    skipped=$((skipped + 1))
  else
    if [ "$DRY_RUN" = true ]; then
      echo "  + $key=${val:0:12}... (dry run)"
    else
      ssh "$PROJECT.devpod" "echo 'export ${key}=${val}' >> ~/.config/devpod-env" </dev/null 2>/dev/null
      echo "  ✓ $key=${val:0:12}..."
    fi
    injected=$((injected + 1))
  fi
done < "$TMP_DEDUP"

rm -f "$TMP_KEYS" "$TMP_DEDUP"

# ── Step 3: GH_TOKEN ────────────────────────────────────────────────
GH_TOKEN_VAL=$(gh auth token 2>/dev/null || echo "")
if [ -n "$GH_TOKEN_VAL" ]; then
  existing=$(ssh "$PROJECT.devpod" "grep \"^export GH_TOKEN=\" ~/.config/devpod-env 2>/dev/null" </dev/null || true)
  if [ -z "$existing" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  + GH_TOKEN=${GH_TOKEN_VAL:0:12}... (dry run)"
    else
      ssh "$PROJECT.devpod" "echo 'export GH_TOKEN=${GH_TOKEN_VAL}' >> ~/.config/devpod-env" </dev/null 2>/dev/null
      echo "  ✓ GH_TOKEN=${GH_TOKEN_VAL:0:12}..."
    fi
    injected=$((injected + 1))
  else
    echo "  ⊙ GH_TOKEN (already present)"
    skipped=$((skipped + 1))
  fi
else
  echo "  ⊘ GH_TOKEN (not available locally — run gh auth login)"
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "=== Dry run complete ==="
else
  echo "=== Done ==="
fi