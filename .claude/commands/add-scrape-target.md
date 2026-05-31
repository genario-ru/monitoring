# Add Scrape Target

Add or change a VictoriaMetrics scrape target.

## Arguments

`$ARGUMENTS` - target description, host/domain, exporter type, and expected job name.

## Workflow

1. Inspect existing jobs in `victoriametrics/scrape.yml`.
2. Add required variables to `.env.example`.
3. Pass variables to `victoriametrics.environment` in `docker-compose.yml` when used by `scrape.yml`.
4. Add the scrape job with a stable `job_name`.
5. Update Grafana dashboards and vmalert alerts when the target should be visible or alertable.
6. Update README coverage, firewall, and acceptance checklists.
7. Run `docker compose --env-file .env.example config`.

Do not run mutating Docker commands or bootstrap scripts unless explicitly requested.
