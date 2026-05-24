# Monitoring

This repository contains the self-hosted monitoring stack for `genario`:

- `Dokploy Domains` publishes Grafana on `https://grafana.<your-domain>`
- `Grafana` renders dashboards
- `VictoriaMetrics` stores, scrapes, and serves metrics
- `vmalert` evaluates alert rules against `VictoriaMetrics`
- `Alertmanager` routes baseline alerts to `Telegram` and `email`

## Repository layout

- `docker-compose.yml`: monitoring stack definition
- `.env.example`: required runtime variables
- `victoriametrics/`: scrape configuration for `VictoriaMetrics`
- `vmalert/`: alert rules for `vmalert`
- `alertmanager/`: Alertmanager config
- `grafana/provisioning/`: automatic datasource and dashboard provisioning
- `grafana/dashboards/`: file-based dashboards committed to git

## What this repository currently covers

- `backend` scrape target on `http://<app-vps-ip>:3000/metrics`
- `app-node` scrape target on `http://<app-vps-ip>:9100/metrics`
- `data-node` scrape target on `http://<data-vps-ip>:9100/metrics`
- `postgres` scrape target on `http://<data-vps-ip>:<postgres-exporter-port>/metrics`
- `redis` scrape target on `http://<data-vps-ip>:<redis-exporter-port>/metrics`
- one host dashboard
- one backend dashboard
- one PostgreSQL dashboard
- one Redis dashboard
- baseline alert rules for backend, hosts, PostgreSQL, and Redis

This repository still does **not** include:

- worker metrics
- logs / traces
- HA `VictoriaMetrics` / `vmalert` / `Alertmanager`

## Local configuration

1. Copy `.env.example` to `.env`.
2. Set:
   - `GRAFANA_ADMIN_USER`
   - `GRAFANA_ADMIN_PASSWORD`
   - `APP_DOMAIN`
   - `DATA_VPS_IP`
   - `POSTGRES_EXPORTER_PORT`
   - `REDIS_EXPORTER_PORT`
   - `ALERTMANAGER_TELEGRAM_BOT_TOKEN`
   - `ALERTMANAGER_TELEGRAM_CHAT_ID`
   - `ALERTMANAGER_EMAIL_FROM`
   - `ALERTMANAGER_EMAIL_TO`
   - `ALERTMANAGER_EMAIL_SMARTHOST`
   - `ALERTMANAGER_EMAIL_AUTH_USERNAME`
   - `ALERTMANAGER_EMAIL_AUTH_PASSWORD`
   - `ALERTMANAGER_EMAIL_REQUIRE_TLS`
3. Keep `VICTORIAMETRICS_RETENTION_MONTHS=1` unless you have a clear reason to retain more metrics.
5. Keep all Alertmanager secrets only in the real `.env` on the monitoring VPS; never commit them to git.

## Deploy on monitoring VPS

```powershell
Copy-Item .env.example .env
docker compose pull
docker compose up -d
```

After startup:

- configure a Dokploy domain for the `grafana` service on port `3000`
- open the configured Grafana domain
- log in with `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`
- confirm the `VictoriaMetrics` datasource is healthy
- confirm the `Host Overview`, `Backend Overview`, `Postgres Overview`, and `Redis Overview` dashboards are present

## Manual work on app VPS

1. Install `node_exporter` as a `systemd` service.
2. Open port `9100` **only** for the monitoring VPS IP.
3. Set backend env:

```env
METRICS_ALLOWED_IPS=<monitoring-vps-ip>
```

4. Redeploy `genario-backend` after the `/metrics` code changes.
5. Verify that:
   - `curl http://127.0.0.1:3000/metrics` works from the app host only if the source IP is allowlisted
   - VictoriaMetrics shows `backend` and `app-node` as `UP`

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

## Manual work on data VPS

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
7. Verify that VictoriaMetrics shows `data-node`, `postgres`, and `redis` as `UP`.

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

## Firewall checklist

- allow `monitoring VPS -> app VPS : 3000`
- allow `monitoring VPS -> app VPS : 9100`
- allow `monitoring VPS -> data VPS : 9100`
- allow `monitoring VPS -> data VPS : 9187`
- allow `monitoring VPS -> data VPS : 9121`
- do **not** publish VictoriaMetrics, `vmalert`, or Alertmanager to the public internet
- do **not** publish custom `80/443` ports from this compose stack; Dokploy already owns ingress on the server

## Alerts

- All baseline alerts go to both `Telegram` and `email`.
- Routing is intentionally simple in this phase: no severity splitting yet.
- Baseline thresholds in alert rules are starting defaults only.
- Revisit thresholds after several days of production observation.

## Acceptance checklist

- `https://grafana.<domain>` is reachable over `HTTPS`
- Grafana requires login
- `backend`, `app-node`, `data-node`, `postgres`, and `redis` are `UP` in VictoriaMetrics
- `Host Overview` shows CPU, memory, disk, load, network, uptime
- `Backend Overview` shows request rate, response classes, latency, in-flight requests, memory, CPU, uptime
- `Postgres Overview` shows exporter health, DB health, connections, transaction rate, size, deadlocks, checkpoint pressure
- `Redis Overview` shows exporter health, Redis health, memory usage, clients, ops/sec, evictions, rejected connections, persistence health
- `/metrics` on the backend is only accessible from the allowlisted monitoring IP
- stopping `postgres_exporter` or `redis_exporter` produces a test alert delivered to both `Telegram` and `email`
