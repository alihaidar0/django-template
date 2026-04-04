#!/usr/bin/env bash
# scripts/entrypoint.dev.sh
#
# Runs before any container command.
# Fixes SSH key permissions broken by Windows NTFS mounts (all files arrive as 777).

set -euo pipefail

if [ -d /root/.ssh ]; then
    chmod 700 /root/.ssh
    find /root/.ssh -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
    find /root/.ssh -type f -name "*.pub"                 -exec chmod 644 {} \;
    find /root/.ssh -type f \( -name "config" -o -name "known_hosts*" \) -exec chmod 600 {} \;
fi

exec "$@"
