#!/usr/bin/env bash
# =============================================================
#  scripts/post-create.sh — runs once when the dev container is
#  created (postCreateCommand in .devcontainer/devcontainer.json)
#
#  1. Git + SSH: trusts /workspace and copies the host's SSH settings
#     (config, known_hosts, public keys) so `git push` works with the
#     same host aliases as on the host. Keys come from the forwarded
#     ssh-agent; private keys are never copied.
#  2. Hands the .venv volume to the `dev` user (Docker creates new
#     named volumes root-owned).
#  3. Existing project (uv.lock present, e.g. a fresh clone): installs
#     the locked dependencies and the git hooks — ready to run.
#     Fresh template: does nothing more; welcome.sh shows the steps.
# =============================================================

set -euo pipefail

cd /workspace

# Bind-mounted files from Windows/macOS hosts show a different owner, which git
# refuses to work with ("dubious ownership"). Trust the workspace once.
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qx /workspace; then
    git config --global --add safe.directory /workspace
fi

# ── SSH settings from the host (docker-compose.yml mounts ~/.ssh read-only) ──
# Copied rather than used in place: ssh rejects a config or key file that other
# users can read, and bind mounts from Windows show every file as world-readable.
# The *.pub files let `IdentityFile ~/.ssh/<key>` + `IdentitiesOnly yes` select
# the matching key from the forwarded agent without the private key present.
host_ssh=/home/dev/.ssh-host
if [[ -d $host_ssh ]]; then
    echo "▶ Copying SSH config, known_hosts and public keys from the host"
    install -d -m 700 ~/.ssh
    for f in config known_hosts; do
        if [[ -f $host_ssh/$f ]]; then install -m 600 "$host_ssh/$f" ~/.ssh/"$f"; fi
    done
    for pub in "$host_ssh"/*.pub; do
        if [[ -f $pub ]]; then install -m 644 "$pub" ~/.ssh/; fi
    done
fi
if ! ssh-add -l >/dev/null 2>&1; then
    echo "⚠ No SSH keys reachable in the container — start the host's ssh-agent and add"
    echo "  your key (Windows: the 'OpenSSH Authentication Agent' service + ssh-add), then"
    echo "  reopen the container. See README → Git and SSH."
fi

if [[ -d .venv && ! -O .venv ]]; then
    echo "▶ Giving the .venv volume to $(id -un)"
    sudo chown "$(id -u):$(id -g)" .venv
fi

if [[ -f uv.lock ]]; then
    echo "▶ uv sync --locked"
    uv sync --locked
fi

if [[ -f pyproject.toml && -f .pre-commit-config.yaml ]] && git rev-parse --git-dir >/dev/null 2>&1; then
    echo "▶ pre-commit install"
    pre-commit install --install-hooks
fi
