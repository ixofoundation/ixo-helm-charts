# Playwright Service Sub-Chart

This is a sub-chart for the Firecrawler Playwright Service component.

## CI/CD Integration

Your CI/CD pipeline should update this `Chart.yaml` file when building and deploying a new version:

1. Build the Docker image: `docker build -t ghcr.io/your-org/playwright-service:v2.1.0 .`
2. Push the image: `docker push ghcr.io/your-org/playwright-service:v2.1.0`
3. Update `Chart.yaml`:
   - Increment `version` (e.g., from `0.0.1` to `0.0.2`)
   - Update `appVersion` to match the Docker tag (e.g., `v2.1.0`)
4. Commit and push: `git commit -am "chore: bump playwright-service to v2.1.0" && git push`
5. The parent chart will automatically use the new `appVersion` as the image tag

## Example CI/CD Script

```bash
#!/bin/bash
NEW_VERSION="v2.1.0"

# Update Chart.yaml
yq -i '.version = "0.0.2"' Chart.yaml
yq -i ".appVersion = \"$NEW_VERSION\"" Chart.yaml

# Commit and push
git add Chart.yaml
git commit -m "chore: bump playwright-service to $NEW_VERSION"
git push
```

## Configuration

See parent chart's `values.yaml` under the `playwright-service` key.

