# Validate Monitoring Change

Run safe validation for monitoring changes.

## Default Checks

```bash
docker compose --env-file .env.example config
```

Also parse changed JSON dashboards and run Markdown/YAML/shell syntax checks when available.

## Do Not Run By Default

- `docker compose up`
- `docker compose down`
- `docker compose pull`
- `docker compose restart`
- `docker compose exec`
- destructive Docker volume commands
- `scripts/bootstrap-*.sh`

Report skipped runtime checks explicitly.
