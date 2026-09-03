# AGENTS.md - Genario Monitoring

This is the canonical working guide for coding agents in `genario-monitoring`.
Tool-specific files may add workflow detail, but they must not contradict this
file.

## Project Snapshot

- Purpose: self-hosted production monitoring and error tracking for Genario.
- Runtime: Docker Compose stack deployed through Dokploy.
- Metrics store and scraper: VictoriaMetrics.
- Rule engine: vmalert.
- Alert routing: Alertmanager with email receiver.
- Dashboards: Grafana file provisioning.
- Error tracking: GlitchTip with internal PostgreSQL and Valkey containers.
- Host/exporter setup: shell bootstrap scripts for backend, frontend,
  monitoring, and DB VPS hosts.
- Deployment trigger: GitHub Actions calls Dokploy on pushes to `main`.

## Source Of Truth

Read these before making non-trivial changes:

- `docker-compose.yml` for services, volumes, networks, exposed ports, env usage,
  and mounted config paths.
- `.env.example` for every required runtime variable.
- `victoriametrics/scrape.yml` for scrape jobs and job names.
- `vmalert/rules/alerts.yml` for alert expressions and labels.
- `alertmanager/alertmanager.yml.tpl` for notification routing and template
  placeholders.
- `grafana/provisioning/**` for datasource and dashboard folder provisioning.
- `grafana/dashboards/**` for committed dashboard JSON.
- `scripts/bootstrap-*.sh` for host exporter installation and firewall setup.
- `.github/workflows/deploy.yaml` for Dokploy deployment trigger.

If documentation disagrees with code/config, trust code/config first, then update
the documentation in the same change.

## Architecture

```text
Grafana -> VictoriaMetrics datasource
VictoriaMetrics -> scrape.yml -> backend / node_exporter / postgres_exporter / redis_exporter
vmalert -> VictoriaMetrics queries -> Alertmanager
Alertmanager -> rendered email config -> SMTP/email receiver
GlitchTip -> internal PostgreSQL + Valkey + uploads volume
```

Grafana and GlitchTip are exposed through Dokploy domains. VictoriaMetrics,
vmalert, Alertmanager, GlitchTip PostgreSQL, and GlitchTip Valkey are internal
compose services and must not be published directly to the public internet.

## Repository Layout

| Path                                | Purpose                                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------------------------ |
| `docker-compose.yml`                | Compose stack for Grafana, VictoriaMetrics, vmalert, Alertmanager, GlitchTip, PostgreSQL, Valkey |
| `.env.example`                      | Required runtime variables and image tags                                                        |
| `victoriametrics/scrape.yml`        | VictoriaMetrics scrape jobs and target templates                                                 |
| `vmalert/rules/alerts.yml`          | vmalert alert rules                                                                              |
| `alertmanager/alertmanager.yml.tpl` | Alertmanager config template rendered at container startup                                       |
| `grafana/provisioning/datasources`  | Grafana datasource provisioning                                                                  |
| `grafana/provisioning/dashboards`   | Grafana file dashboard provisioning                                                              |
| `grafana/dashboards`                | Committed Grafana dashboard JSON grouped by folder                                               |
| `scripts`                           | Root-only VPS bootstrap scripts for exporters and firewall rules                                 |
| `.github/workflows/deploy.yaml`     | Dokploy deployment workflow                                                                      |

## Current Scrape Jobs

Keep these job names stable unless dashboards and alerts are updated together:

- `backend` - backend `/metrics` over HTTPS.
- `backend-node` - node_exporter on backend VPS.
- `frontend-node` - node_exporter on frontend VPS.
- `monitoring-node` - node_exporter on monitoring VPS.
- `db-node` - node_exporter on DB VPS.
- `postgres` - postgres_exporter on DB VPS.
- `redis` - redis_exporter on DB VPS.

## Safety Rules

- Do not commit real `.env` values, passwords, SMTP credentials, IP allowlists,
  or GlitchTip secrets.
- Do not run `docker compose up`, `docker compose down`, `docker compose pull`,
  `docker compose restart`, `docker compose exec`, or destructive Docker volume
  commands unless the user explicitly asks for that exact operation in the
  current task.
- Do not run `scripts/bootstrap-*.sh` unless the user explicitly asks for that
  exact operation in the current task. These scripts install packages, write
  systemd units, create users, and can change firewall rules on a VPS.
- Do not publish VictoriaMetrics, vmalert, Alertmanager, exporter ports, or
  GlitchTip internal PostgreSQL/Valkey services to the public internet.
- Keep exporter ports allowlisted to the monitoring VPS IP when firewall rules
  are involved.
- Treat Grafana dashboard JSON as source-controlled config: preserve stable
  `uid`, folder path, datasource UID `victoriametrics`, and meaningful panel
  titles.
- Keep Alertmanager secrets as template placeholders in git and env values in
  real `.env` only.

## Allowed Default Validation

Agents may run read-only/local validation by default:

```bash
docker compose --env-file .env.example config
```

Also validate edited JSON/YAML/shell files with available local tooling. Do not
start containers or mutate remote hosts as part of default validation.

## Change Workflows

### Add Or Change A Scrape Target

1. Update `.env.example` if a new host, port, or domain variable is needed.
2. Update `docker-compose.yml` only if VictoriaMetrics needs the env variable at
   runtime.
3. Update `victoriametrics/scrape.yml` with a stable `job_name`.
4. Update Grafana dashboards and vmalert rules that should use the new job.
5. Update `README.md` acceptance and firewall checklists.
6. Validate with `docker compose --env-file .env.example config`.

### Add Or Change An Alert

1. Keep rules in `vmalert/rules/alerts.yml`.
2. Use existing labels/job names. If a new job name is introduced, update
   dashboards and README together.
3. Add `for:` to avoid noisy instant alerts unless the alert is intentionally
   immediate.
4. Add `summary` and `description` annotations.
5. Remember: vmalert evaluates rules; Alertmanager only groups/routes fired
   alerts.
6. Validate compose config and YAML syntax. If possible, test through a safe
   simulated outage only when the user explicitly asks.

### Add Or Change A Grafana Dashboard

1. Place JSON under the matching folder:
   - `grafana/dashboards/backend`
   - `grafana/dashboards/frontend`
   - `grafana/dashboards/db`
   - `grafana/dashboards/monitoring`
2. Make sure `grafana/provisioning/dashboards/dashboards.yml` includes the
   folder path.
3. Use datasource UID `victoriametrics`.
4. Keep dashboard `uid` stable and unique.
5. Keep panel queries aligned with current scrape job names and metric names.
6. Validate dashboard JSON parseability before finishing.

### Update Bootstrap Scripts

1. Treat scripts as destructive/root-level infrastructure code.
2. Preserve `set -euo pipefail`.
3. Keep scripts idempotent where possible: create users only when missing,
   overwrite known systemd units deliberately, and print clear next steps.
4. Keep firewall rules scoped to `${MONITORING_IP}`.
5. Do not run scripts by default. Review them statically and report that runtime
   VPS validation was not performed unless the user explicitly asked.

## Pull Requests

- Agents may create a feature branch and open a pull request for owner review.
- Use branch names like `agent/TASK-XXX-short-slug` when working from orchestrator tasks.
- Never force-push to `main`.
- Owner merges after review; do not merge your own PR unless explicitly asked.

## Completion Checklist

Before finishing, report:

- files changed;
- service/job/dashboard/script references inspected;
- secrets/firewall/public-port impact;
- validation commands run and results;
- validation skipped, especially any Docker startup or VPS script execution,
  with the reason.
