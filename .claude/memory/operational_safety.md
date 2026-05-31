---
name: Operational safety
description: Mutating commands and secrets policy for genario-monitoring
type: project
---

## Do Not Run By Default

- `docker compose up`
- `docker compose down`
- `docker compose pull`
- `docker compose restart`
- `docker compose exec`
- destructive Docker volume commands
- `scripts/bootstrap-*.sh`

These operations mutate containers, volumes, services, host packages, systemd units, users, or firewall rules. Run them only when the user explicitly asks for that exact operation in the current task.

## Secrets

Do not commit real `.env` values, SMTP credentials, GlitchTip secrets, IP allowlists, or production tokens.
