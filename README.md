# PlasmaPOS DevPod Dotfiles

Shared dotfiles for all DevPod cloud workspaces. Auto-installed via `--dotfiles` flag.

## What it does

- Installs bun and adds it to PATH (all shells + non-interactive SSH)
- Installs global tools: convex CLI
- Sets up git config (name, email, rebase on pull)
- Adds common aliases for bun, git, convex
- Configures GitHub CLI auth if `GH_TOKEN` is available
- Creates `~/.config/devpod-env` for persistent environment tokens

## First-Time Auth (per workspace)

After creating a workspace, auth into each CLI once:

```bash
ssh dev-agent.devpod

# GitHub CLI
gh auth login            # or auto-configured if GH_TOKEN is set

# Claude Code (uses your Claude Pro/Max subscription)
claude                   # shows device code URL — approve in browser

# Codex (uses your ChatGPT subscription)
codex                    # shows device code URL — approve in browser
```

Auth tokens persist in the container. Only need to re-auth after `--reset`.

## GitHub CLI Auth

Three ways to inject your GitHub PAT so `gh` + `git push` work immediately:

```bash
# Option A: Set before workspace creation (auto-detected by install.sh)
export GH_TOKEN=ghp_xxx
devpod up <repo>

# Option B: Place .gh-token file in this repo (gitignored)
echo "ghp_xxx" > .gh-token

# Option C: Add manually after workspace creation
ssh dev-agent.devpod 'echo "export GH_TOKEN=ghp_xxx" >> ~/.config/devpod-env'
```

## Project Auto-Detection

Each project has a `projects/<name>.env` file with its public env vars (Convex URLs, Clerk publishable keys, etc.). When a workspace is created, `install.sh` detects the project name from the workspace directory and auto-loads the right config.

**What's automatic:**
- Public values (Convex URL, Clerk publishable key, Stripe publishable key) are loaded into `~/.config/devpod-env`
- On first setup, a warning lists any missing secrets

**What you need to add manually (once per workspace):**
```bash
# Secrets can't be committed to git — add them after workspace creation
ssh pile.devpod 'echo "export CLERK_SECRET_KEY=sk_test_xxx" >> ~/.config/devpod-env'
```

Currently configured projects: `dev-agent`, `plasma`, `pile`, `roster`, `veil`, `seal`, `aqua`

## Environment Tokens

The `~/.config/devpod-env` file is sourced by all shell profiles. Use it for any env vars that need to persist across sessions:

```bash
ssh dev-agent.devpod 'echo "export MY_VAR=value" >> ~/.config/devpod-env'
```

## Usage

Automatically applied when creating workspaces:

```bash
devpod context set-options -o DOTFILES_URL=https://github.com/PlasmaPOS/dotfiles
```

Or per-workspace:

```bash
devpod up <repo> --dotfiles https://github.com/PlasmaPOS/dotfiles
```
