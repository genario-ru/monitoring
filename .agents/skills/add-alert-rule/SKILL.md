---
name: add-alert-rule
description: Use when adding or changing vmalert alert rules.
---

# Add Alert Rule

1. Inspect nearby rules in `vmalert/rules/alerts.yml`.
2. Confirm the metric and `job` label exist in scrape config, dashboards, or exporter output.
3. Add the rule to the right group or create a clearly named group.
4. Include a `for:` duration unless immediate firing is intentional.
5. Include `summary` and `description` annotations.
6. Update README alerting checks if the alert changes expected operations.
7. Validate compose config and YAML syntax when tooling is available.

Do not run outage smoke tests unless explicitly requested.
