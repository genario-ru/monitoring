# Monitoring

This repository contains the self-hosted monitoring stack for `genario`:

- `Dokploy Domains` publishes Grafana on `https://grafana.<your-domain>` and GlitchTip on `https://glitchtip.<your-domain>`
- `Grafana` renders dashboards
- `VictoriaMetrics` stores, scrapes, and serves metrics
- `vmalert` evaluates alert rules against `VictoriaMetrics`
- `Alertmanager` routes baseline alerts to `email`
- `GlitchTip` provides self-hosted error tracking with its own PostgreSQL and Valkey dependencies

## Repository layout

- `docker-compose.yml`: monitoring stack definition
- `.env.example`: required runtime variables
- `AGENTS.md`: canonical instructions for AI agents working in this repository
- `.agents/`, `.cursor/`, `.claude/`: tool-specific AI workflows derived from `AGENTS.md`
- `scripts/`: bootstrap scripts for `backend VPS`, `frontend VPS`, `monitoring VPS`, and `db VPS`
- `victoriametrics/`: scrape configuration for `VictoriaMetrics`
- `vmalert/`: alert rules for `vmalert`
- `alertmanager/`: Alertmanager config
- `grafana/provisioning/`: automatic datasource and dashboard provisioning
- `grafana/dashboards/`: file-based dashboards committed to git

## What this repository currently covers

- `backend` scrape targets on `https://<backend-domain>/metrics` and `https://<stage-backend-domain>/metrics`
- `backend-node` scrape target on `http://<backend-vps-ip>:9100/metrics`
- `frontend-node` scrape target on `http://<frontend-vps-ip>:9100/metrics`
- `monitoring-node` scrape target on `http://<monitoring-vps-ip>:9100/metrics`
- `db-node` scrape target on `http://<db-vps-ip>:9100/metrics`
- `postgres` scrape target on `http://<db-vps-ip>:<postgres-exporter-port>/metrics`
- `redis` scrape target on `http://<db-vps-ip>:<redis-exporter-port>/metrics`
- one backend host dashboard
- one backend API dashboard
- one frontend host dashboard
- one monitoring host dashboard
- one PostgreSQL dashboard
- one Redis dashboard
- baseline alert rules for backend, hosts, PostgreSQL, and Redis
- one self-hosted `GlitchTip` deployment for application error tracking

This repository still does **not** include:

- worker metrics
- logs / traces
- HA `VictoriaMetrics` / `vmalert` / `Alertmanager`
- application-side GlitchTip SDK wiring for each service

## Local configuration

1. Copy `.env.example` to `.env`.
2. Set:
   - `GRAFANA_ADMIN_USER`
   - `GRAFANA_ADMIN_PASSWORD`
   - `BACKEND_PRODUCTION_DOMAIN`
   - `BACKEND_STAGE_DOMAIN`
   - `FRONTEND_PRODUCTION_DOMAIN`
   - `MONITORING_IP`
   - `DB_IP`
   - `POSTGRES_EXPORTER_PORT`
   - `REDIS_EXPORTER_PORT`
   - `ALERTMANAGER_EMAIL_FROM`
   - `ALERTMANAGER_EMAIL_TO`
   - `ALERTMANAGER_EMAIL_SMARTHOST`
   - `ALERTMANAGER_EMAIL_AUTH_USERNAME`
   - `ALERTMANAGER_EMAIL_AUTH_PASSWORD`
   - `ALERTMANAGER_EMAIL_REQUIRE_TLS`
   - `GLITCHTIP_DOMAIN`
   - `GLITCHTIP_SECRET_KEY`
   - `GLITCHTIP_DEFAULT_FROM_EMAIL`
   - `GLITCHTIP_EMAIL_URL`
   - `GLITCHTIP_POSTGRES_PASSWORD`
   - `GLITCHTIP_VALKEY_PASSWORD`
3. Keep `VICTORIAMETRICS_RETENTION_MONTHS=1` unless you have a clear reason to retain more metrics.
4. Keep `GLITCHTIP_ENABLE_ADMIN=false`, `GLITCHTIP_ENABLE_OPENAPI=false`, and `GLITCHTIP_ENABLE_MCP=false` unless you explicitly need them.
5. `GLITCHTIP_EMAIL_URL=consolemail://` is acceptable for first boot and testing. For production, replace it with a real SMTP URL so invites, password resets, and notifications leave the container.
6. Keep all Alertmanager and GlitchTip secrets only in the real `.env` on the monitoring VPS; never commit them to git.

## AI agent safety policy

- Agents may run read-only validation such as `docker compose --env-file .env.example config`.
- Agents must not run `docker compose up`, `docker compose down`, `docker compose pull`, `docker compose restart`, `docker compose exec`, destructive Docker volume commands, or `scripts/bootstrap-*.sh` unless the user explicitly asks for that exact operation in the current task.
- Agents must not commit real `.env` values, SMTP credentials, GlitchTip secrets, IP allowlists, or production tokens.
- Infrastructure changes should report which dashboards, alert rules, scrape jobs, env variables, and firewall assumptions were checked.

