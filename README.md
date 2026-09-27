# django-template

> **GitHub Template** — the starting point for every new Django project.
> Click **Use this template**, open in VS Code, **Reopen in Container**, start coding.

[![CI](https://github.com/alihaidar0/django-template/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/alihaidar0/django-template/actions/workflows/ci.yml)
[![Python](https://img.shields.io/badge/python-3.14-blue?logo=python&logoColor=white)](https://www.python.org)
[![Django](https://img.shields.io/badge/django-6.x-green?logo=django&logoColor=white)](https://www.djangoproject.com)
[![uv](https://img.shields.io/badge/uv-package%20manager-blueviolet)](https://docs.astral.sh/uv/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://docs.astral.sh/ruff/)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://pre-commit.com)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://github.com/alihaidar0/django-template/blob/main/LICENSE)

---

## What this is

A GitHub Template that gives every new Django project the same
**infrastructure and tooling skeleton** — the Django code itself is created
per project in six commands after the container starts.

- **Nothing to install locally** except Docker Desktop and VS Code: the dev
  environment is the shared image
  [`alihaidar199527/django-devcontainer`](https://hub.docker.com/r/alihaidar199527/django-devcontainer)
  — **pulled, never built** on your machine.
- **Full stack pre-wired:** PostgreSQL 18, Redis 8, Celery worker + Beat, Mailpit.
- **Pure-Python git hooks** (pre-commit + Conventional Commits) — no Node.js.
- **Tiered CI** that never fails on a fresh template and grows with the project.
- **Production image** (Gunicorn, non-root, amd64 + arm64, SBOM, signed
  provenance) published to Docker Hub on every release.
- **Dependabot** for Actions, Docker images, compose services, pre-commit
  hooks, and (after `uv init`) Python packages.

---

## How it fits together

```text
django-devcontainer ──(CI builds & publishes)──▶ Docker Hub: alihaidar199527/django-devcontainer
                                                     │ pulled by
django-template ──(Use this template)──▶ your project: app · celery · celery-beat
                                          + postgres · redis · mailpit
```

| Repo | Responsibility |
| --- | --- |
| [`django-devcontainer`](https://github.com/alihaidar0/django-devcontainer) | The environment — Python, uv, tools, shell — one image for every project |
| `django-template` ← **you are here** | The project scaffold — compose stack, dev container, hooks, CI, production image |

---

## Prerequisites

| Tool | Purpose |
| --- | --- |
| [Docker Desktop](https://docs.docker.com/get-docker/) | Runs the dev stack |
| [VS Code](https://code.visualstudio.com/) + **Dev Containers** extension (`ms-vscode-remote.remote-containers`) | Opens the project inside the container |
| An SSH key loaded in your **host** ssh-agent | `git push` from inside the container — see [Git and SSH](#git-and-ssh) |

No Python, Node.js, or database on your machine.

---

## Quickstart

### 1. Create and open your project

Click **Use this template → Create a new repository**, then:

```bash
git clone git@github.com:<you>/<your-project>.git
code <your-project>
```

Click **Reopen in Container**. VS Code pulls the dev image, starts every
service, and prints the next steps in the terminal.

### 2. Create the Django project — six commands

```bash
# 1. uv project
uv init --bare

# 2. production dependencies
uv add django djangorestframework "psycopg[binary,pool]" dj-database-url \
       redis celery django-celery-beat gunicorn whitenoise

# 3. dev / test dependencies
uv add --dev pytest pytest-django pytest-cov factory-boy faker \
             mypy django-stubs celery-types pip-audit ipython

# 4. scaffold Django: settings split, env-driven config, Celery
bash scripts/init-django.sh

# 5. git hooks (pre-commit + commit-msg)
pre-commit install

# 6. database and server
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Open <http://localhost:8000>. No venv activation needed — the dev image puts
`/workspace/.venv/bin` first on `PATH`, in every container and shell. The
Celery worker and Beat start by themselves as soon as the project and its
dependencies exist.

`scripts/init-django.sh` generates a production-ready layout:

| Generated | What it gives you |
| --- | --- |
| `config/settings/{base,development,production,testing}.py` | settings split; configured from the environment (`SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `DATABASE_URL`, `CELERY_*`, `LOG_LEVEL` …) |
| `production.py` | HTTPS behind a proxy, secure cookies, Django 6 **Content Security Policy** (report-only until tuned) |
| WhiteNoise | static files served by Gunicorn with hashed, cacheable names |
| `config/health.py` | `GET /healthz` for Cloud Run / Kubernetes probes (answers before host checks) |
| `users/` app | Custom user model (`AUTH_USER_MODEL = "users.User"`), with its first migration already generated — Django's own docs call swapping it in later "a substantial task" |
| `config/celery.py` | Celery app (`celery -A config`), `django-celery-beat` scheduler |
| logging | everything to stdout, level via `LOG_LEVEL` |
| `pyproject.toml` | ruff rules (incl. bugbear, bandit, Django), **mypy strict** with django-stubs, pytest-django, coverage |

**Want fields on `User` before the database exists?** Step 4 already generates
`users/migrations/0001_initial.py`, so step 6's `migrate` has something to apply — Django's own docs call adding
`AUTH_USER_MODEL` after that first migration "a substantial task". Before running step 6, edit `users/models.py`,
then regenerate that one migration so it already contains your fields:

```bash
rm users/migrations/0001_initial.py
python manage.py makemigrations users
```

Fields added after step 6 don't need this — that's just a normal follow-up migration.

The generated project passes ruff, mypy strict, `makemigrations --check` and
`check --deploy` out of the box — CI runs this same script on every push to
prove it, then builds and probes the production image.

**Teammates cloning an existing project** don't run these steps: on container
creation `scripts/post-create.sh` runs `uv sync --locked` and `pre-commit install`
automatically.

### 3. Finish the repository setup

- Enable the commented **`uv`** block in `.github/dependabot.yml`.
- Apply the branch rulesets and settings in
  [`.github/CONTRIBUTING.md`](https://github.com/alihaidar0/django-template/blob/main/.github/CONTRIBUTING.md) §2.
- Add the Actions variable **`DOCKERHUB_USERNAME`** and secret
  **`DOCKERHUB_TOKEN`** to publish the production image.

---

## Services

| Service | URL / port | Purpose |
| --- | --- | --- |
| Django | <http://localhost:8000> | `pmr` → `runserver 0.0.0.0:8000` |
| Mailpit | <http://localhost:8025> (SMTP `1025`) | catches every outgoing email |
| Flower | <http://localhost:5555> | `cf` → Celery monitor |
| PostgreSQL 18 | `localhost:5432` | database (`django` / `django_pass` / `django_dev`) |
| Redis 8 | `localhost:6379` | cache, Celery broker + results |
| debugpy | `localhost:5678` | VS Code *Django: Attach Debugger* |

Celery worker and Beat wait until `manage.py` and the project's dependencies
exist, then start on their own (the worker reloads on code changes). Host ports
are bound to `127.0.0.1` only. Each project gets its own containers, network
and volumes (named after the project folder), so several projects can run side
by side.

**Fast on Windows and macOS:** the project's `.venv` lives in a Docker volume
(Linux filesystem) instead of the bind-mounted folder, so `uv sync` and Python
imports don't pay the cross-OS file-sharing cost. It's shared by the app and
Celery containers; on your host the `.venv` folder stays empty.

Configuration: every value has a working default in `docker-compose.yml`;
copy `.env.example` to `.env` to override (e.g. pin `DEVCONTAINER_IMAGE` to a
dated tag).

---

## Everyday workflow

```text
develop ◀── you push directly (CI + Lint run on every push)
   │   ◀── Dependabot update PRs
   └──PR──▶ main  (release: required checks PR source · Lint · CI → production image published)
```

Details — branch rules, required checks, release tags — in
[`CONTRIBUTING.md`](https://github.com/alihaidar0/django-template/blob/main/.github/CONTRIBUTING.md).

### Git hooks

| Stage | Hook | Purpose |
| --- | --- | --- |
| `pre-commit` | `pre-commit-hooks` | whitespace, EOF, YAML/TOML/JSON validity, private keys, large files, LF endings |
| `pre-commit` | `ruff-check` + `ruff-format` | lint (auto-fix) and format |
| `pre-commit` | `django-upgrade` | modernise code to the project's Django version (read from `pyproject.toml`) |
| `pre-commit` | `uv-lock` | keep `uv.lock` in sync with `pyproject.toml` |
| `pre-commit` | `check-github-workflows` · `check-dependabot` | schema-validate workflow and Dependabot files |
| `commit-msg` | `conventional-pre-commit` | Conventional Commits (`feat` `fix` `chore` `docs` `style` `refactor` `perf` `test` `build` `ci` `revert` `wip`) |

Hook versions are bumped weekly by Dependabot. Run all hooks with
`pre-commit run --all-files`.

### Git and SSH

Commit and push from the container terminal or from your host — both use the
same repository and the same keys.

- **Keys**: VS Code forwards your host's ssh-agent into the container. Private
  keys never enter the container.
- **SSH settings**: `docker-compose.yml` mounts your host `~/.ssh` read-only;
  on container creation `scripts/post-create.sh` copies `config`,
  `known_hosts` and the `*.pub` files into the container. Host aliases work the
  same inside, e.g. for several GitHub accounts:

  ```text
  Host github.com-work
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_work
      IdentitiesOnly yes
  ```

  with the remote `git@github.com-work:<owner>/<repo>.git`. The copied `.pub`
  file lets `IdentitiesOnly` pick the matching key from the forwarded agent.
  After changing `~/.ssh/config` on the host, **Rebuild Container**.
- **Identity**: VS Code copies your host `~/.gitconfig`. For a per-project
  identity, set it in the repository — it lives in `.git/config`, so the host
  and the container both use it:
  `git config user.email you@example.com`.
- **Committing from the host**: the hooks installed by `pre-commit install`
  also run for commits made on the host, so the host needs `pre-commit` on
  `PATH` too — e.g. `uv tool install pre-commit` (Windows:
  `winget install astral-sh.uv` first). Without it, host commits stop with
  "`pre-commit` not found".

---

## CI

| Tier | When | Runs |
| --- | --- | --- |
| 1 · template | no `pyproject.toml` | pre-commit · a sample project scaffolded with the quickstart steps, checked (ruff · mypy strict · pytest · migrations · deploy check) and served from the production image |
| 2 · pre-Django | `pyproject.toml` | pre-commit · pip-audit |
| 3 · Django | `manage.py` + `uv.lock` | pre-commit · mypy · pytest (PostgreSQL 18) · `check --deploy` · missing-migrations check · pip-audit · production image build + smoke test (`/healthz`, CSP header) |

`Lint` additionally audits the workflows with **zizmor** (GitHub Actions
security) and **actionlint**, and checks the Dockerfile, shell scripts, compose
file, Markdown and spelling.

The single `CI` gate job is the required check; skipped jobs simply don't
apply to the current tier.

---

## Production image

Built from `docker/Dockerfile.prod` in two stages — a pinned `uv` resolves the
locked dependencies; the runtime stage is slim Python + the venv + your code,
running as the non-root user `app`:

- Static files collected at build time and served by WhiteNoise.
- `GET /healthz` → 200 for platform probes; Django 6 CSP header (report-only);
  logs to stdout.
- `scripts/entrypoint.prod.sh` runs `migrate` (skip with `RUN_MIGRATIONS=false`
  when a separate job migrates), then Gunicorn bound to `$PORT` (default 8080)
  with `$WEB_CONCURRENCY` workers (default 2); override anything via
  `GUNICORN_CMD_ARGS`.
- Published on every merge to `main` as `latest` + `sha-<short>`, plus
  `X.Y.Z` / `X.Y` for `vX.Y.Z` tags.

```bash
docker run --rm -p 8080:8080 \
  -e SECRET_KEY=change-me -e DATABASE_URL=postgres://… -e ALLOWED_HOSTS=example.com \
  <DOCKERHUB_USERNAME>/<repo>:latest
```

Deployment workflows (Cloud Run, GKE, …) are intentionally not included — add
the one your project needs.

---

## Repository structure

```text
.
├── .devcontainer/devcontainer.json   # VS Code: compose service `app`, extensions, settings
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # CI (tiered) — required check "CI"
│   │   ├── lint.yml                  # repo linters — required check "Lint"
│   │   ├── branch-policy.yml         # "PR source": main accepts PRs from develop only
│   │   ├── docker.yml                # release: publish + scan the production image
│   │   ├── dockerhub-description.yml # README → Docker Hub
│   │   └── labels.yml                # labels.yml → GitHub labels
│   ├── ISSUE_TEMPLATE/ · CODEOWNERS · CONTRIBUTING.md · SECURITY.md · pull_request_template.md
│   ├── actionlint.yaml · dependabot.yml · labels.yml
├── .vscode/launch.json · tasks.json  # debug configs + task shortcuts
├── docker/Dockerfile.prod            # production image
├── scripts/
│   ├── init-django.sh                # step 4: scaffold config/ + settings + Celery + tool config
│   ├── post-create.sh                # container created: SSH settings, .venv volume owner, uv sync, hooks
│   ├── entrypoint.prod.sh            # migrate → Gunicorn
│   └── welcome.sh                    # next-steps banner on container start
├── .env.example · .dockerignore · .gitignore · .gitattributes · .editorconfig
├── .pre-commit-config.yaml           # pure-Python hooks
├── .hadolint.yaml · .markdownlint-cli2.jsonc · cspell.json · .cspell/
├── docker-compose.yml                # dev stack
└── LICENSE · README.md
```

---

## Troubleshooting

### `git push` fails inside the container — Permission denied (publickey)

The container uses your **host's** ssh-agent. On the host, check `ssh-add -l`
lists your key (`post-create.sh` also warns when the container sees no keys).
On Windows (PowerShell as Administrator), once:

```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
```

Then **Rebuild / Reopen in Container**.

`Could not resolve hostname github.com-…` means the host alias is missing in
the container: check it is in the host `~/.ssh/config`, then **Rebuild
Container** (the settings are copied on creation).

### Upgrading an older project (root-based dev image)

Projects created before the dev image switched to the non-root user `dev`
need the current versions of `docker-compose.yml`,
`.devcontainer/devcontainer.json` and `scripts/welcome.sh` from this template,
and `scripts/entrypoint.dev.sh` deleted. To keep the old behaviour meanwhile,
set `DEVCONTAINER_IMAGE=alihaidar199527/django-devcontainer:sha-7cd9005`
(the last root image) in `.env`.

### Existing PostgreSQL data after the PostgreSQL 18 volume fix

The volume now mounts at `/var/lib/postgresql` (PostgreSQL 18 layout). Old dev
databases lived in an anonymous volume and are not carried over — re-run
`python manage.py migrate` (and reload fixtures) after `docker compose down -v`.

---

## License

[MIT](https://github.com/alihaidar0/django-template/blob/main/LICENSE) © Ali Haidar
