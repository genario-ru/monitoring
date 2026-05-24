#!/usr/bin/env bash
set -euo pipefail

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.9.1}"
POSTGRES_EXPORTER_VERSION="${POSTGRES_EXPORTER_VERSION:-0.17.1}"
REDIS_EXPORTER_VERSION="${REDIS_EXPORTER_VERSION:-1.67.0}"

NODE_EXPORTER_USER="${NODE_EXPORTER_USER:-node_exporter}"
POSTGRES_EXPORTER_USER="${POSTGRES_EXPORTER_USER:-postgres_exporter}"
REDIS_EXPORTER_USER="${REDIS_EXPORTER_USER:-redis_exporter}"

NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
POSTGRES_EXPORTER_PORT="${POSTGRES_EXPORTER_PORT:-9187}"
REDIS_EXPORTER_PORT="${REDIS_EXPORTER_PORT:-9121}"

POSTGRES_EXPORTER_DB_HOST="${POSTGRES_EXPORTER_DB_HOST:-127.0.0.1}"
POSTGRES_EXPORTER_DB_PORT="${POSTGRES_EXPORTER_DB_PORT:-5432}"
POSTGRES_EXPORTER_DB_NAME="${POSTGRES_EXPORTER_DB_NAME:-postgres}"
POSTGRES_EXPORTER_DB_USER="${POSTGRES_EXPORTER_DB_USER:-postgres_exporter}"
POSTGRES_EXPORTER_DB_PASSWORD="${POSTGRES_EXPORTER_DB_PASSWORD:-}"
POSTGRES_SSLMODE="${POSTGRES_SSLMODE:-disable}"

REDIS_EXPORTER_REDIS_ADDR="${REDIS_EXPORTER_REDIS_ADDR:-redis://127.0.0.1:6379}"
REDIS_EXPORTER_REDIS_PASSWORD="${REDIS_EXPORTER_REDIS_PASSWORD:-}"

MONITORING_VPS_IP="${MONITORING_VPS_IP:-}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root: sudo bash $0" >&2
    exit 1
  fi
}

require_postgres_password() {
  if [[ -z "${POSTGRES_EXPORTER_DB_PASSWORD}" ]]; then
    echo "POSTGRES_EXPORTER_DB_PASSWORD is required." >&2
    exit 1
  fi
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y curl tar postgresql-client
}

ensure_system_user() {
  local user="$1"

  if ! id "${user}" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "${user}"
  fi
}

download_and_install() {
  local url="$1"
  local archive_name="$2"
  local source_binary_path="$3"
  local destination_binary_path="$4"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -fsSL "${url}" -o "${tmp_dir}/${archive_name}"
  tar -xzf "${tmp_dir}/${archive_name}" -C "${tmp_dir}"
  install -m 0755 "${tmp_dir}/${source_binary_path}" "${destination_binary_path}"
  rm -rf "${tmp_dir}"
}

install_node_exporter() {
  local archive="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
  local url="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${archive}"
  download_and_install \
    "${url}" \
    "${archive}" \
    "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" \
    "/usr/local/bin/node_exporter"
}

install_postgres_exporter() {
  local archive="postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz"
  local url="https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/${archive}"
  download_and_install \
    "${url}" \
    "${archive}" \
    "postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64/postgres_exporter" \
    "/usr/local/bin/postgres_exporter"
}

install_redis_exporter() {
  local archive="redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-amd64.tar.gz"
  local url="https://github.com/oliver006/redis_exporter/releases/download/v${REDIS_EXPORTER_VERSION}/${archive}"
  download_and_install \
    "${url}" \
    "${archive}" \
    "redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-amd64/redis_exporter" \
    "/usr/local/bin/redis_exporter"
}

create_postgres_monitoring_user() {
  local escaped_password
  escaped_password="${POSTGRES_EXPORTER_DB_PASSWORD//\'/\'\'}"

  sudo -u postgres psql <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_EXPORTER_DB_USER}') THEN
    CREATE ROLE ${POSTGRES_EXPORTER_DB_USER} LOGIN PASSWORD '${escaped_password}';
  ELSE
    ALTER ROLE ${POSTGRES_EXPORTER_DB_USER} WITH LOGIN PASSWORD '${escaped_password}';
  END IF;
