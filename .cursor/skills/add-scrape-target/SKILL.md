---
name: add-scrape-target
description: Adds or changes a VictoriaMetrics scrape target with required env, dashboard, alert, and documentation updates.
---

# Add Scrape Target

## Workflow

1. Inspect existing jobs in `victoriametrics/scrape.yml`.
2. Pick a stable `job_name`; avoid renaming existing jobs unless requested.
3. Add `.env.example` variables for any new host/domain/port.
4. Pass those variables into `victoriametrics.environment` in `docker-compose.yml` if the scrape config uses them.
5. Add the target to `victoriametrics/scrape.yml`.
6. Update dashboards under `grafana/dashboards/**` when the new target needs visibility.
7. Update `vmalert/rules/alerts.yml` when the new target needs alerts.
8. Update README coverage, firewall, and acceptance checklists.
9. Validate with `docker compose --env-file .env.example config`.

## Safety

- Do not expose exporter ports publicly.
- Do not run `docker compose up/down/pull/restart`.
- Do not commit real target IPs unless they are intentional public examples.
