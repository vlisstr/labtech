#!/usr/bin/env bash
# =============================================================================
# Self-hosted GitHub Actions runner setup (Lab #3).
#
# Run on a separate Ubuntu 24.04 Server VM (NOT the target node). Installs
# everything needed to run the runner, but DOES NOT register it — the
# registration token is short-lived and must NEVER be committed to the repo.
#
# Usage:
#     sudo bash deploy/runner-setup.sh
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

[[ $EUID -eq 0 ]] || { echo "This script must be run as root (use sudo)" >&2; exit 1; }

RUNNER_USER="actions"
RUNNER_HOME="/home/$RUNNER_USER"
RUNNER_DIR="$RUNNER_HOME/actions-runner"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "1/4: installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  curl ca-certificates jq git openssh-client tar

log "2/4: installing Docker (needed if image build runs on this runner; harmless otherwise)"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

log "3/4: creating $RUNNER_USER user"
if ! id -u "$RUNNER_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$RUNNER_USER"
fi
usermod -aG docker "$RUNNER_USER"

log "4/4: downloading GitHub Actions runner"
mkdir -p "$RUNNER_DIR"

LATEST=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest \
  | jq -r .tag_name | sed 's/^v//')

if [[ ! -x "$RUNNER_DIR/run.sh" ]]; then
  curl -fsSL -o "$RUNNER_DIR/runner.tar.gz" \
    "https://github.com/actions/runner/releases/download/v${LATEST}/actions-runner-linux-x64-${LATEST}.tar.gz"
  tar -C "$RUNNER_DIR" -xzf "$RUNNER_DIR/runner.tar.gz"
  rm -f "$RUNNER_DIR/runner.tar.gz"
fi

chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
"$RUNNER_DIR/bin/installdependencies.sh"

cat <<EOF

================================================================================
  Runner downloaded to $RUNNER_DIR (version $LATEST).

  REMAINING MANUAL STEPS (token is short-lived — do NOT commit it):

  1) On GitHub:
        Settings → Actions → Runners → New self-hosted runner
     Copy the registration TOKEN displayed there.

  2) Register the runner:
        sudo -iu $RUNNER_USER
        cd actions-runner
        ./config.sh --url https://github.com/<owner>/<repo> --token <TOKEN>
        exit

  3) Install and start as a systemd service:
        cd $RUNNER_DIR
        sudo ./svc.sh install $RUNNER_USER
        sudo ./svc.sh start
        sudo ./svc.sh status

  4) Generate the SSH key the runner will use to reach the target VM:
        sudo -iu $RUNNER_USER ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""
        sudo cat $RUNNER_HOME/.ssh/deploy_key.pub
        # → append to /home/deploy/.ssh/authorized_keys on the target VM
        sudo cat $RUNNER_HOME/.ssh/deploy_key
        # → paste the WHOLE content as repo secret TARGET_SSH_KEY on GitHub
================================================================================
EOF
