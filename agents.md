# DevPod Workspace Agent Guide

This document is for AI coding agents (Claude Code, Codex, or any LLM-based tool) running inside a PlasmaPOS DevPod cloud workspace. Read this before doing anything else.

## Where You Are

You are running inside a Docker container on a GCP VM. The container is based on a prebuild image from [PlasmaPOS/devcontainers](https://github.com/PlasmaPOS/devcontainers).

```
GCP VM (n2d-standard-4 or n2d-standard-8)
└── Docker container
    ├── /workspaces/<project-name>/   ← Your project code (git repo)
    ├── /home/vscode/                 ← Home directory (default user: vscode)
    │   ├── .config/devpod-env        ← All environment variables
    │   ├── .aliases                  ← Shell aliases (symlink)
    │   ├── .bun/                     ← Bun installation
    │   └── .gitconfig                ← Git config (dynamic)
    └── /usr/local/bin/               ← System-wide binaries
        ├── bun, bunx                 ← Symlinks to ~/.bun/bin/
        ├── claude                    ← Claude Code CLI
        └── codex                     ← Codex CLI
```

## Identify Your Project

```bash
# The workspace name = project name = repo name
ls /workspaces/
# Output: dev-agent  (or plasma, pile, roster, veil, seal, aqua)
```

Your project code is at `/workspaces/<project-name>/`. This is a git repo cloned from `PlasmaPOS/<project-name>`.

## Available Tools

| Tool | Path | Version | Notes |
|------|------|---------|-------|
| **bun** | `/usr/local/bin/bun` | latest | Package manager. **Always use bun, never npm/yarn/pnpm.** |
| **node** | `/usr/bin/node` | 22.x | System-wide. Used by Claude Code and Codex internally. |
| **convex** | `~/.bun/bin/convex` | latest | Convex CLI. Also via `bunx convex` or alias `cx`. |
| **claude** | `/usr/local/bin/claude` | latest | Claude Code CLI. Auth via OAuth device code. |
| **codex** | `/usr/local/bin/codex` | latest | OpenAI Codex CLI. Auth via OAuth device code. |
| **gh** | `/usr/bin/gh` | latest | GitHub CLI. Auth via `GH_TOKEN` in devpod-env. |
| **git** | `/usr/bin/git` | latest | Pre-configured with identity and team defaults. |

### Full image only (plasma, pile, roster, veil)

| Tool | Path | Notes |
|------|------|-------|
| **playwright** | via `bunx playwright` | Chromium browser at `~/.cache/ms-playwright/` |
| **agent-device** | `~/.bun/bin/agent-device` | iOS/Android device automation |
| **adb** | `/opt/android-sdk/platform-tools/adb` | Android Debug Bridge |
| **emulator** | `/opt/android-sdk/emulator/emulator` | AVD: `test-device` (Pixel 6, API 34) |

## Environment Variables

All env vars are in `~/.config/devpod-env`. Source it or read it directly:

```bash
source ~/.config/devpod-env

# Or read specific values
grep CONVEX_URL ~/.config/devpod-env
grep CLERK ~/.config/devpod-env
```

### What's available

| Variable | Example | Available? |
|----------|---------|-----------|
| `GH_TOKEN` | `ghp_xxx` | If injected at workspace creation |
| `CONVEX_DEPLOYMENT` | `dev:animal-name-123` | Auto-loaded from project config |
| `CONVEX_URL` / `VITE_CONVEX_URL` | `https://animal-name-123.convex.cloud` | Auto-loaded |
| `VITE_CLERK_PUBLISHABLE_KEY` | `pk_test_xxx` | Auto-loaded |
| `EXPO_PUBLIC_*` | Various | Auto-loaded for mobile projects |
| `CLERK_SECRET_KEY` | `sk_test_xxx` | **Manual injection required** |
| `STRIPE_SECRET_KEY` | `sk_test_xxx` | **Manual injection required** |

If a secret is missing, check `~/.config/devpod-env` and report it — do not proceed with operations that require secrets you don't have.

## Common Tasks

### Install dependencies
```bash
cd /workspaces/<project>
bun install
```

### Start dev server
```bash
# Convex backend
bunx convex dev          # or: cx dev

# Web app (varies by project)
bun run dev

# Both (if package.json has a combined script)
bun run dev
```

### Run tests
```bash
bun test                 # Unit tests
bunx playwright test     # E2E tests (full image only)
```

### Git operations
```bash
# Identity is pre-configured. Just commit and push.
git add <files>
git commit -m "message"
git push                 # Works if GH_TOKEN is configured
```

### Check what's configured
```bash
cat ~/.config/devpod-env          # All env vars
git config --global --list        # Git config
which bun claude codex gh         # Tool availability
```

## Project Map

| Project | Repo | Type | Stack |
|---------|------|------|-------|
| **dev-agent** | `PlasmaPOS/dev-agent` | Backend agent | Convex, Slack, Linear, Sentry |
| **plasma** | `PlasmaPOS/plasma` | POS system (monorepo) | Convex, Clerk, Stripe, Expo, SvelteKit |
| **pile** | `PlasmaPOS/pile` | Personal finance (monorepo) | Convex, Clerk, Stripe, Plaid, Expo |
| **roster** | `PlasmaPOS/roster` | Team management (monorepo) | Convex, Clerk, Stripe, Expo |
| **veil** | `PlasmaPOS/veil` | Anonymous social (monorepo) | Convex, Clerk, Expo |
| **seal** | `PlasmaPOS/seal` | Legal/contracts | Convex, Clerk, Stripe |
| **aqua** | `PlasmaPOS/aqua` | Water delivery | Convex, Clerk |

All projects use **Convex** as the backend and **Clerk** for authentication. Most use **Stripe** for payments. Mobile apps use **Expo** (React Native).

## Critical Rules

1. **Bun only.** Never use npm, yarn, or pnpm. Every project uses bun.

2. **Never commit secrets.** If you see `sk_test_*`, webhook secrets, or API keys in code, that's a bug. Secrets live in `~/.config/devpod-env` only.

3. **Check before assuming.** If an env var is missing, don't guess the value. Read `~/.config/devpod-env` and report what's missing.

4. **The VM auto-stops.** DevPod shuts down the VM after 30 minutes of inactivity. Active SSH sessions do NOT prevent this — DevPod tracks activity via its own daemon. If you're running a long autonomous session:
   ```bash
   # Disable auto-stop (remember to re-enable after)
   # This must be run from the HOST machine, not inside the workspace
   devpod provider set-options gcloud -o INACTIVITY_TIMEOUT=0
   ```

5. **Non-interactive SSH works.** All critical tools (`bun`, `claude`, `codex`, `node`) are in `/usr/local/bin`. You don't need to source `.bashrc` for them to work.

6. **Git push requires GH_TOKEN.** If `git push` fails with auth errors, check `echo $GH_TOKEN`. If empty, the token wasn't injected at workspace creation.

7. **Each workspace is isolated.** Your workspace has its own VM, its own Docker container, its own env vars. Changes here don't affect other workspaces.

## Workspace Lifecycle

Understanding when things run helps you debug environment issues:

```
devpod up <repo>
  │
  ├── 1. Docker image pulled (light or full from GHCR)
  ├── 2. devcontainer.json features installed (git, gh)
  ├── 3. Dotfiles cloned + install.sh executed     ← env vars, git config, aliases
  ├── 4. postCreateCommand runs (e.g. "bun install") ← project dependencies
  └── 5. Container ready — SSH session starts
```

| Event | Runs when | Example |
|-------|-----------|---------|
| Docker image | Container created | Bun, Node, Claude, Codex pre-installed |
| `install.sh` (dotfiles) | Container created | Env vars, git identity, aliases |
| `postCreateCommand` | Container created | `bun install` |
| `postStartCommand` | Every container start | Dev server startup scripts |
| `postAttachCommand` | Every SSH/attach | Editor setup |

**State persists** across `devpod stop` / `devpod up`. Only `devpod up --reset` wipes the container.

## Working Directory

Always `cd` to the project root before running commands:

```bash
cd /workspaces/$(ls /workspaces/)
```

This is where `package.json`, `convex/`, and project CLAUDE.md live. Most commands expect to run from here.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `bun: command not found` | Run `source ~/.bashrc` or use `/usr/local/bin/bun` directly |
| `git push` auth failure | Check `echo $GH_TOKEN` — if empty, inject it into `~/.config/devpod-env` |
| Missing env var | Read `~/.config/devpod-env`, check if project config was loaded |
| `convex dev` fails | Check `CONVEX_DEPLOYMENT` is set: `grep CONVEX ~/.config/devpod-env` |
| Clerk auth fails | Check both publishable key (auto-loaded) and secret key (manual) are present |
| VM suddenly stops | Inactivity timeout hit. `devpod up <repo>` to restart (state persists). |
| Emulator won't start | Only available on `full` image. Check: `which emulator` |
