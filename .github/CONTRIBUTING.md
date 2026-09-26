# Contributing & repository operations

Source of truth for **branching, protection rules, CI/CD, releases, and
dependency automation**. Some pieces are applied on GitHub (rulesets,
settings) rather than in the repo. Project setup is in the root
[`README.md`](../README.md).

---

## 1. Branching model

```text
            direct pushes          Dependabot PRs
                  │                      │
                  ▼                      ▼
develop  ──────────────────────────────────────  (integration: CI + Lint on every push)
                  │
                  └──PR──▶  main   (release: every merge publishes the production image)
```

| Branch | Role | Direct push? | Accepts PRs from |
| --- | --- | --- | --- |
| `main` | Released history — the default branch | ❌ | `develop` **only** |
| `develop` | Integration branch — daily work lands here | ✅ | Dependabot (and any short-lived branch) |

- Commit and push **directly to `develop`**. Every push runs `Lint` and `CI`
  on that commit.
- A release is a PR **`develop` → `main`**. It needs no new CI run: status
  checks attach to the commit, so the PR reuses develop's head-commit results.
- Dependabot opens every update PR against `develop`.
- Commit messages follow **Conventional Commits** (enforced locally by the
  `commit-msg` hook): `feat` `fix` `chore` `docs` `style` `refactor` `perf`
  `test` `build` `ci` `revert` `wip`.

---

## 2. GitHub settings (apply in the UI)

### Ruleset `protect-main` (Settings → Rules → Rulesets)

| Setting | Value |
| --- | --- |
| Target branches | `main` (Include default branch) |
| Enforcement status | **Active**, bypass list *empty* |
| **Restrict creations** / **Restrict deletions** | ✅ |
| **Restrict updates** | ❌ — with an empty bypass list it blocks **every** update to `main`, PR merges included |
| **Block force pushes** | ✅ |
| **Require a pull request before merging** | ✅ |
| &nbsp;&nbsp;Required approvals | **0** while solo (raise to 1 with a second maintainer) |
| &nbsp;&nbsp;Require review from Code Owners | ❌ while solo — the author can't approve their own PR; enable with 1 approval once there's a second maintainer |
| &nbsp;&nbsp;Require conversation resolution | ✅ |
| &nbsp;&nbsp;Allowed merge methods | **Merge** only — squash/rebase would give `main` commits `develop` doesn't have |
| **Require status checks to pass** | ✅ → **`PR source`**, **`Lint`**, **`CI`** — source **GitHub Actions** |
| &nbsp;&nbsp;Require branches to be up to date | ❌ — `main` only ever receives `develop` |

> **"Only `develop` may open PRs into `main`"** isn't expressible as a ruleset.
> The `PR source` check in [`workflows/branch-policy.yml`](workflows/branch-policy.yml)
> fails any PR into `main` whose head isn't this repo's `develop`; requiring it
> makes the rule binding.

### Ruleset `protect-develop`

Target `develop`: **Restrict deletions** ✅, **Block force pushes** ✅. No PR or
status-check requirement — direct pushes are allowed.

### Other settings

- **General:** default branch **`main`**; *Allow merge commits* ✅ (squash ✅
  for Dependabot PRs into `develop`); *Automatically delete head branches* ✅.
  In the **template repository only**: *Template repository* ✅.
- **Advanced Security:** private vulnerability reporting, dependency graph,
  Dependabot alerts + malware alerts, CodeQL default setup, secret protection +
  push protection — all ✅. **Dependabot security updates ❌**: GitHub opens
  those PRs against `main`, which only accepts PRs from `develop`.
- **Secrets and variables → Actions:** variable **`DOCKERHUB_USERNAME`**,
  secret **`DOCKERHUB_TOKEN`** (Docker Hub access token, Read & Write);
  optional secret `CODECOV_TOKEN`.

---

## 3. CI/CD

