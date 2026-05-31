# Add Alert Rule

Add or change a vmalert rule.

## Arguments

`$ARGUMENTS` - alert name, metric, threshold, duration, and operational intent.

## Workflow

1. Inspect related rules in `vmalert/rules/alerts.yml`.
2. Confirm metrics and `job` labels are available from scrape config, dashboards, or exporter output.
3. Add the rule to a relevant group.
4. Include a `for:` duration unless immediate firing is intentional.
5. Include `summary` and `description`.
6. Update README alerting checks if the alert changes expected operations.
7. Validate compose config and YAML syntax when available.

Do not trigger outage smoke tests unless explicitly requested.
