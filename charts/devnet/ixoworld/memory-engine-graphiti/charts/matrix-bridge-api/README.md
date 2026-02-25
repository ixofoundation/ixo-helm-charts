# matrix-bridge-api (subchart)

Matrix Bridge API sidecar for the Graphiti memory engine. Version is managed **separately** from the parent chart.

- **Image tag**: Set via `Chart.AppVersion` in this `Chart.yaml`. CI/CD can bump it independently (e.g. when `matrix-bridge-api` is released).
- **Parent overrides**: Use the `matrix-bridge-api` key in the parent chart values (or your overrides file) to set `enabled`, `image.repository`, `env`, `resources`, etc.
- This subchart does **not** render its own Deployment; the parent chart adds the bridge as a container when `matrix-bridge-api.enabled` is true.
