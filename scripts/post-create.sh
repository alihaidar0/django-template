#!/usr/bin/env bash
# =============================================================
#  scripts/post-create.sh — runs once when the dev container is
#  created (postCreateCommand in .devcontainer/devcontainer.json)
#
#  1. Hands the .venv volume to the `dev` user (Docker creates new
#     named volumes root-owned).
#  2. Existing project (uv.lock present, e.g. a fresh clone): installs
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
