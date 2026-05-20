#!/usr/bin/env bash
# =============================================================================
# Deploy script — invoked by the GitHub Actions CD job on the self-hosted
# runner. Updates the image tag in /opt/mywebapp/.env on the target VM and
# restarts the systemd unit, which in turn pulls the new image and recreates
# the container.
# =============================================================================

set -euo pipefail

: "${TARGET_USER:?missing}"
: "${TARGET_HOST:?missing}"
: "${IMAGE_TAG:?missing}"
: "${GITHUB_REPO_LC:?missing}"

# Container registry stores names in lower case.
IMAGE_REPO=$(echo "$GITHUB_REPO_LC" | tr '[:upper:]' '[:lower:]')

echo "Deploy: image=ghcr.io/${IMAGE_REPO}:${IMAGE_TAG} → ${TARGET_USER}@${TARGET_HOST}"

ssh -i "$HOME/.ssh/deploy_key" \
    -o StrictHostKeyChecking=accept-new \
    "${TARGET_USER}@${TARGET_HOST}" \
    "sudo /usr/local/bin/mywebapp-deploy '${IMAGE_REPO}' '${IMAGE_TAG}'"

echo "Deploy: SSH command finished"
