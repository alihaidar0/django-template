# django-template

> **GitHub Template** — the zero-configuration starting point for every new Django project.
> One click to create. One command to run. Start coding in under 3 minutes.

[![CI](https://github.com/alihaidar199527/django-template/actions/workflows/ci.yml/badge.svg)](https://github.com/alihaidar199527/django-template/actions/workflows/ci.yml)
[![Docker](https://github.com/alihaidar199527/django-template/actions/workflows/docker.yml/badge.svg)](https://github.com/alihaidar199527/django-template/actions/workflows/docker.yml)
[![Python](https://img.shields.io/badge/python-3.14-blue?logo=python&logoColor=white)](https://www.python.org)
[![Django](https://img.shields.io/badge/django-6.x-green?logo=django&logoColor=white)](https://djangoproject.com)
[![uv](https://img.shields.io/badge/uv-package%20manager-blueviolet)](https://docs.astral.sh/uv/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://docs.astral.sh/ruff/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://pre-commit.com)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

---

## What this is

A production-grade GitHub Template repository that spins up a full Django development environment inside a VS Code Dev Container. It provides the **infrastructure and tooling skeleton** — Django source files are added per project after the container starts.

**What you get immediately:**

- Full dev environment (Python 3.14, uv, ruff, mypy, pytest) — no local installs required
- PostgreSQL 18 + Redis 8 + Celery + Mailpit — all pre-wired and running
- Zero Node.js — all git hooks are pure Python (`pre-commit` + `conventional-pre-commit`)
- Smart CI with graceful degradation across three project tiers
- Production Docker build triggered automatically on merge to `main`
- Dependabot auto-updates for Actions, Docker, **and pre-commit hooks** (March 2026+)

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Docker Desktop | Runs the dev container | [docs.docker.com](https://docs.docker.com/get-docker/) |
| VS Code | Editor with Dev Container support | [code.visualstudio.com](https://code.visualstudio.com/) |
| Dev Containers extension | Opens the project inside Docker | `ms-vscode-remote.remote-containers` |

No Python, Node, or database installations required on your machine.

---

## Quickstart

### 1. Create your project from this template

Click **"Use this template"** on GitHub → **"Create a new repository"**.

### 2. Clone and open in VS Code

```bash
git clone git@github.com:your-org/your-project.git
code your-project
```

When VS Code prompts **"Reopen in Container"** — click it.

The container starts, pulls the dev image, spins up all services, and prints the getting-started guide in the terminal automatically.

### 3. Follow the getting-started guide in the terminal

The terminal will show the exact commands for your current project state. For a fresh template:

```bash
# 1. Initialise uv (creates pyproject.toml)
uv init --no-package

# 2. Add core production dependencies
uv add django djangorestframework \
       "psycopg[binary,pool]" \
       redis celery django-celery-beat \
       gunicorn python-decouple

# 3. Add dev / test dependencies
uv add --dev \
    pytest pytest-django pytest-cov pytest-asyncio \
    factory-boy faker mypy django-stubs \
    pip-audit ipython

# 4. Scaffold the Django project
django-admin startproject config .

# 5. Install pre-commit hooks (pre-commit + commit-msg)
pre-commit install

# 6. Apply migrations and start the server
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Open [http://localhost:8000](http://localhost:8000) — you're live.

---

## Repository structure

```
django-template/
├── .devcontainer/
│   └── devcontainer.json          # VS Code dev container config
├── .github/
│   ├── dependabot.yml             # Auto-updates: Actions + Docker + pre-commit
│   ├── labels.yml                 # GitHub label definitions
│   └── workflows/
│       ├── ci.yml                 # Three-tier CI pipeline
│       ├── docker.yml             # Production image build + push
│       ├── dockerhub-description.yml
│       └── labels.yml
├── .vscode/
│   ├── launch.json                # Debug configurations
│   └── tasks.json                 # Task runner shortcuts
├── docker/
│   └── Dockerfile.prod            # Production image (Gunicorn)
├── scripts/
│   ├── entrypoint.dev.sh          # SSH permission fixer for Windows NTFS mounts
│   ├── entrypoint.prod.sh         # Migrate + start Gunicorn
│   └── welcome.sh                 # Context-aware getting-started banner
├── .dockerignore
├── .env.example
├── .gitignore
├── .pre-commit-config.yaml        # Pure Python hooks — zero Node.js
├── docker-compose.yml             # Full dev stack
└── README.md
```

---

## Git hooks (pure Python — zero Node.js)

All hooks are managed by [pre-commit](https://pre-commit.com). No Node, no npm, no Husky.

Install hooks after `uv init` and dependencies are installed:

```bash
pre-commit install
```

The `default_install_hook_types` setting in `.pre-commit-config.yaml` installs both `pre-commit` and `commit-msg` hooks in one command.

| Stage | Hook | Purpose |
|---|---|---|
| `pre-commit` | `pre-commit-hooks` v6.0.0 | File health (trailing whitespace, YAML, secrets…) |
| `pre-commit` | `ruff` v0.15.9 | Lint + auto-fix |
| `pre-commit` | `ruff-format` v0.15.9 | Format check |
| `pre-commit` | `django-upgrade` v1.30.0 | Auto-upgrade Django patterns to 6.0+ |
| `commit-msg` | `conventional-pre-commit` v4.4.0 | Enforce Conventional Commits format |

> **Branch protection** is enforced via GitHub branch protection rules ("Require a pull request before merging"), not a client-side hook. Configure it in your repo Settings → Branches.

### Conventional Commits

Valid types: `feat` `fix` `chore` `docs` `style` `refactor` `perf` `test` `build` `ci` `revert`

```bash
# Good
git commit -m "feat(auth): add JWT refresh token endpoint"
git commit -m "fix(celery): handle connection timeout on broker start"
git commit -m "chore(deps): upgrade django to 6.0.3"

# Bad — will be rejected
git commit -m "updated stuff"
git commit -m "WIP"
```

### Run hooks manually

```bash
pre-commit run --all-files          # All hooks on all files
pre-commit run ruff-check --all-files  # One specific hook
pre-commit autoupdate               # Update all hook versions (or let Dependabot do it)
```

---

## CI pipeline

The CI uses a **three-tier model** — it never fails on a fresh template.

| Tier | Condition | Active checks |
|---|---|---|
| 1 — Template | No `pyproject.toml` | All skipped |
| 2 — Pre-Django | `pyproject.toml` present, no `manage.py` | lint, typecheck (stub), pip-audit |
| 3 — Full project | `manage.py` + `uv.lock` present | lint, mypy, pytest+coverage, `manage.py check --deploy`, pip-audit, Trivy |

The `ci-passed` job is the single required status check for branch protection. It evaluates all upstream results and passes correctly whether jobs ran or were skipped.

---

## Services

| Service | Port | Purpose |
|---|---|---|
| Django | 8000 | Dev server |
| PostgreSQL 18 | 5432 | Primary database |
| Redis 8 | 6379 | Cache + Celery broker |
| Celery worker | — | Background task processing |
| Celery Beat | — | Scheduled tasks |
| Mailpit | 8025 (UI) / 1025 (SMTP) | Email catcher |
| debugpy | 5678 | VS Code remote debugger |
| Flower | 5555 | Celery task monitor |

Celery and Celery Beat start automatically but stay silent until `manage.py` exists.

---

## Shell aliases

Baked into the dev image:

| Alias | Command |
|---|---|
| `pmr` | `python manage.py runserver 0.0.0.0:8000` |
| `pmm` | `python manage.py migrate` |
| `pmmk` | `python manage.py makemigrations` |
| `pms` | `python manage.py shell` |
| `pmsu` | `python manage.py createsuperuser` |
| `gs` | `git status` |
| `ga` | `git add -p` |
| `gc` | `git commit` |
| `gp` | `git push` |

---

## Production image

On every merge to `main` (after CI passes), GitHub Actions builds a production Docker image and pushes it to Docker Hub:

```
your-dockerhub-username/your-repo-name:latest
your-dockerhub-username/your-repo-name:sha-<short-sha>
your-dockerhub-username/your-repo-name:<semver>   # on git tags
```

The build is skipped gracefully on a fresh template (no `manage.py` yet).

**Required GitHub Secrets:**
- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — Docker Hub access token (Read & Write)

---

## Deployment

This template intentionally omits deployment workflows (Cloud Run, GKE, GCE, etc.) so they can be added per-project. The production image is deployment-agnostic and works on any container platform.

---

## Windows / macOS / Linux compatibility

`docker-compose.yml` uses `${USERPROFILE:-$HOME}` for SSH and Git config mounts, making it work across all platforms without edits. `entrypoint.dev.sh` fixes SSH key permissions on every start, resolving the Windows NTFS limitation where mounted files arrive as `777`.

---

## Keeping hooks up to date

Dependabot now handles `pre-commit` hook updates natively (March 2026+). It will open PRs to bump `rev:` values in `.pre-commit-config.yaml` weekly — no manual `pre-commit autoupdate` required. You can still run it manually if needed:

```bash
pre-commit autoupdate
git add .pre-commit-config.yaml
git commit -m "chore(hooks): update pre-commit hook versions"
```
