---
name: add-scrape-target
description: Use when adding or changing VictoriaMetrics scrape targets in genario-monitoring.
---

# Add Scrape Target

1. Inspect existing jobs in `victoriametrics/scrape.yml`.
2. Choose a stable `job_name`; avoid renaming existing jobs unless requested.
3. Add required host/domain/port variables to `.env.example`.
4. Pass new variables to the `victoriametrics` service in `docker-compose.yml` when the scrape config needs them.
5. Add the scrape job in `victoriametrics/scrape.yml`.
6. Update dashboards and alert rules that should cover the new target.
7. Update README coverage, firewall, and acceptance checklists.
8. Validate with `docker compose --env-file .env.example config`.

Do not expose exporter ports publicly or run mutating Docker commands by default.
