#!/usr/bin/env bash
set -euo pipefail

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.9.1}"
NODE_EXPORTER_USER="${NODE_EXPORTER_USER:-node_exporter}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"

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

print_summary() {
  cat <<EOF

Monitoring VPS bootstrap complete.

Installed:
- node_exporter on port ${NODE_EXPORTER_PORT}

Next:
1. Verify locally on the monitoring VPS:
   curl http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics
2. In genario-monitoring env, set:
   MONITORING_IP=<monitoring-ip>
3. Redeploy genario-monitoring.
4. Verify that VictoriaMetrics shows monitoring-node as UP.

Note:
- This script does not add UFW rules automatically.
- If you enable a host firewall on the monitoring VPS later, make sure Docker containers running VictoriaMetrics can still reach port ${NODE_EXPORTER_PORT} on the host.
EOF
}

require_root
install_packages
ensure_system_user "${NODE_EXPORTER_USER}"
install_node_exporter
write_node_exporter_service
enable_service node_exporter.service
print_summary
