# Add Grafana Dashboard

Add or update Grafana dashboard JSON.

## Arguments

`$ARGUMENTS` - dashboard purpose, folder, metrics, and panels.

## Workflow

1. Inspect existing dashboards in the target folder under `grafana/dashboards/**`.
2. Add or update JSON under `backend`, `frontend`, `db`, or `monitoring`.
3. Use datasource UID `victoriametrics`.
4. Keep dashboard `uid` stable and unique.
5. Keep PromQL aligned with current scrape jobs and metric names.
6. Update provisioning if adding a new dashboard folder.
7. Update README acceptance checklist when applicable.
8. Parse changed JSON files before finishing.
