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

POSTGRES_ADMIN_SYSTEM_USER="${POSTGRES_ADMIN_SYSTEM_USER:-postgres}"
POSTGRES_ADMIN_DB_HOST="${POSTGRES_ADMIN_DB_HOST:-127.0.0.1}"
POSTGRES_ADMIN_DB_PORT="${POSTGRES_ADMIN_DB_PORT:-5432}"
POSTGRES_ADMIN_DB_NAME="${POSTGRES_ADMIN_DB_NAME:-postgres}"
POSTGRES_ADMIN_DB_USER="${POSTGRES_ADMIN_DB_USER:-postgres}"
POSTGRES_ADMIN_DB_PASSWORD="${POSTGRES_ADMIN_DB_PASSWORD:-}"
POSTGRES_SKIP_ROLE_SETUP="${POSTGRES_SKIP_ROLE_SETUP:-false}"

REDIS_EXPORTER_REDIS_ADDR="${REDIS_EXPORTER_REDIS_ADDR:-redis://127.0.0.1:6379}"
REDIS_EXPORTER_REDIS_PASSWORD="${REDIS_EXPORTER_REDIS_PASSWORD:-}"

STAGE_DB_ENABLED="${STAGE_DB_ENABLED:-false}"

POSTGRES_STAGE_EXPORTER_PORT="${POSTGRES_STAGE_EXPORTER_PORT:-9188}"
POSTGRES_STAGE_DB_HOST="${POSTGRES_STAGE_DB_HOST:-127.0.0.1}"
POSTGRES_STAGE_DB_PORT="${POSTGRES_STAGE_DB_PORT:-5433}"
POSTGRES_STAGE_DB_NAME="${POSTGRES_STAGE_DB_NAME:-postgres}"
POSTGRES_STAGE_EXPORTER_DB_PASSWORD="${POSTGRES_STAGE_EXPORTER_DB_PASSWORD:-${POSTGRES_EXPORTER_DB_PASSWORD}}"

REDIS_STAGE_EXPORTER_PORT="${REDIS_STAGE_EXPORTER_PORT:-9122}"
REDIS_STAGE_EXPORTER_REDIS_ADDR="${REDIS_STAGE_EXPORTER_REDIS_ADDR:-redis://127.0.0.1:6380}"
REDIS_STAGE_EXPORTER_REDIS_PASSWORD="${REDIS_STAGE_EXPORTER_REDIS_PASSWORD:-${REDIS_EXPORTER_REDIS_PASSWORD}}"

MONITORING_IP="${MONITORING_IP:-}"

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

run_psql_as_admin() {
  local sql="$1"
  local db_port="$2"

  if id "${POSTGRES_ADMIN_SYSTEM_USER}" >/dev/null 2>&1; then
    sudo -u "${POSTGRES_ADMIN_SYSTEM_USER}" psql -p "${db_port}" -d "${POSTGRES_ADMIN_DB_NAME}" -v ON_ERROR_STOP=1 <<EOF
${sql}
EOF
    return
  fi

  PGPASSWORD="${POSTGRES_ADMIN_DB_PASSWORD}" \
    psql \
      -h "${POSTGRES_ADMIN_DB_HOST}" \
      -p "${db_port}" \
      -U "${POSTGRES_ADMIN_DB_USER}" \
      -d "${POSTGRES_ADMIN_DB_NAME}" \
      -v ON_ERROR_STOP=1 <<EOF
${sql}
EOF
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
  local db_port="$1"
  local exporter_password="$2"

  if [[ "${POSTGRES_SKIP_ROLE_SETUP}" == "true" ]]; then
    echo "Skipping PostgreSQL role setup because POSTGRES_SKIP_ROLE_SETUP=true."
    return
  fi

  local escaped_password
  escaped_password="${exporter_password//\'/\'\'}"
  local role_sql

  role_sql="$(cat <<EOF
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
)"

  run_psql_as_admin "${role_sql}" "${db_port}"
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
  local service_name="$1"
  local description="$2"
  local db_host="$3"
  local db_port="$4"
  local db_name="$5"
  local exporter_password="$6"
  local exporter_port="$7"

  cat >"/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=${description}
After=network-online.target
Wants=network-online.target

[Service]
User=${POSTGRES_EXPORTER_USER}
Group=${POSTGRES_EXPORTER_USER}
Environment="DATA_SOURCE_NAME=postgresql://${POSTGRES_EXPORTER_DB_USER}:${exporter_password}@${db_host}:${db_port}/${db_name}?sslmode=${POSTGRES_SSLMODE}"
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:${exporter_port}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

write_redis_exporter_service() {
  local service_name="$1"
  local description="$2"
  local exporter_port="$3"
  local redis_addr="$4"
  local redis_password="$5"
  local redis_password_flag=""

  if [[ -n "${redis_password}" ]]; then
    redis_password_flag=" --redis.password=${redis_password}"
  fi

  cat >"/etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=${description}
After=network-online.target
Wants=network-online.target

[Service]
User=${REDIS_EXPORTER_USER}
Group=${REDIS_EXPORTER_USER}
ExecStart=/usr/local/bin/redis_exporter --web.listen-address=:${exporter_port} --redis.addr=${redis_addr}${redis_password_flag}
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

  if [[ "${STAGE_DB_ENABLED}" == "true" ]]; then
    systemctl enable --now postgres_exporter_stage.service
    systemctl enable --now redis_exporter_stage.service
  fi
}

