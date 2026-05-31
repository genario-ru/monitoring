---
name: validate-monitoring-change
description: Selects safe validation for monitoring repository changes without mutating Docker or VPS state.
---

# Validate Monitoring Change

## Matrix

- Compose/env: `docker compose --env-file .env.example config`.
- Dashboard JSON: parse changed `.json` files.
- YAML/template configs: parse with available tooling; otherwise inspect indentation and placeholders.
- Alert rules: verify metric names, job names, `for:`, `summary`, and `description`.
- Bootstrap scripts: static review and shell syntax checks when available.
- Docs/AI rules only: formatting and stale-reference search.

## Do Not Run By Default

- `docker compose up`
- `docker compose down`
- `docker compose pull`
- `docker compose restart`
- `docker compose exec`
- Docker volume deletion
- `scripts/bootstrap-*.sh`

Report skipped runtime checks explicitly.
