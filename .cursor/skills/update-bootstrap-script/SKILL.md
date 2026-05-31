---
name: update-bootstrap-script
description: Updates root-level VPS bootstrap scripts with static safety checks and matching monitoring config changes.
---

# Update Bootstrap Script

## Workflow

1. Inspect the closest existing bootstrap script in `scripts/**`.
2. Preserve `set -euo pipefail`.
3. Keep versions and ports configurable through env defaults.
4. Keep user creation idempotent.
5. Keep systemd unit writes deliberate and readable.
6. Keep UFW rules scoped to `${MONITORING_VPS_IP}`.
7. If adding an exporter, update:
   - `.env.example`;
   - `docker-compose.yml` if VictoriaMetrics needs new env;
   - `victoriametrics/scrape.yml`;
   - dashboards/alerts when useful;
   - README manual/bootstrap/firewall/acceptance docs.
8. Run shell syntax checks when available. Do not execute the script by default.

## Safety

- These scripts install packages, create users, write systemd units, and may change firewall rules.
- Only run them when the user explicitly asks for that exact operation.
