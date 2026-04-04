#!/usr/bin/env bash
# scripts/entrypoint.prod.sh
#
# Production container entrypoint.
# Runs migrations then starts Gunicorn.

set -euo pipefail

echo "▶  Running database migrations..."
uv run python manage.py migrate --no-input

echo "▶  Starting Gunicorn..."
exec "$@"
