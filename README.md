# PlasmaPOS DevPod Dotfiles

Shared configuration for all PlasmaPOS cloud development environments. Automatically applied to every DevPod workspace via the `--dotfiles` flag.

## Repository Structure

```
dotfiles/
├── install.sh              # Main entry point — DevPod runs this automatically
├── setup-devpod.sh         # One-time local machine setup (GCP provider + identity)
├── .aliases                # Shell aliases (bun, git, convex)
├── .git-identity           # Your git name/email (gitignored, local only)
├── .gh-token               # Your GitHub PAT (gitignored, local only)
├── .gitignore
└── projects/               # Per-project environment configs
    ├── dev-agent.env
    ├── plasma.env
    ├── pile.env
    ├── roster.env
    ├── veil.env
    ├── seal.env
    └── aqua.env
```

## How It Works

When you run `devpod up <repo>`, DevPod clones this dotfiles repo into the workspace and executes `install.sh`. The script does the following **in order**:

1. **Installs bun** (if not already present) and adds it to PATH for all shells + non-interactive SSH
2. **Symlinks bun** into `/usr/local/bin` so it works in non-interactive SSH sessions
3. **Installs global tools**: `convex` CLI via bun
4. **Links shell aliases** (`.aliases` → `~/.aliases`, sourced from `.bashrc`)
5. **Configures git** — team-wide defaults for all developers, dynamic identity from `.git-identity` or env vars
6. **Creates `~/.config/devpod-env`** — the single source of truth for all environment variables
7. **Configures GitHub CLI** auth if `GH_TOKEN` is available (env var or `.gh-token` file)
8. **Auto-detects the project** from the workspace name and loads its `projects/<name>.env` config
9. **Reports missing secrets** that need manual injection

## Environment System

All environment variables flow through one file: **`~/.config/devpod-env`**

```
┌─────────────────────────────────┐
│  ~/.config/devpod-env           │  ← Single source of truth
│                                 │
│  Sourced by: .bashrc            │
│              .zshrc             │
│              .profile           │
│                                 │
│  Contains:                      │
│  - GH_TOKEN (GitHub PAT)       │
│  - Project public vars          │
│  - Project secrets (manual)     │
│  - Any custom env vars          │
└─────────────────────────────────┘
```

### What gets loaded automatically

| Source | Variables | Example |
|--------|-----------|---------|
| `.gh-token` file or `$GH_TOKEN` env | `GH_TOKEN` | `ghp_xxx` |
| `.git-identity` file | `GIT_USER_NAME`, `GIT_USER_EMAIL` | `Shlomo Kabareti` |
| `projects/<name>.env` | Convex URLs, Clerk publishable keys, Stripe publishable keys | `VITE_CONVEX_URL=https://...` |

### What you add manually (once per workspace)

Secret keys (`sk_test_*`, webhook secrets) cannot be committed to git. After creating a workspace:

```bash
ssh <project>.devpod 'echo "export CLERK_SECRET_KEY=sk_test_xxx" >> ~/.config/devpod-env'
```

Each `projects/<name>.env` file lists its required secrets as `# OP_ITEM:` comments. The install script warns you about any that are missing.

## Git Identity

Git identity is **dynamic** — no hardcoded names in this repo. Resolution order:

