---
name: validate-monitoring-change
description: Use before finishing monitoring changes to choose safe validation without mutating infrastructure.
---

# Validate Monitoring Change

Safe default checks:

- Compose/env: `docker compose --env-file .env.example config`.
- Dashboard JSON: parse changed `.json` files.
- YAML/template configs: parse with available tooling or inspect indentation/placeholders.
- Alert rules: verify metric names, job names, `for:`, `summary`, and `description`.
- Bootstrap scripts: static review and shell syntax checks when available.
- Docs/AI rules only: formatting and stale-reference search.

Do not run `docker compose up/down/pull/restart/exec`, destructive Docker volume commands, or `scripts/bootstrap-*.sh` unless explicitly requested.
