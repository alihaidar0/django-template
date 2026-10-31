#!/usr/bin/env bash
# =============================================================
#  check-node-pin.sh — is the Node.js pin of the git hooks still healthy?
#
#  .pre-commit-config.yaml pins one exact Node.js (default_language_version →
#  node) for the cspell and markdownlint hooks, so the dev container, CI and
#  every other machine run the same version. Dependabot cannot bump that line,
#  so this check watches it against nodejs.org:
#    * the pin must be a published release and an LTS one,
#    * its release line must not be end-of-life, nor within 90 days of it,
#    * --strict only: the pin must be the newest LTS release (the weekly
#      template run; a project gets the warnings above, never a failure).
#
#  Without --strict every finding is a warning and the script exits 0, even
#  when nodejs.org cannot be reached, so CI never fails because of it.
#  Run from the repository root; needs curl, jq and GNU date (runners have them).
# =============================================================
set -euo pipefail

strict=false
[ "${1:-}" = "--strict" ] && strict=true

status=0
findings=0
problem() {
  findings=$((findings + 1))
  if "${strict}"; then
    echo "::error::$*"
    status=1
  else
    echo "::warning title=Node.js pin::$*"
  fi
}

pin="$(grep -A4 '^default_language_version:' .pre-commit-config.yaml 2>/dev/null \
  | grep -oE 'node:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9.]+$' | head -1 || true)"
if [ -z "${pin}" ]; then
  problem "No exact Node.js version (x.y.z) under default_language_version in .pre-commit-config.yaml."
  exit "${status}"
fi

# nodejs.org is only a data source here: when it is unreachable, say so and stop.
if ! index="$(curl -fsSL --retry 3 --max-time 30 https://nodejs.org/dist/index.json)" \
  || ! schedule="$(curl -fsSL --retry 3 --max-time 30 https://raw.githubusercontent.com/nodejs/Release/main/schedule.json)"; then
  echo "::notice::Could not read the Node.js release data; the pin (${pin}) was not checked."
  "${strict}" && exit 1
  exit 0
fi

# Newest LTS release: highest version among those flagged LTS (a patch of an older
# line can be published later than the newest line's first release).
latest="$(jq -r '[.[] | select(.lts != false) | .version | ltrimstr("v") | split(".") | map(tonumber)]
  | sort | last | join(".")' <<< "${index}")"

jq -e --arg v "v${pin}" 'any(.[]; .version == $v)' <<< "${index}" > /dev/null \
  || problem "Node.js ${pin} is not a published release; set a real x.y.z (newest LTS: ${latest})."
jq -e --arg v "v${pin}" 'any(.[]; .version == $v and .lts != false)' <<< "${index}" > /dev/null \
  || problem "Node.js ${pin} is not an LTS release; pin an LTS (newest: ${latest})."

line="v${pin%%.*}"
end="$(jq -r --arg l "${line}" '.[$l].end // empty' <<< "${schedule}")"
if [ -n "${end}" ]; then
  days=$(( ($(date -u -d "${end}" +%s) - $(date -u +%s)) / 86400 ))
  if [ "${days}" -lt 0 ]; then
    problem "Node.js ${line} reached end-of-life on ${end}; move the pin to ${latest}."
  elif [ "${days}" -lt 90 ]; then
    problem "Node.js ${line} reaches end-of-life on ${end} (${days} days); plan the move to ${latest}."
  fi
fi

if "${strict}" && [ "${pin}" != "${latest}" ]; then
  problem "default_language_version pins Node.js ${pin} but the newest LTS is ${latest}; bump it in .pre-commit-config.yaml."
fi

if [ "${findings}" -eq 0 ]; then
  echo "Node.js pin ${pin} is a supported LTS release (newest LTS: ${latest})."
fi
exit "${status}"