## Deploy on monitoring VPS

```powershell
Copy-Item .env.example .env
docker compose pull
docker compose up -d
```

After startup:

- configure a Dokploy domain for the `grafana` service on port `3000`
- configure a Dokploy domain for the `glitchtip` service on port `8000`
- open the configured Grafana domain
- log in with `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`
- confirm the `VictoriaMetrics` datasource is healthy
- confirm the `Backend`, `Frontend`, and `DB` dashboard folders are present
- open the configured GlitchTip domain
- create the first GlitchTip user and organization
- if `GLITCHTIP_EMAIL_URL=consolemail://`, use `docker compose logs -f glitchtip` to inspect outbound email output until SMTP is configured

## GlitchTip notes

- The compose stack follows the current GlitchTip Docker installation guidance as of May 25, 2026: one `all_in_one` GlitchTip container plus dedicated PostgreSQL and Valkey containers.
- Database migrations run automatically on `glitchtip` startup; there is no separate `migrate` service in this repository.
- Uploaded artifacts such as sourcemaps are stored in the `glitchtip_uploads` Docker volume.
- The PostgreSQL and Valkey containers are internal-only and stay on the `monitoring` Docker network.

## Bootstrap scripts

You can bootstrap new servers with repo scripts instead of repeating the
manual install steps.

Backend VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/bootstrap-backend-vps.sh -o bootstrap-backend-vps.sh
sudo env MONITORING_IP=<monitoring-ip> bash bootstrap-backend-vps.sh
```

Frontend VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/bootstrap-frontend-vps.sh -o bootstrap-frontend-vps.sh
sudo env MONITORING_IP=<monitoring-ip> bash bootstrap-frontend-vps.sh
```

Monitoring VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/bootstrap-monitoring-vps.sh -o bootstrap-monitoring-vps.sh
sudo bash bootstrap-monitoring-vps.sh
```

DB VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-org>/<your-repo>/main/scripts/bootstrap-db-vps.sh -o bootstrap-db-vps.sh
sudo env MONITORING_IP=<monitoring-ip> POSTGRES_EXPORTER_DB_PASSWORD=<strong-password> POSTGRES_ADMIN_DB_USER=<postgres-admin-user-if-no-local-postgres-user> POSTGRES_ADMIN_DB_PASSWORD=<postgres-admin-password-if-no-local-postgres-user> REDIS_EXPORTER_REDIS_PASSWORD=<redis-password-if-needed> bash bootstrap-db-vps.sh
```

The scripts install exporters, create system users, write `systemd` units,
start services, and optionally add `ufw` rules if `MONITORING_IP` is set.
If the server does not have a local Unix user named `postgres`, the DB bootstrap
script can connect through regular PostgreSQL admin credentials instead.

## Manual work on backend VPS

1. Install `node_exporter` as a `systemd` service.
2. Open port `9100` **only** for the monitoring VPS IP.
3. Set backend env:

```env
METRICS_ALLOWED_IPS=<monitoring-vps-ip>
```

4. Redeploy `genario-backend` after the `/metrics` code changes.
5. Verify that:
   - `curl https://<backend-domain>/metrics` works from the monitoring VPS when `METRICS_ALLOWED_IPS` contains the monitoring VPS public IP
   - `curl https://<stage-backend-domain>/metrics` works from the monitoring VPS when `METRICS_ALLOWED_IPS` contains the monitoring VPS public IP
   - VictoriaMetrics shows `backend` and `backend-node` as `UP`

Example `node_exporter` service:

```ini
[Unit]
Description=Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Manual work on db VPS

1. Install `node_exporter` as a `systemd` service.
2. Open port `9100` **only** for the monitoring VPS IP.
3. Create a dedicated PostgreSQL monitoring user:

```sql
CREATE USER postgres_exporter WITH PASSWORD 'change-me';
GRANT pg_monitor TO postgres_exporter;
```

4. Install `postgres_exporter` as a `systemd` service.
5. Install `redis_exporter` as a `systemd` service.
6. Open ports `9187` and `9121` **only** for the monitoring VPS IP.
7. Verify that VictoriaMetrics shows `db-node`, `postgres`, and `redis` as `UP`.

Example `postgres_exporter` DSN:

```env
DATA_SOURCE_NAME=postgresql://postgres_exporter:change-me@127.0.0.1:5432/postgres?sslmode=disable
```

Example `postgres_exporter` service:

```ini
[Unit]
Description=PostgreSQL Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Environment="DATA_SOURCE_NAME=postgresql://postgres_exporter:change-me@127.0.0.1:5432/postgres?sslmode=disable"
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:9187
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Example `redis_exporter` command:

```powershell
/usr/local/bin/redis_exporter --web.listen-address=:9121 --redis.addr=redis://127.0.0.1:6379
```