| Workflow | Triggers | What |
| --- | --- | --- |
| [`ci.yml`](workflows/ci.yml) → **`CI`** (required) | push `develop`, PR → `develop` | tiered project CI (below) |
| [`lint.yml`](workflows/lint.yml) → **`Lint`** (required) | push `develop`, PR → `develop` | hadolint · ShellCheck · actionlint · zizmor · `docker compose config` · cspell · markdownlint |
| [`branch-policy.yml`](workflows/branch-policy.yml) → **`PR source`** (required) | PR → `main` | only `develop` may open PRs into `main` |
| [`docker.yml`](workflows/docker.yml) → **Docker** | push `main` (release), tags `v*.*.*`, dispatch | publish the production image (skips until the project is initialised and `DOCKERHUB_USERNAME` is set) |
| [`dockerhub-description.yml`](workflows/dockerhub-description.yml) | push `main` touching `README.md`, dispatch | README → the image's Docker Hub page |
| [`labels.yml`](workflows/labels.yml) | push `main` touching labels, PR dry run, dispatch | `.github/labels.yml` → GitHub labels |

### CI tiers — never fails on a fresh template

| Tier | Detected by | Jobs that run |
| --- | --- | --- |
| 1 · template | no `pyproject.toml` | `pre-commit` · `Production image` (scaffolds a sample project with the documented steps, checks it with ruff · mypy strict · pytest · migrations · deploy check, then builds it and probes `/healthz` + the CSP header) |
| 2 · pre-Django | `pyproject.toml` | `pre-commit` · `pip-audit` |
| 3 · Django | `manage.py` + `uv.lock` | `pre-commit` · `mypy` · `pytest` (PostgreSQL 18 service) · `Django deploy check` (+ missing migrations) · `pip-audit` · `Production image` |

The `CI` gate job passes when every applicable job passed — skipped jobs are
simply not applicable at the current tier.

### Releases

Merging `develop` → `main` publishes
`docker.io/<DOCKERHUB_USERNAME>/<repo>` as `latest` + `sha-<short>` (native
amd64 + arm64, SBOM, Sigstore-signed provenance) and scans it with Trivy.
Tag a release `vX.Y.Z` on `main` to add `X.Y.Z` and `X.Y` tags.

### Workflow hardening (keep it when editing)

- Every action and reusable workflow pinned to a **full commit SHA** with a
  `# vX.Y.Z` comment; Dependabot bumps both.
- Explicit runners (`ubuntu-26.04`, `ubuntu-26.04-arm`), never `ubuntu-latest`.
- Top-level `permissions: contents: read`; jobs widen only what they need.
- `persist-credentials: false` on every checkout; `timeout-minutes` on every job.
- Event values reach `run:` scripts only through `env:`, never inline `${{ }}`.
- A job downstream of a skipped job needs an explicit
  `if: ${{ !cancelled() && needs.<job>.result == 'success' }}`.

---

## 4. Dependency automation — [`dependabot.yml`](dependabot.yml)

Weekly (Monday 09:00 UTC), PRs against **`develop`**, **7-day cooldown**:

| Ecosystem | Scans |
| --- | --- |
| `github-actions` | workflow action SHAs (incl. the reusable builder) |
| `docker` | `docker/Dockerfile.prod` — python base + uv (tag + digest) |
| `docker-compose` | `docker-compose.yml` — postgres, redis, mailpit (tag + digest) |
| `pre-commit` | `.pre-commit-config.yaml` hook revs |
| `uv` | `pyproject.toml` + `uv.lock` — **uncomment the block after `uv init`** |

Every label Dependabot applies exists in [`labels.yml`](labels.yml).

---

## 5. Local checks

Inside the dev container:

```bash
pre-commit run --all-files     # ruff, django-upgrade, file hygiene
pytest                         # once the project exists
mypy .
```

Repository linters (from any machine with Docker):

```bash
docker run --rm -i hadolint/hadolint hadolint - < docker/Dockerfile.prod
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable scripts/*.sh
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest
docker compose config --quiet
```
