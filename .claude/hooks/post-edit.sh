#!/usr/bin/env bash
# Post-edit hook: prints non-blocking reminders after monitoring config edits.

INPUT=$(cat)

FILE=$(printf '%s' "$INPUT" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit

tool_input = data.get("tool_input", {}) or {}
file_path = tool_input.get("file_path") or ""
print(file_path)
' 2>/dev/null)

case "$FILE" in
  */docker-compose.yml|*/.env.example)
    echo "[hook] Compose/env changed: run docker compose --env-file .env.example config; do not start containers by default."
    ;;
  */victoriametrics/scrape.yml)
    echo "[hook] Scrape config changed: verify env variables, dashboards, alerts, firewall docs, and acceptance checklist."
    ;;
  */vmalert/rules/*.yml)
    echo "[hook] Alert rules changed: verify job names, metric names, for duration, summary, and description."
    ;;
  */alertmanager/*.yml.tpl)
    echo "[hook] Alertmanager template changed: keep secrets as placeholders and validate rendered config assumptions."
    ;;
  */grafana/dashboards/*.json|*/grafana/dashboards/*/*.json)
    echo "[hook] Dashboard changed: parse JSON and verify datasource UID victoriametrics plus current job names."
    ;;
  */grafana/provisioning/*.yml|*/grafana/provisioning/*/*.yml)
    echo "[hook] Grafana provisioning changed: verify mounted paths and dashboard folders."
    ;;
  */scripts/*.sh)
    echo "[hook] Bootstrap script changed: do not execute by default; verify set -euo pipefail, systemd, and firewall scope."
    ;;
esac

exit 0
