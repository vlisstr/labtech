#!/usr/bin/env bash
# =============================================================================
# /usr/local/bin/mywebapp-deploy <image-repo> <image-tag>
#
# Invoked over SSH by the CD pipeline, via sudo, by the `deploy` user.
# Updates /opt/mywebapp/.env with the new image reference and restarts the
# systemd unit, which triggers `docker compose pull` + `up -d`.
# =============================================================================

set -euo pipefail

IMAGE_REPO="${1:?usage: mywebapp-deploy <image-repo> <image-tag>}"
IMAGE_TAG="${2:?usage: mywebapp-deploy <image-repo> <image-tag>}"
ENV_FILE=/opt/mywebapp/.env

[[ -f "$ENV_FILE" ]] || { echo "missing $ENV_FILE — was target-setup.sh run?" >&2; exit 1; }

# Basic input sanity: no shell-meta in tag or repo (defence in depth).
if [[ ! "$IMAGE_REPO" =~ ^[a-z0-9._/-]+$ ]]; then
  echo "Invalid image repo: $IMAGE_REPO" >&2
  exit 2
fi
if [[ ! "$IMAGE_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid image tag: $IMAGE_TAG" >&2
  exit 2
fi

set_var() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

set_var GITHUB_REPO "$IMAGE_REPO"
set_var APP_TAG     "$IMAGE_TAG"

echo "Updated $ENV_FILE — restarting mywebapp.service"
systemctl restart mywebapp.service

# Give the stack a moment to come up.
for i in {1..30}; do
  sleep 2
  if curl -fsS -H 'Accept: application/json' "http://127.0.0.1/" >/dev/null 2>&1; then
    echo "App is reachable on http://127.0.0.1/"
    exit 0
  fi
done

echo "WARNING: app not yet reachable after 60s — check 'systemctl status mywebapp' and container logs" >&2
exit 0
