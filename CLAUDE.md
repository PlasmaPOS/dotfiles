# PlasmaPOS Dotfiles — Project Instructions

This is the shared dotfiles repository for all PlasmaPOS DevPod cloud workspaces. It configures the development environment when a workspace is created.

## Architecture

```
Host machine                          GCP VM (DevPod workspace)
┌──────────────┐     devpod up       ┌──────────────────────────────────┐
│ DevPod CLI   │ ──────────────────> │ Docker image (light or full)     │
│              │                      │   ├── Node 22, Bun, Claude, Codex│
│ This repo    │ ── cloned into ───> │   └── /home/vscode/.dotfiles/    │
│ (dotfiles)   │                      │       └── install.sh (runs once) │
└──────────────┘                      │                                  │
                                      │ ~/.config/devpod-env  ← env vars │
                                      │ ~/.aliases            ← symlink  │
                                      │ ~/.gitconfig          ← dynamic  │
                                      └──────────────────────────────────┘
```

## Key Files

| File | Purpose | When it runs |
|------|---------|-------------|
| `install.sh` | Main entry point. DevPod executes this once on workspace creation. | `devpod up` |
| `setup-devpod.sh` | One-time local machine setup. Configures GCP provider + git identity. | Manual, on new machines |
| `.aliases` | Shell aliases. Symlinked to `~/.aliases`. | Sourced on every shell session |
| `.git-identity` | Developer's git name/email. **Gitignored.** | Read by `install.sh` |
| `.gh-token` | GitHub PAT. **Gitignored.** | Read by `install.sh` |
| `projects/<name>.env` | Per-project env vars (public values + secret references). | Read by `install.sh` |

## Conventions

### Adding a new project

1. Create `projects/<name>.env` following this format:
   ```bash
   # <name> — Short Description
   # Public values (safe to commit)
   CONVEX_DEPLOYMENT=dev:animal-name-123
   VITE_CONVEX_URL=https://animal-name-123.convex.cloud
   VITE_CLERK_PUBLISHABLE_KEY=pk_test_xxx

   # Secrets (pulled from 1Password at setup time)
   # OP_ITEM: CLERK_SECRET_KEY -> "1Password Item Name"
   ```

2. Public values (`pk_test_*`, Convex URLs, Sentry DSNs) go as plain `KEY=value` lines
3. Secrets (`sk_test_*`, webhook secrets) go as `# OP_ITEM: VAR_NAME -> "1Password Item Name"` comments
4. The project name must match the GitHub repo name (that's how auto-detection works)

### Modifying install.sh

- Every operation must be **idempotent** — install.sh may run multiple times on the same workspace
- Use `grep -q` checks before appending to files
- Use `2>/dev/null || true` for operations that may fail on some systems
- Test changes by running `devpod up --reset` on an existing workspace

### Environment variables

- All env vars go through `~/.config/devpod-env` — never scatter them across `.bashrc`/`.zshrc`/`.profile`
- The env file is sourced from all three shell profiles automatically
- Only `export KEY="value"` format in devpod-env

### Git identity

- Never hardcode names or emails in committed files
- Identity resolution: `.git-identity` file → env vars → GitHub API auto-detection (via GH_TOKEN) → warning
- `.git-identity` is gitignored and only works as a local override — DevPod clones from GitHub, so this file won't exist in remote workspaces. The primary mechanism is GitHub API auto-detection.
- Team-wide git defaults (rebase, autoSetupRemote) are set via `git config --global` in install.sh

## Code Standards

- Use `bun` — never npm/yarn/pnpm
- Shell scripts use `bash` with `set -e`
- No hardcoded personal information in committed files
- Secrets are always gitignored (`.gh-token`, `.git-identity`, `*.key`, `*.pem`)

## Testing Changes

```bash
# Reset and rebuild workspace to test install.sh changes
devpod up <repo> --reset

# SSH in and verify
ssh <repo>.devpod
cat ~/.config/devpod-env     # check env vars loaded
git config --global --list   # check git config
which bun claude codex       # check tools available
```

## Related Repositories

- **[PlasmaPOS/devcontainers](https://github.com/PlasmaPOS/devcontainers)** — Docker images (light + full) that these dotfiles run on top of
