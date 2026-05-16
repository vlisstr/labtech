
set -euo pipefail
IFS=$'\n\t'

N_VALUE=26

APP_NAME="mywebapp"
APP_USER="mywebapp"            
APP_DIR="/opt/mywebapp"
APP_HOST="127.0.0.1"
APP_PORT="5200"

DB_NAME="mywebapp"
DB_USER="mywebapp"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_PASSWORD="${DB_PASSWORD:-mywebapp_dev_pass}"  

DEFAULT_HUMAN_PASSWORD="12345678"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || fail "this script must be run as root (use sudo)"
}

step_packages() {
  log "Step 1/8: installing packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    nginx \
    mariadb-server \
    mariadb-client \
    nodejs \
    npm \
    curl \
    ca-certificates \
    sudo
}

create_system_user() {
  local user="$1" home="$2"
  if ! id -u "$user" >/dev/null 2>&1; then
    useradd --system --home-dir "$home" --shell /usr/sbin/nologin "$user"
    log "  + system user $user created"
  else
    log "  = system user $user already exists"
  fi
}

create_human_user() {
  local user="$1" extra_groups="$2"
  if ! id -u "$user" >/dev/null 2>&1; then
    if [[ -n "$extra_groups" ]]; then
      useradd --create-home --shell /bin/bash --groups "$extra_groups" "$user"
    else
      useradd --create-home --shell /bin/bash "$user"
    fi
    echo "${user}:${DEFAULT_HUMAN_PASSWORD}" | chpasswd
    passwd --expire "$user"
    log "  + user $user (groups=${extra_groups:-none}) created, password expired"
  else
    log "  = user $user already exists (leaving as-is)"
  fi
}

step_users() {
  log "Step 2/8: creating users"
  create_system_user "$APP_USER" "$APP_DIR"
  create_human_user student sudo   
  create_human_user teacher sudo   
  create_human_user operator ""    
}

step_database() {
  log "Step 3/8: configuring MariaDB and creating database"

  cat >/etc/mysql/mariadb.conf.d/99-mywebapp.cnf <<EOF
[mysqld]
bind-address = 127.0.0.1
port = ${DB_PORT}
EOF

  systemctl enable --now mariadb
  systemctl restart mariadb

  for i in {1..30}; do
    if mysqladmin --protocol=socket -uroot ping >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  mysql --protocol=socket -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
}

step_app() {
  log "Step 4/8: deploying app to ${APP_DIR}"

  mkdir -p "$APP_DIR"
  cp -rT "$REPO_ROOT/app" "$APP_DIR"
  chown -R "$APP_USER:$APP_USER" "$APP_DIR"

  NODE_BIN="$(command -v node || command -v nodejs || true)"
  [[ -n "$NODE_BIN" ]] || fail "node binary not found after install"
  log "  using node binary: ${NODE_BIN} ($(${NODE_BIN} --version))"

  log "  installing npm dependencies (as ${APP_USER})"
  ( cd "$APP_DIR" && sudo -u "$APP_USER" npm install --omit=dev --no-audit --no-fund --no-progress )
}

step_systemd() {
  log "Step 5/8: installing systemd units"

  local db_args="--db-host ${DB_HOST} --db-port ${DB_PORT} --db-user ${DB_USER} --db-password ${DB_PASSWORD} --db-name ${DB_NAME}"

  
  cat >/etc/systemd/system/${APP_NAME}.socket <<EOF
[Unit]
Description=mywebapp listening socket
PartOf=${APP_NAME}.service

[Socket]
ListenStream=${APP_HOST}:${APP_PORT}
NoDelay=true

[Install]
WantedBy=sockets.target
EOF

  cat >/etc/systemd/system/${APP_NAME}.service <<EOF
[Unit]
Description=mywebapp - Simple Inventory
Requires=${APP_NAME}.socket
After=${APP_NAME}.socket network.target mariadb.service
Wants=mariadb.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}

# Run DB migrations before starting the server.
ExecStartPre=${NODE_BIN} ${APP_DIR}/migrate.js ${db_args}
ExecStart=${NODE_BIN} ${APP_DIR}/server.js --host ${APP_HOST} --port ${APP_PORT} ${db_args}

