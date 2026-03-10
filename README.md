# PlasmaPOS DevPod Dotfiles

Shared dotfiles for all DevPod cloud workspaces. Auto-installed via `--dotfiles` flag.

## What it does

- Installs bun and adds it to PATH (all shells)
- Installs global tools: convex CLI
- Sets up git config (name, email, rebase on pull)
- Adds common aliases for bun, git, convex

## Usage

Automatically applied when creating workspaces:

```bash
devpod context set-options -o DOTFILES_URL=https://github.com/PlasmaPOS/dotfiles
```

Or per-workspace:

```bash
devpod up <repo> --dotfiles https://github.com/PlasmaPOS/dotfiles
```
