@AGENTS.md

# Claude Code Notes

Use `AGENTS.md` as the shared project contract. This repository is
infrastructure-heavy, so avoid mutating real hosts or Docker state unless the
user explicitly asks for that exact operation.

## Default Task Flow

1. Identify the changed area: compose/env, scrape target, alert rule, Grafana
   dashboard, bootstrap script, README, or deployment workflow.
2. Read the matching local references before editing:
   - nearby scrape jobs in `victoriametrics/scrape.yml`;
   - nearby alerts in `vmalert/rules/alerts.yml`;
   - similar dashboards in `grafana/dashboards/**`;
   - related bootstrap scripts in `scripts/**`.
3. Make the smallest config change that satisfies the request.
4. Update dependent files together:
   - new env variable -> `.env.example` and `docker-compose.yml`;
   - new scrape job -> dashboards, alerts, README;
   - new dashboard folder -> provisioning file;
   - new exporter -> bootstrap script, scrape config, firewall docs.
5. Validate with read-only/local commands. Do not start containers or run VPS
   bootstrap scripts unless explicitly requested.

## Claude-Specific Guidance

- Prefer `.claude/commands/**` for repeatable workflows.
- Use `.claude/agents/**` for focused monitoring/config review.
- Keep project memory aligned with `AGENTS.md`.
- Do not commit local Claude permissions or secrets.