Restart=on-failure
RestartSec=2

# Hardening — minimum-rights principle for the app user.
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ${APP_NAME}.socket
  systemctl restart ${APP_NAME}.socket
  systemctl restart ${APP_NAME}.service
}


  log "Step 6/8: configuring nginx"

  cat >/etc/nginx/sites-available/${APP_NAME} <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log  /var/log/nginx/${APP_NAME}_error.log;

    # Root — list of business endpoints (HTML only).
    location = / {
        proxy_pass http://${APP_HOST}:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Business endpoints.
    location /items {
        proxy_pass http://${APP_HOST}:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Everything else is hidden from the outside world (in particular,
    # /health/* must NOT be reachable through nginx, per the spec).
    location / {
        return 404;
    }
}
EOF

  rm -f /etc/nginx/sites-enabled/default
  ln -sf /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/${APP_NAME}

  nginx -t
  systemctl enable nginx
  systemctl restart nginx
}


step_sudoers() {
  log "Step 7/8: installing sudoers entry for operator"

 
  cat >/etc/sudoers.d/operator <<'EOF'
# Limited sudo privileges for the "operator" user — manage mywebapp + nginx.
Cmnd_Alias MYWEBAPP_CTL = \
    /usr/bin/systemctl start mywebapp.service,    \
    /usr/bin/systemctl stop mywebapp.service,     \
    /usr/bin/systemctl restart mywebapp.service,  \
    /usr/bin/systemctl status mywebapp.service,   \
    /usr/bin/systemctl start mywebapp.socket,     \
    /usr/bin/systemctl stop mywebapp.socket,      \
    /usr/bin/systemctl restart mywebapp.socket,   \
    /usr/bin/systemctl status mywebapp.socket

Cmnd_Alias NGINX_CTL = \
    /usr/bin/systemctl reload nginx.service,      \
    /usr/bin/systemctl reload nginx

operator ALL=(root) MYWEBAPP_CTL, NGINX_CTL
EOF
  chmod 0440 /etc/sudoers.d/operator
  visudo -cf /etc/sudoers.d/operator >/dev/null
}

step_finalize() {
  log "Step 8/8: finalising"

  echo "${N_VALUE}" >/home/student/gradebook
  chown student:student /home/student/gradebook
  chmod 0644 /home/student/gradebook
  log "  + /home/student/gradebook = ${N_VALUE}"

  if id -u ubuntu >/dev/null 2>&1; then
    usermod -L ubuntu
    usermod -s /usr/sbin/nologin ubuntu
    log "  + default user 'ubuntu' locked & shell disabled"
  else
    log "  = no default 'ubuntu' user found"
  fi

  log "  smoke test:"
  sleep 1
  if curl -sf -o /dev/null -H 'Accept: application/json' http://127.0.0.1/items; then
    log "    GET / via nginx → OK"
  else
    log "    WARNING: GET / via nginx failed (check 'systemctl status mywebapp' and journalctl)"
  fi
}


main() {
  require_root

  step_packages
  step_users
  step_database
  step_app
  step_systemd
  step_nginx
  step_sudoers
  step_finalize

  cat <<EOF

  Deployment complete.

  Test from the VM:
    curl -H 'Accept: application/json' http://127.0.0.1/
    curl -H 'Accept: application/json' http://127.0.0.1/items
    curl -H 'Accept: application/json' -X POST                                  \\
         -d 'name=screwdriver&quantity=5' http://127.0.0.1/items

  Health endpoints (NOT reachable via nginx, only on localhost:${APP_PORT}):
    curl http://127.0.0.1:${APP_PORT}/health/alive
    curl http://127.0.0.1:${APP_PORT}/health/ready

  Users (default password: ${DEFAULT_HUMAN_PASSWORD}, must be changed at first login):
    - student, teacher  — full sudo
    - operator          — limited sudo (mywebapp + nginx reload)
    - mywebapp          — system user running the service (no shell)

EOF
}

main "$@"
