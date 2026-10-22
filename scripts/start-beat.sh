#!/usr/bin/env bash
# =============================================================
#  scripts/start-beat.sh — command of the celery-beat service
#  (docker-compose.yml)
#
#  Beat keeps its schedule in the database (django-celery-beat's
#  DatabaseScheduler), so it must not start before the tables exist,
#  and it must not start by itself against a database that is not
#  the local dev one:
#
#  1. Database guard: reads the host of DATABASE_URL. The compose `db`
#     service, localhost and a unix socket (empty host) continue. Any
#     other host is an external database, where Beat would schedule
#     periodic jobs on its own and the local worker would run them on
#     that data. Beat then stays idle, logging only the host name (never
#     credentials), until BEAT_ON_EXTERNAL_DATABASE=true is set.
#  2. Waits for manage.py and the project venv (the quickstart's uv sync).
#  3. Waits for `manage.py migrate --check` to pass, logging the reason
#     once per change: pending migrations, or the full error (wrong URL,
#     settings, database down). It never exits while waiting, so the
#     cause can be fixed from inside the dev container and Beat starts
#     by itself within seconds.
#
#  The worker is not guarded: it only runs tasks that something enqueues.
# =============================================================

set -euo pipefail

cd /workspace

POLL_SECONDS=5

log() { printf '⏳ Celery Beat: %s\n' "$*"; }

# ── 1. Database guard ───────────────────────────────────────────────────────
# Parsed with urllib (standard library, so it works before the venv exists):
# passwords may contain @ : % and hosts may be IPv6, which sed gets wrong.
db_host=$(python -c '
import os
from urllib.parse import urlsplit

try:
    print(urlsplit(os.environ.get("DATABASE_URL", "")).hostname or "")
except ValueError:
    print("<unreadable>")
')

case "$db_host" in
    "" | db | localhost | 127.0.0.1 | ::1) ;;
    *)
        if [[ "${BEAT_ON_EXTERNAL_DATABASE:-false}" == "true" ]]; then
            log "DATABASE_URL points at '${db_host}' — starting anyway (BEAT_ON_EXTERNAL_DATABASE=true)."
        else
            log "DATABASE_URL points at '${db_host}', not the local dev database — staying idle, so Beat schedules no jobs there."
            log "To run it anyway, set BEAT_ON_EXTERNAL_DATABASE=true in .env and recreate it: docker compose up -d celery-beat"
            # Idle on purpose (not a crash loop): the container stays up and
            # the reason above stays in its log.
            while true; do sleep 3600; done
        fi
        ;;
esac

# ── 2. Project and dependencies ─────────────────────────────────────────────
log "waiting for manage.py and the project venv (uv sync)…"
until [[ -f manage.py && -x .venv/bin/celery ]]; do sleep "$POLL_SECONDS"; done

# ── 3. Migrations ───────────────────────────────────────────────────────────
# `migrate --check -v 0` prints nothing and exits 1 while migrations are
# pending (also on an empty database); a failure (database unreachable, bad
# settings) prints its error. Empty output therefore means "pending".
last=""
while ! output=$(python manage.py migrate --check --verbosity 0 2>&1); do
    if [[ -z "$output" ]]; then
        message="waiting for the migrations — run: python manage.py migrate"
    else
        message="'migrate --check' failed, retrying every ${POLL_SECONDS}s:"$'\n'"${output}"
    fi
    if [[ "$message" != "$last" ]]; then
        log "$message"
        last=$message
    fi
    sleep "$POLL_SECONDS"
done

log "migrations applied — starting."
exec celery -A config beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
