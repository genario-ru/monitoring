---
name: add-alert-rule
description: Adds or changes vmalert rules while preserving Alertmanager routing and noise controls.
---

# Add Alert Rule

## Workflow

1. Inspect nearby rules in `vmalert/rules/alerts.yml`.
2. Confirm the metric exists in current dashboards, exporter docs, or scrape targets.
3. Add the rule to the most relevant group or create a clearly named group.
4. Use current stable `job` labels.
5. Add a `for:` duration unless the alert intentionally fires immediately.
6. Add `summary` and `description` annotations.
7. Update README alerting checks if the alert affects acceptance/testing.
8. Validate compose config and YAML syntax when tooling is available.

## Safety

- Do not change Alertmanager secrets.
- Do not run runtime outage smoke tests unless explicitly requested.
