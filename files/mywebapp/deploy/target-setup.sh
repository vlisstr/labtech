#!/usr/bin/env bash
# =============================================================================
# Target node setup script (Lab #3).
#
# Run on a fresh Ubuntu 24.04 Server VM. Installs everything the CD pipeline
# needs in order to deploy the container stack via SSH from the self-hosted
# runner:
#
#   * Docker Engine + compose plugin
#   * /opt/mywebapp/ with docker-compose.yml, nginx.conf, .env
#   * a `deploy` user that the runner SSHes in as
#   * a systemd unit that wraps `docker compose up/down`
#   * /usr/local/bin/mywebapp-deploy — sudo-callable helper for the deploy user
#
# Usage:
#     sudo bash deploy/target-setup.sh
#
# After this finishes:
#   1) Edit /opt/mywebapp/.env — set GITHUB_REPO=<owner>/<repo> (lower case)
#   2) Append the runner's public key to /home/deploy/.ssh/authorized_keys
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

[[ $EUID -eq 0 ]] || { echo "This script must be run as root (use sudo)" >&2; exit 1; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

DEPLOY_USER="deploy"
APP_DIR="/opt/mywebapp"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# --- 1. Docker ---------------------------------------------------------------
log "1/6: installing Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

# --- 2. App directory & compose files ----------------------------------------
log "2/6: preparing $APP_DIR"
mkdir -p "$APP_DIR/nginx"

cp "$REPO_ROOT/deploy/compose-target/docker-compose.yml" "$APP_DIR/docker-compose.yml"
cp "$REPO_ROOT/deploy/compose-target/nginx.conf"          "$APP_DIR/nginx/nginx.conf"

if [[ ! -f "$APP_DIR/.env" ]]; then
  cat > "$APP_DIR/.env" <<EOF
# Edit GITHUB_REPO once after the first run; the rest is updated by the CD pipeline.
GITHUB_REPO=YOUR_GITHUB_USER/YOUR_REPO_NAME
APP_TAG=latest
DB_PASSWORD=$(openssl rand -hex 16)
DB_ROOT_PASSWORD=$(openssl rand -hex 16)
EOF
  chmod 600 "$APP_DIR/.env"
  log "  + generated /opt/mywebapp/.env with random DB passwords"
else
  log "  = /opt/mywebapp/.env already exists, leaving as-is"
fi

# --- 3. Deploy user ----------------------------------------------------------
log "3/6: creating $DEPLOY_USER user for CD SSH access"
if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$DEPLOY_USER"
fi
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
touch "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"

# --- 4. systemd unit ---------------------------------------------------------
log "4/6: installing systemd unit"
cp "$REPO_ROOT/deploy/systemd/mywebapp.service" /etc/systemd/system/mywebapp.service
systemctl daemon-reload
systemctl enable mywebapp.service

# --- 5. deploy helper + sudoers ---------------------------------------------
log "5/6: installing mywebapp-deploy helper and sudoers rule"
cp "$REPO_ROOT/deploy/mywebapp-deploy.sh" /usr/local/bin/mywebapp-deploy
chmod 755 /usr/local/bin/mywebapp-deploy

cat > /etc/sudoers.d/deploy <<'EOF'
# The deploy user may invoke the mywebapp-deploy helper with any arguments.
# The helper itself validates inputs.
deploy ALL=(root) NOPASSWD: /usr/local/bin/mywebapp-deploy *
EOF
chmod 0440 /etc/sudoers.d/deploy
visudo -cf /etc/sudoers.d/deploy >/dev/null

# --- 6. summary --------------------------------------------------------------
log "6/6: done"

cat <<EOF

================================================================================
  Target VM setup complete.

  REMAINING MANUAL STEPS:

  1) Edit /opt/mywebapp/.env and set GITHUB_REPO=<owner>/<repo>
     (lower-case, e.g. johndoe/mywebapp-lab1).

  2) On the RUNNER VM, generate an SSH key for the deploy user:
        sudo -iu actions ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""

     Append the corresponding public key here:
        echo '<runner-public-key>' >> /home/${DEPLOY_USER}/.ssh/authorized_keys

  3) In the GitHub repo, set secrets:
        TARGET_HOST    = $(hostname -I | awk '{print $1}')   (or public IP)
        TARGET_USER    = ${DEPLOY_USER}
        TARGET_SSH_KEY = <full contents of ~/.ssh/deploy_key on the runner>

  4) Push an annotated tag to trigger the first deploy:
        git tag -a v0.1.0 -m "first release"
        git push --tags

================================================================================
EOF