If Redis requires auth, add:

```powershell
--redis.password=<redis-password>
```

Example `redis_exporter` service:

```ini
[Unit]
Description=Redis Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=redis_exporter
Group=redis_exporter
ExecStart=/usr/local/bin/redis_exporter --web.listen-address=:9121 --redis.addr=redis://127.0.0.1:6379
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Manual work on frontend VPS

1. Install `node_exporter` as a `systemd` service.
2. Open port `9100` **only** for the monitoring VPS IP.
3. Verify that VictoriaMetrics shows `frontend-node` as `UP`.

The bootstrap script already covers this setup for a fresh VPS:

```bash
sudo env MONITORING_IP=<monitoring-ip> bash bootstrap-frontend-vps.sh
```

## Manual work on monitoring VPS

1. Install `node_exporter` as a `systemd` service.
2. Set `MONITORING_IP` in `genario-monitoring` runtime env.
3. Redeploy `genario-monitoring`.
4. Verify that VictoriaMetrics shows `monitoring-node` as `UP`.
5. If you later enable a host firewall on the monitoring VPS, make sure Docker containers running the monitoring stack can still reach port `9100` on the host.

The bootstrap script already covers the `node_exporter` setup:

```bash
sudo bash bootstrap-monitoring-vps.sh
```

## Firewall checklist

- allow `monitoring VPS -> backend HTTPS domain : 443`
- allow `monitoring VPS -> backend VPS : 9100`
- allow `monitoring VPS -> frontend VPS : 9100`
- allow `monitoring VPS -> db VPS : 9100`
- allow `monitoring VPS -> db VPS : 9187`
- allow `monitoring VPS -> db VPS : 9121`
- do **not** publish VictoriaMetrics, `vmalert`, or Alertmanager to the public internet
- do **not** publish custom `80/443` ports from this compose stack; Dokploy already owns ingress on the server

## Alerts

- All baseline alerts go to `email`.
- Routing is intentionally simple in this phase: no severity splitting yet.
- Baseline thresholds in alert rules are starting defaults only.
- Revisit thresholds after several days of production observation.
- Required env for alerting:
  - `ALERTMANAGER_EMAIL_FROM`
  - `ALERTMANAGER_EMAIL_TO`
  - `ALERTMANAGER_EMAIL_SMARTHOST`
  - `ALERTMANAGER_EMAIL_AUTH_USERNAME`
  - `ALERTMANAGER_EMAIL_AUTH_PASSWORD`
  - `ALERTMANAGER_EMAIL_REQUIRE_TLS`
- `Alertmanager` renders `/etc/alertmanager/alertmanager.yml.tpl` to `/tmp/alertmanager.yml` at container startup, then starts the real binary with that rendered config.
- `vmalert` is the rule engine. `Alertmanager` only receives already-fired alerts and handles grouping and delivery.

## Alerting checks

After deploy:

- `docker compose ps` should show `alertmanager` as `Up` with no restart loop.
- Alertmanager logs must not contain `unexpected /bin/sh`.
- `vmalert` must keep `-notifier.url=http://alertmanager:9093` healthy.

End-to-end smoke test:

1. Temporarily stop `redis_exporter` on the db VPS.
2. Wait for the `RedisDown` alert to fire.
3. Confirm the alert appears in `vmalert`.
4. Confirm the alert appears in `Alertmanager`.
5. Confirm the notification arrives in `email`.
6. Start `redis_exporter` again and verify resolved notification delivery.

Repeat the same flow with `postgres_exporter` and `PostgresDown`.

## Acceptance checklist

- `https://grafana.<domain>` is reachable over `HTTPS`
- `https://glitchtip.<domain>` is reachable over `HTTPS`
- Grafana requires login
- GlitchTip shows the setup/login screen and can create the first organization
- `backend` has both `production` and `stage` targets `UP` in VictoriaMetrics
- `backend-node`, `frontend-node`, `monitoring-node`, `db-node`, `postgres`, and `redis` are `UP` in VictoriaMetrics
- `Backend / Host Overview` shows CPU, memory, disk, load, network, uptime for the backend VPS
- `Frontend / Host Overview` shows CPU, memory, disk, load, network, uptime for the frontend VPS
- `Monitoring / Host Overview` shows CPU, memory, disk, load, network, uptime for the monitoring VPS
- `Backend Overview` shows request rate, response classes, latency, in-flight requests, memory, CPU, uptime for the selected backend environment
- `Backend / API Endpoints` lets you switch between `production` and `stage` on the same dashboard
- `Postgres Overview` shows exporter health, DB health, connections, transaction rate, size, deadlocks, checkpoint pressure
- `Redis Overview` shows exporter health, Redis health, memory usage, clients, ops/sec, evictions, rejected connections, persistence health
- `/metrics` on the backend is only accessible from the allowlisted monitoring IP
- stopping `postgres_exporter` or `redis_exporter` produces a test alert delivered to `email`