configure_ufw() {
  if [[ -z "${MONITORING_IP}" ]]; then
    echo "Skipping UFW rules: MONITORING_IP is not set."
    return
  fi

  if ! command -v ufw >/dev/null 2>&1; then
    echo "Skipping UFW rules: ufw is not installed."
    return
  fi

  ufw allow from "${MONITORING_IP}" to any port "${NODE_EXPORTER_PORT}" proto tcp
  ufw allow from "${MONITORING_IP}" to any port "${POSTGRES_EXPORTER_PORT}" proto tcp
  ufw allow from "${MONITORING_IP}" to any port "${REDIS_EXPORTER_PORT}" proto tcp

  if [[ "${STAGE_DB_ENABLED}" == "true" ]]; then
    ufw allow from "${MONITORING_IP}" to any port "${POSTGRES_STAGE_EXPORTER_PORT}" proto tcp
    ufw allow from "${MONITORING_IP}" to any port "${REDIS_STAGE_EXPORTER_PORT}" proto tcp
  fi
}

print_summary() {
  local stage_installed=""
  local stage_verify_local=""
  local stage_verify_remote=""

  if [[ "${STAGE_DB_ENABLED}" == "true" ]]; then
    stage_installed="
- postgres_exporter_stage on port ${POSTGRES_STAGE_EXPORTER_PORT} (PostgreSQL at ${POSTGRES_STAGE_DB_HOST}:${POSTGRES_STAGE_DB_PORT})
- redis_exporter_stage on port ${REDIS_STAGE_EXPORTER_PORT} (Redis at ${REDIS_STAGE_EXPORTER_REDIS_ADDR})"
    stage_verify_local="
- curl http://127.0.0.1:${POSTGRES_STAGE_EXPORTER_PORT}/metrics
- curl http://127.0.0.1:${REDIS_STAGE_EXPORTER_PORT}/metrics"
    stage_verify_remote="
- curl http://<db-host>:${POSTGRES_STAGE_EXPORTER_PORT}/metrics
- curl http://<db-host>:${REDIS_STAGE_EXPORTER_PORT}/metrics"
  fi

  cat <<EOF

DB VPS bootstrap complete.

Installed:
- node_exporter on port ${NODE_EXPORTER_PORT}
- postgres_exporter on port ${POSTGRES_EXPORTER_PORT}
- redis_exporter on port ${REDIS_EXPORTER_PORT}${stage_installed}

Verify locally:
- curl http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics
- curl http://127.0.0.1:${POSTGRES_EXPORTER_PORT}/metrics
- curl http://127.0.0.1:${REDIS_EXPORTER_PORT}/metrics${stage_verify_local}

Verify from monitoring VPS:
- curl http://<db-host>:${NODE_EXPORTER_PORT}/metrics
- curl http://<db-host>:${POSTGRES_EXPORTER_PORT}/metrics
- curl http://<db-host>:${REDIS_EXPORTER_PORT}/metrics${stage_verify_remote}

Notes:
- If the server has no local Unix user named "${POSTGRES_ADMIN_SYSTEM_USER}", provide PostgreSQL admin credentials:
  POSTGRES_ADMIN_DB_USER=<admin-user>
  POSTGRES_ADMIN_DB_PASSWORD=<admin-password>
- If the exporter role already exists and you do not want the script to manage it, set:
  POSTGRES_SKIP_ROLE_SETUP=true
- If a stage PostgreSQL/Redis instance also runs on this VPS, set:
  STAGE_DB_ENABLED=true
  and optionally override POSTGRES_STAGE_DB_PORT, REDIS_STAGE_EXPORTER_REDIS_ADDR,
  POSTGRES_STAGE_EXPORTER_PORT, REDIS_STAGE_EXPORTER_PORT.
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
create_postgres_monitoring_user "${POSTGRES_ADMIN_DB_PORT}" "${POSTGRES_EXPORTER_DB_PASSWORD}"
write_node_exporter_service
write_postgres_exporter_service \
  "postgres_exporter" \
  "PostgreSQL Exporter" \
  "${POSTGRES_EXPORTER_DB_HOST}" \
  "${POSTGRES_EXPORTER_DB_PORT}" \
  "${POSTGRES_EXPORTER_DB_NAME}" \
  "${POSTGRES_EXPORTER_DB_PASSWORD}" \
  "${POSTGRES_EXPORTER_PORT}"
write_redis_exporter_service \
  "redis_exporter" \
  "Redis Exporter" \
  "${REDIS_EXPORTER_PORT}" \
  "${REDIS_EXPORTER_REDIS_ADDR}" \
  "${REDIS_EXPORTER_REDIS_PASSWORD}"

if [[ "${STAGE_DB_ENABLED}" == "true" ]]; then
  create_postgres_monitoring_user "${POSTGRES_STAGE_DB_PORT}" "${POSTGRES_STAGE_EXPORTER_DB_PASSWORD}"
  write_postgres_exporter_service \
    "postgres_exporter_stage" \
    "PostgreSQL Exporter (stage)" \
    "${POSTGRES_STAGE_DB_HOST}" \
    "${POSTGRES_STAGE_DB_PORT}" \
    "${POSTGRES_STAGE_DB_NAME}" \
    "${POSTGRES_STAGE_EXPORTER_DB_PASSWORD}" \
    "${POSTGRES_STAGE_EXPORTER_PORT}"
  write_redis_exporter_service \
    "redis_exporter_stage" \
    "Redis Exporter (stage)" \
    "${REDIS_STAGE_EXPORTER_PORT}" \
    "${REDIS_STAGE_EXPORTER_REDIS_ADDR}" \
    "${REDIS_STAGE_EXPORTER_REDIS_PASSWORD}"
fi

enable_services
configure_ufw
print_summary