END
\$\$;
GRANT pg_monitor TO ${POSTGRES_EXPORTER_DB_USER};
EOF
}

write_node_exporter_service() {
  cat >/etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=${NODE_EXPORTER_USER}
Group=${NODE_EXPORTER_USER}
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:${NODE_EXPORTER_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

write_postgres_exporter_service() {
  cat >/etc/systemd/system/postgres_exporter.service <<EOF
[Unit]
Description=PostgreSQL Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=${POSTGRES_EXPORTER_USER}
Group=${POSTGRES_EXPORTER_USER}
Environment="DATA_SOURCE_NAME=postgresql://${POSTGRES_EXPORTER_DB_USER}:${POSTGRES_EXPORTER_DB_PASSWORD}@${POSTGRES_EXPORTER_DB_HOST}:${POSTGRES_EXPORTER_DB_PORT}/${POSTGRES_EXPORTER_DB_NAME}?sslmode=${POSTGRES_SSLMODE}"
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:${POSTGRES_EXPORTER_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

write_redis_exporter_service() {
  local redis_password_flag=""

  if [[ -n "${REDIS_EXPORTER_REDIS_PASSWORD}" ]]; then
    redis_password_flag=" --redis.password=${REDIS_EXPORTER_REDIS_PASSWORD}"
  fi

  cat >/etc/systemd/system/redis_exporter.service <<EOF
[Unit]
Description=Redis Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=${REDIS_EXPORTER_USER}
Group=${REDIS_EXPORTER_USER}
ExecStart=/usr/local/bin/redis_exporter --web.listen-address=:${REDIS_EXPORTER_PORT} --redis.addr=${REDIS_EXPORTER_REDIS_ADDR}${redis_password_flag}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

enable_services() {
  systemctl daemon-reload
  systemctl enable --now node_exporter.service
  systemctl enable --now postgres_exporter.service
  systemctl enable --now redis_exporter.service
}

configure_ufw() {
  if [[ -z "${MONITORING_VPS_IP}" ]]; then
    echo "Skipping UFW rules: MONITORING_VPS_IP is not set."
    return
  fi

  if ! command -v ufw >/dev/null 2>&1; then
    echo "Skipping UFW rules: ufw is not installed."
    return
  fi

  ufw allow from "${MONITORING_VPS_IP}" to any port "${NODE_EXPORTER_PORT}" proto tcp
  ufw allow from "${MONITORING_VPS_IP}" to any port "${POSTGRES_EXPORTER_PORT}" proto tcp
  ufw allow from "${MONITORING_VPS_IP}" to any port "${REDIS_EXPORTER_PORT}" proto tcp
}

print_summary() {
  cat <<EOF

DB VPS bootstrap complete.

Installed:
- node_exporter on port ${NODE_EXPORTER_PORT}
- postgres_exporter on port ${POSTGRES_EXPORTER_PORT}
- redis_exporter on port ${REDIS_EXPORTER_PORT}

Verify locally:
- curl http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics
- curl http://127.0.0.1:${POSTGRES_EXPORTER_PORT}/metrics
- curl http://127.0.0.1:${REDIS_EXPORTER_PORT}/metrics

Verify from monitoring VPS:
- curl http://<db-host>:${NODE_EXPORTER_PORT}/metrics
- curl http://<db-host>:${POSTGRES_EXPORTER_PORT}/metrics
- curl http://<db-host>:${REDIS_EXPORTER_PORT}/metrics
EOF
}

require_root
require_postgres_password
install_packages
ensure_system_user "${NODE_EXPORTER_USER}"
ensure_system_user "${POSTGRES_EXPORTER_USER}"
ensure_system_user "${REDIS_EXPORTER_USER}"
install_node_exporter
install_postgres_exporter
install_redis_exporter
create_postgres_monitoring_user
write_node_exporter_service
write_postgres_exporter_service
write_redis_exporter_service
enable_services
configure_ufw
print_summary