1. `.git-identity` file in this repo (gitignored, local override only — won't reach remote clones)
2. `GIT_USER_NAME` / `GIT_USER_EMAIL` env vars (from `devpod-env` or environment)
3. `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` (standard git env vars)
4. **GitHub API auto-detection** — if `GH_TOKEN` is available, `install.sh` fetches your name/email from your GitHub profile automatically
5. Warning printed if nothing is set

In practice, most developers just need `GH_TOKEN` set — identity is auto-detected from GitHub.

Team-wide git defaults applied to everyone:

| Setting | Value |
|---------|-------|
| `init.defaultBranch` | `main` |
| `pull.rebase` | `true` |
| `push.autoSetupRemote` | `true` |
| `core.autocrlf` | `input` |

## GitHub CLI Auth

Three ways to inject your GitHub PAT so `gh` + `git push` work immediately:

```bash
# Option A: Set env var before workspace creation (auto-detected by install.sh)
export GH_TOKEN=ghp_xxx
devpod up <repo>

# Option B: Place .gh-token file in this repo (gitignored, persistent across workspaces)
echo "ghp_xxx" > .gh-token

# Option C: Add manually after workspace creation
ssh <project>.devpod 'echo "export GH_TOKEN=ghp_xxx" >> ~/.config/devpod-env'
```

## AI CLIs

AI tools (Claude Code, Codex) run **locally** on your machine — they connect to the workspace via `ssh <project>.devpod`. They are NOT installed in the container image. This keeps images small and avoids version drift between local AI tools and remote copies.

## Project Configs

Each project has a `projects/<name>.env` file. Format:

```bash
# project-name — Short description
# Public values (safe to commit)
CONVEX_DEPLOYMENT=dev:animal-name-123
VITE_CONVEX_URL=https://animal-name-123.convex.cloud
VITE_CLERK_PUBLISHABLE_KEY=pk_test_xxx

# Secrets (pulled from 1Password at setup time)
# OP_ITEM: CLERK_SECRET_KEY -> "1Password Item Name"
# OP_ITEM: STRIPE_SECRET_KEY -> "1Password Item Name"
```

**Public values** (`pk_test_*`, Convex URLs, Sentry DSNs) are loaded into `devpod-env` automatically.
**Secrets** (`sk_test_*`, webhook secrets) are listed as `# OP_ITEM:` references — install.sh reports which ones are missing. The fastest way to inject them is scraping from the project's `.env.local` files (see Step 3).

### Current projects

| Project | Description | Image | VM Size |
|---------|-------------|-------|---------|
| `dev-agent` | Background dev agent | `light` | n2d-standard-4 |
| `plasma` | POS system (monorepo) | `full` | n2d-standard-8 |
| `pile` | Inventory management | `full` | n2d-standard-8 |
| `roster` | Staff scheduling | `full` | n2d-standard-8 |
| `veil` | Anonymous social (monorepo) | `full` | n2d-standard-8 |
| `seal` | Legal/contracts | `light` | n2d-standard-4 |
| `aqua` | Water delivery | `light` | n2d-standard-4 |

## Adding a New Project Workspace

To set up a DevPod workspace for a project (one-time per project):

### Step 1: Add `devcontainer.json` to the project repo

Create `.devcontainer/devcontainer.json` in the project's GitHub repo:

```json
{
  "name": "my-project",
  "image": "ghcr.io/plasmapos/devcontainers/light:latest",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "postCreateCommand": "bun install",
  "runArgs": ["--shm-size=2g"]
}
```

Use `light` for backend/simple projects, `full` for projects with mobile/E2E testing.

### Step 2: Create the workspace

```bash
# Light projects (dev-agent, seal, aqua)
devpod up PlasmaPOS/seal

# Full projects — override machine type for more resources
devpod up PlasmaPOS/plasma --provider-option MACHINE_TYPE=n2d-standard-8
```

This pulls the Docker image, clones the repo, runs dotfiles `install.sh` (which auto-detects the project and loads its env vars), and runs `bun install`.

### Step 3: Inject GH_TOKEN + secrets (once)

#### GH_TOKEN (required for git push)

```bash
GH_TOKEN=$(gh auth token)
ssh <project>.devpod "echo 'export GH_TOKEN=$GH_TOKEN' >> ~/.config/devpod-env"
```

#### Project secrets (from .env.local)

Secrets live in each project's `.env.local` files locally. Scrape them into the workspace:

```bash
# Find which .env.local has your secrets
SECRETS_FILE=~/Projects/<project>/apps/backend/.env.local

for key in CLERK_SECRET_KEY STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET PLAID_CLIENT_ID PLAID_SECRET RESEND_API_KEY; do
  val=$(grep "^${key}=" "$SECRETS_FILE" | head -1 | cut -d'=' -f2-)
  if [ -n "$val" ]; then
    ssh <project>.devpod "echo 'export ${key}=${val}' >> ~/.config/devpod-env"
  fi
done
```

### Step 4: Verify

```bash
ssh <project>.devpod 'source ~/.config/devpod-env && env | grep -E "CLERK|STRIPE|CONVEX|GH_TOKEN"'
```

That's it. The workspace persists across stop/start. Only `--reset` requires re-doing steps 3-4.

## Fresh Machine Setup

If setting up DevPod from scratch (new machine, disaster recovery):

```bash
# 1. Install DevPod CLI
#    https://devpod.sh/docs/getting-started/install

# 2. Clone this repo
git clone https://github.com/PlasmaPOS/dotfiles.git
cd dotfiles

# 3. Run the setup script — configures GCP provider, dotfiles URL, and git identity
./setup-devpod.sh

# 4. (Optional) Add your GitHub PAT
echo "ghp_xxx" > .gh-token

# 5. Create your first workspace
devpod up PlasmaPOS/dev-agent
```

### What `setup-devpod.sh` configures

| Setting | Value |
|---------|-------|
| GCP Project | `plasma-429815` |
| Zone | `us-central1-a` |
| Default machine type | `n2d-standard-4` |
| Disk size | `80 GB` |
| Inactivity timeout | `30m` (VM auto-stops after 30 min idle) |
| Dotfiles URL | `https://github.com/PlasmaPOS/dotfiles` |
| Default provider | `gcloud` |

Override machine type for heavier projects:
```bash
devpod up <repo> --provider-option MACHINE_TYPE=n2d-standard-8
```

## For Coding Agents

If you are Claude Code, Codex, or another AI agent running inside a DevPod workspace:

- **Environment variables** are in `~/.config/devpod-env` — source it or read it directly
- **Project detection**: The workspace name matches the project name. Check `ls /workspaces/` to confirm which project you're in
- **Bun** is the package manager — never use npm/yarn/pnpm
- **Git identity** is already configured via `git config --global`
- **GitHub auth** is configured if `GH_TOKEN` was injected — `git push` over HTTPS works immediately
- **Convex CLI** is globally installed — use `bunx convex` or the `cx` alias
- **Non-interactive SSH**: Bun and common tools are symlinked into `/usr/local/bin`, so they work even without shell profile sourcing
- **DevPod inactivity timeout**: The VM auto-stops after 30 min of inactivity. Active SSH sessions do NOT prevent this. If running long autonomous sessions, disable with: `devpod provider set-options gcloud -o INACTIVITY_TIMEOUT=0`

### Shell aliases available

| Alias | Command |
|-------|---------|
| `bi` | `bun install` |
| `ba` | `bun add` |
| `br` | `bun run` |
| `bt` | `bun test` |
| `bx` | `bunx` |
| `gs` | `git status` |
| `gd` | `git diff` |
| `gl` | `git log --oneline -20` |
| `gp` | `git push` |
| `gc` | `git commit` |
| `cx` | `bunx convex` |
| `cxd` | `bunx convex dev` |

## Related Repositories

- **[PlasmaPOS/devcontainers](https://github.com/PlasmaPOS/devcontainers)** — Prebuild Docker images (`light` and `full`) with bun, Node.js, and optional Playwright/Android SDK. AI CLIs run locally, not in the image.
