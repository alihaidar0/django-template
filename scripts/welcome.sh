#!/usr/bin/env bash
# scripts/welcome.sh
#
# Shown every time the container starts (postStartCommand in devcontainer.json).
# Displays context-aware guidance based on project state.

set -euo pipefail

WORKSPACE=/workspace
VENV="$WORKSPACE/.venv"

# ── Activate venv if it exists ────────────────────────────────────────────────
if [ -d "$VENV" ]; then
    if ! grep -q "source $VENV/bin/activate" /root/.bashrc 2>/dev/null; then
        echo "source $VENV/bin/activate" >> /root/.bashrc
    fi
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐍  django-template — dev container ready"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Context-aware state ───────────────────────────────────────────────────────
if [ -f "$WORKSPACE/manage.py" ]; then
    echo ""
    echo "  ✅  Django project detected"
    echo ""
    echo "  ❯ Quick commands:"
    echo "    pmr    → python manage.py runserver 0.0.0.0:8000"
    echo "    pmm    → python manage.py migrate"
    echo "    pmmk   → python manage.py makemigrations"
    echo "    pms    → python manage.py shell"
    echo "    pmsu   → python manage.py createsuperuser"
    echo ""
    echo "  ❯ Services:"
    echo "    Django  → http://localhost:8000"
    echo "    Mailpit → http://localhost:8025"
    echo "    Flower  → http://localhost:5555"

elif [ -f "$WORKSPACE/pyproject.toml" ]; then
    echo ""
    echo "  ℹ️   pyproject.toml found — Django not yet initialised"
    echo ""
    echo "  ┌─ Next: scaffold Django ────────────────────────────────────────┐"
    echo "  │  uv add django djangorestframework 'psycopg[binary,pool]' \\   │"
    echo "  │         redis celery django-celery-beat                   \\   │"
    echo "  │         gunicorn python-decouple                               │"
    echo "  │                                                                │"
    echo "  │  uv add --dev                                             \\   │"
    echo "  │    pytest pytest-django pytest-cov pytest-asyncio          \\   │"
    echo "  │    factory-boy faker mypy django-stubs pip-audit ipython       │"
    echo "  │                                                                │"
    echo "  │  django-admin startproject config .                            │"
    echo "  │  python manage.py migrate                                      │"
    echo "  │  python manage.py runserver 0.0.0.0:8000                      │"
    echo "  └────────────────────────────────────────────────────────────────┘"

else
    echo ""
    echo "  👋  Fresh template — no project initialised yet"
    echo ""
    echo "  ┌─ Step 1: Initialise uv ────────────────────────────────────────┐"
    echo "  │  uv init --no-package                                          │"
    echo "  └────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ Step 2: Add production dependencies ──────────────────────────┐"
    echo "  │  uv add django djangorestframework 'psycopg[binary,pool]' \\   │"
    echo "  │         redis celery django-celery-beat                   \\   │"
    echo "  │         gunicorn python-decouple                               │"
    echo "  └────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ Step 3: Add dev / test dependencies ──────────────────────────┐"
    echo "  │  uv add --dev                                             \\   │"
    echo "  │    pytest pytest-django pytest-cov pytest-asyncio          \\   │"
    echo "  │    factory-boy faker mypy django-stubs pip-audit ipython       │"
    echo "  └────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ Step 4: Scaffold Django project ──────────────────────────────┐"
    echo "  │  django-admin startproject config .                            │"
    echo "  └────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ┌─ Step 5: Apply migrations & start server ───────────────────────┐"
    echo "  │  python manage.py migrate                                       │"
    echo "  │  python manage.py runserver 0.0.0.0:8000                       │"
    echo "  └─────────────────────────────────────────────────────────────────┘"
fi

echo ""
echo "  ❯ Git aliases:  gs · ga · gc · gp"
echo "  📖  https://github.com/alihaidar199527/django-template"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
