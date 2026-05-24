#!/usr/bin/env bash
set -euo pipefail

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.9.1}"
NODE_EXPORTER_USER="${NODE_EXPORTER_USER:-node_exporter}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
MONITORING_VPS_IP="${MONITORING_VPS_IP:-}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root: sudo bash $0" >&2
    exit 1
  fi
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y curl tar
}

ensure_system_user() {
  local user="$1"

  if ! id "${user}" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "${user}"
  fi
}

install_node_exporter() {
  local archive="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
  local url="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${archive}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -fsSL "${url}" -o "${tmp_dir}/${archive}"
  tar -xzf "${tmp_dir}/${archive}" -C "${tmp_dir}"
  install -m 0755 "${tmp_dir}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/node_exporter
  rm -rf "${tmp_dir}"
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

enable_service() {
  local service="$1"
  systemctl daemon-reload
  systemctl enable --now "${service}"
}

configure_ufw() {
  if [[ -z "${MONITORING_VPS_IP}" ]]; then
    echo "Skipping UFW rule: MONITORING_VPS_IP is not set."
    return
  fi

  if ! command -v ufw >/dev/null 2>&1; then
    echo "Skipping UFW rule: ufw is not installed."
    return
  fi

  ufw allow from "${MONITORING_VPS_IP}" to any port "${NODE_EXPORTER_PORT}" proto tcp
}

print_summary() {
  cat <<EOF

Backend VPS bootstrap complete.

Installed:
- node_exporter on port ${NODE_EXPORTER_PORT}

Next:
1. In genario-backend runtime env, set:
   METRICS_ALLOWED_IPS=${MONITORING_VPS_IP:-<monitoring-vps-ip>}
2. Redeploy genario-backend.
3. Verify locally:
   curl http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics
4. Verify from monitoring VPS:
   curl http://<backend-host>:${NODE_EXPORTER_PORT}/metrics
EOF
}

require_root
install_packages
ensure_system_user "${NODE_EXPORTER_USER}"
install_node_exporter
write_node_exporter_service
enable_service node_exporter.service
configure_ufw
print_summary
