# Update Bootstrap Script

Update a root-level VPS bootstrap script.

## Arguments

`$ARGUMENTS` - script name and desired exporter/systemd/firewall behavior.

## Workflow

1. Inspect the closest existing script in `scripts/**`.
2. Preserve `set -euo pipefail`.
3. Keep versions, ports, and users configurable through env defaults.
4. Keep system user creation idempotent.
5. Keep UFW rules scoped to `${MONITORING_VPS_IP}`.
6. If adding an exporter, update scrape config, env, dashboards, alerts, and README.
7. Run shell syntax checks when available.

Do not execute bootstrap scripts unless explicitly requested.
