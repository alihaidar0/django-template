#!/usr/bin/env bash
# =============================================================
#  check-tool-pins.sh — do the Lint workflow's tool versions match the hooks?
#
#  actionlint and zizmor run twice: as git hooks (.pre-commit-config.yaml, whose
#  revs Dependabot bumps weekly) and in the Lint workflow (the `version:` input of
#  each action in lint.yml, which no Dependabot ecosystem reads). This check keeps
#  the two equal, so CI and the hooks report the same findings:
#    actionlint  lint.yml `version: X.Y.Z`  =  actionlint-py rev vX.Y.Z.N
#    zizmor      lint.yml `version: X.Y.Z`  =  zizmor-pre-commit rev vX.Y.Z
#
#  Without --strict a difference is a warning and the script exits 0 (CI on every
#  pull request: a Dependabot hook bump must not fail by itself). --strict fails
#  (the weekly Image contract run of the template), so a difference cannot stay
#  unnoticed. Run from the repository root.
# =============================================================
set -euo pipefail

strict=false
[ "${1:-}" = "--strict" ] && strict=true
status=0

problem() {
  if "${strict}"; then
    echo "::error::$*"
    status=1
  else
    echo "::warning title=Tool pins::$*"
  fi
}

# The `version:` input of the lint.yml step that uses the given action.
workflow_pin() {
  awk -v action="$1" '
    index($0, "uses: " action "@") { found = 1; next }
    found && /^[[:space:]]*- name:/ { exit }
    found && /^[[:space:]]*version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+/ {
      sub(/^[[:space:]]*version:[[:space:]]*/, ""); print $1; exit
    }' .github/workflows/lint.yml
}

# The rev of the given hook repository in .pre-commit-config.yaml, as X.Y.Z.
hook_pin() {
  grep -A1 -F "repo: $1" .pre-commit-config.yaml \
    | grep -oE 'rev:[[:space:]]*v?[0-9]+\.[0-9]+\.[0-9]+' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

check() { # tool name, action, hook repository
  local workflow hook
  workflow="$(workflow_pin "$2")"
  hook="$(hook_pin "$3")"
  if [ -z "${workflow}" ]; then
    problem "lint.yml pins no ${1} version (a 'version: X.Y.Z' input on the $2 step)."
  elif [ -z "${hook}" ]; then
    problem "No rev for $3 in .pre-commit-config.yaml."
  elif [ "${workflow}" != "${hook}" ]; then
    problem "${1}: lint.yml runs ${workflow} but the git hook runs ${hook}. Set 'version: ${hook}' on the $2 step in .github/workflows/lint.yml."
  else
    echo "${1} ${workflow}: lint.yml and the git hook agree."
  fi
}

check actionlint raven-actions/actionlint https://github.com/Mateusz-Grzelinski/actionlint-py
check zizmor zizmorcore/zizmor-action https://github.com/zizmorcore/zizmor-pre-commit
exit "${status}"
