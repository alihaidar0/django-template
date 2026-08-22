#!/usr/bin/env bash
# =============================================================================
#  scripts/entrypoint.dev.sh — Django dev container
#
#  Execution contexts this script must survive:
#
#  1. VS Code Dev Containers — app service (primary use-case)
#     VS Code overrides the entrypoint with its own /bin/sh -c wrapper and
#     passes THIS script as $1. Result: $@ is empty in our script body.
#     Fix: fall back to `sleep infinity`.
#
#  2. docker compose up — app service (standalone, no VS Code)
#     compose: entrypoint = this script, command = sleep infinity
#     Result: $@ = ("sleep" "infinity") → exec'd correctly.
#
#  3. docker compose up — celery / celery-beat services
#     compose: command = sh -c '[ -f manage.py ] && celery ...'
#     Result: $@ = ("sh" "-c" "...") → exec'd correctly.
#
#  4. docker run ... mycommand (CI, one-off management commands)
#     Result: $@ = whatever was passed → exec'd correctly.
#
#  NOTE: The prod entrypoint (entrypoint.prod.sh) does NOT use this fallback
#        because production containers always receive an explicit command
#        (gunicorn) and must never silently stay alive without one.
#
# =============================================================================
set -euo pipefail

# ── 1. SSH key permissions ────────────────────────────────────────────────────
#  Windows NTFS mounts arrive as 777 — SSH refuses keys that are world-readable.
#  This block is idempotent and silent when no SSH dir is present.
if [[ -d /root/.ssh ]]; then
  chmod 700 /root/.ssh
  find /root/.ssh -type f -name "id_*"  ! -name "*.pub" -exec chmod 600 {} +
  find /root/.ssh -type f -name "*.pub"                  -exec chmod 644 {} +
  find /root/.ssh -type f \( -name "config" -o -name "known_hosts*" \) \
                                                         -exec chmod 600 {} +
  echo "🔑  SSH key permissions fixed"
fi

# ── 2. Handoff ────────────────────────────────────────────────────────────────
#  exec "$@"  : replaces this shell with the requested command (zero overhead,
#               correct PID 1, clean signal forwarding).
#
#  sleep infinity fallback: VS Code devcontainer injection leaves $@ empty;
#               we keep the container alive so VS Code can attach and run
#               postCreateCommand / postStartCommand normally.
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  echo "✅  Entrypoint complete — container ready (VS Code devcontainer mode)"
  exec sleep infinity
fi