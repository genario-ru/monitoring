---
name: Project architecture
description: Monitoring stack and data flow for genario-monitoring
type: project
---

## Stack

- Docker Compose deployed by Dokploy.
- Grafana for dashboards.
- VictoriaMetrics for scraping and metric storage.
- vmalert for alert rule evaluation.
- Alertmanager for email routing.
- GlitchTip for error tracking with internal PostgreSQL and Valkey.

## Data Flow

Grafana queries VictoriaMetrics. VictoriaMetrics scrapes backend metrics and exporters. vmalert queries VictoriaMetrics and sends fired alerts to Alertmanager. Alertmanager sends email notifications.

Grafana and GlitchTip are exposed through Dokploy domains. The rest of the stack remains internal.
