---
name: add-grafana-dashboard
description: Use when adding or updating Grafana dashboard JSON and provisioning.
---

# Add Grafana Dashboard

1. Inspect existing dashboards in the target folder.
2. Place JSON under `grafana/dashboards/backend`, `frontend`, `db`, or `monitoring`.
3. Use stable unique dashboard `uid`.
4. Use datasource UID `victoriametrics`.
5. Keep PromQL aligned with current `job_name` and metric names.
6. Update `grafana/provisioning/dashboards/dashboards.yml` if adding a folder.
7. Update README acceptance checklist when the dashboard becomes part of expected operations.
8. Parse changed JSON files before finishing.

Committed JSON is the source of truth, not uncommitted live Grafana edits.
