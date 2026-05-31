---
name: add-grafana-dashboard
description: Adds or updates Grafana dashboard JSON and provisioning safely.
---

# Add Grafana Dashboard

## Workflow

1. Inspect existing dashboards in the target folder under `grafana/dashboards/**`.
2. Choose the correct folder: `backend`, `frontend`, `db`, or `monitoring`.
3. Add or update dashboard JSON with stable unique `uid`.
4. Use datasource UID `victoriametrics`.
5. Keep panel queries aligned with current scrape `job_name` values and metrics.
6. If adding a new folder, update `grafana/provisioning/dashboards/dashboards.yml`.
7. Update README acceptance checklist when the dashboard becomes part of expected operations.
8. Parse changed JSON files before finishing.

## Safety

- Do not use live-only Grafana edits as the source of truth unless exported JSON is committed.
- Do not change dashboard UIDs casually; links and provisioning depend on them.
