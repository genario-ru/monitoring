---
name: update-bootstrap-script
description: Use when changing root-level VPS bootstrap scripts for exporters, systemd units, or firewall rules.
---

# Update Bootstrap Script

1. Inspect the closest script in `scripts/**`.
2. Preserve `set -euo pipefail`.
3. Keep versions, ports, users, and addresses configurable through env defaults.
4. Keep user creation idempotent and systemd unit output readable.
5. Keep UFW rules scoped to `${MONITORING_VPS_IP}`.
6. If adding an exporter, update `.env.example`, `docker-compose.yml`, `victoriametrics/scrape.yml`, dashboards, alerts, and README as needed.
7. Run shell syntax checks when available.

Do not execute bootstrap scripts by default. They install packages, create users, write systemd units, and can change firewall rules.
