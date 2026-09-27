#!/usr/bin/env bash
# =============================================================
#  scripts/welcome.sh — shown on every container start
#  (postStartCommand in .devcontainer/devcontainer.json)
#
#  Prints the next steps for the project's current state. No venv
#  activation is needed: the dev image puts /workspace/.venv/bin
#  first on PATH, so python / celery / pytest resolve to the project.
# =============================================================

set -euo pipefail

WORKSPACE=/workspace
RULE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

step() {  # step "<title>" <line>...
    local title=$1; shift
    echo ""
    echo "  ▸ ${title}"
    printf '      %s\n' "$@"
}

echo ""
echo "$RULE"
echo "  🐍  Django dev container ready — $(python --version 2>&1), uv $(uv --version | cut -d' ' -f2)"
echo "$RULE"

if [[ -f "$WORKSPACE/manage.py" ]]; then
    echo ""
    echo "  ✅  Django project detected"
    step "Run" \
        "pmr   python manage.py runserver 0.0.0.0:8000" \
        "pmm   python manage.py migrate      ·  pmmk  makemigrations" \
        "pms   python manage.py shell        ·  pmsu  createsuperuser" \
        "pytest                              ·  pre-commit run --all-files"
    step "Services" \
        "Django   http://localhost:8000" \
        "Mailpit  http://localhost:8025" \
        "Flower   cf  →  http://localhost:5555"

elif [[ -f "$WORKSPACE/pyproject.toml" ]]; then
    echo ""
    echo "  ℹ️   pyproject.toml found — Django not initialised yet"
    step "Add dependencies (if not done yet)" \
        "uv add django djangorestframework 'psycopg[binary,pool]' dj-database-url \\" \
        "       redis celery django-celery-beat gunicorn whitenoise" \
        "uv add --dev pytest pytest-django pytest-cov factory-boy faker \\" \
        "             mypy django-stubs celery-types pip-audit ipython"
    step "Scaffold Django (settings split, Celery, env-driven config)" \
        "bash scripts/init-django.sh"
    step "Hooks, database, server" \
        "pre-commit install" \
        "python manage.py migrate" \
        "python manage.py runserver 0.0.0.0:8000"

else
    echo ""
    echo "  👋  Fresh template — six steps to a running Django project"
    step "1. Initialise uv" \
        "uv init --bare"
    step "2. Production dependencies" \
        "uv add django djangorestframework 'psycopg[binary,pool]' dj-database-url \\" \
        "       redis celery django-celery-beat gunicorn whitenoise"
    step "3. Dev / test dependencies" \
        "uv add --dev pytest pytest-django pytest-cov factory-boy faker \\" \
        "             mypy django-stubs celery-types pip-audit ipython"
    step "4. Scaffold Django (settings split, Celery, env-driven config)" \
        "bash scripts/init-django.sh"
    step "5. Git hooks (pre-commit + commit-msg)" \
        "pre-commit install"
    step "6. Database and server" \
        "python manage.py migrate" \
        "python manage.py runserver 0.0.0.0:8000"
fi

step "Committing from the host too, not just this container?" \
    "The same git hooks run there — install pre-commit + uv on the host once," \
    "or a host commit stops with \"pre-commit not found\" (README → Git and SSH)."

echo ""
echo "  📖  https://github.com/alihaidar0/django-template#readme"
echo "$RULE"
echo ""
