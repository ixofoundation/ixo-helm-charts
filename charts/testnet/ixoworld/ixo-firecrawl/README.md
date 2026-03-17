# ixo-firecrawler

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for Firecrawler with API, MCP Server, and Playwright Service

## Overview

This Helm chart deploys Firecrawler with three containers in a single pod:

- **API Server** (`api` container) - Main API service for Firecrawler (port 3002)
- **MCP Server** (`mcp-server` container) - Model Context Protocol server (port 3000)
- **Playwright Service** (`playwright-service` container) - Browser automation service (port 3000)

## Architecture: Sub-Charts for Independent CI/CD

This chart uses a **sub-chart architecture** where each component (API Server, MCP Server, Playwright Service) is defined as a separate sub-chart with its own `Chart.yaml`. This enables:

✅ **Independent versioning** - Each component has its own version and `appVersion`  
✅ **Separate CI/CD pipelines** - Each component's CI/CD can update only its own `Chart.yaml`  
✅ **Single deployment** - All three containers still run in one pod  
✅ **Localhost communication** - Containers communicate via localhost (no network overhead)

### Sub-Chart Structure

```
ixo-firecrawler/
├── Chart.yaml                          # Parent chart with dependencies
├── values.yaml                         # Overrides for all sub-charts
└── charts/
    ├── api-server/
    │   ├── Chart.yaml                 # Independent version & appVersion (CI/CD updates this)
    │   └── values.yaml                # Default values for API server
    ├── mcp-server/
    │   ├── Chart.yaml                 # Independent version & appVersion (CI/CD updates this)
    │   └── values.yaml                # Default values for MCP server
    └── playwright-service/
        ├── Chart.yaml                  # Independent version & appVersion (CI/CD updates this)
        └── values.yaml                 # Default values for Playwright service
```

### How CI/CD Works

Each component's CI/CD pipeline:

1. Builds the component's Docker image
2. Tags it with a version (e.g., `v1.2.3`)
3. Updates the component's `charts/COMPONENT/Chart.yaml`:
   - Increments `version`
   - Updates `appVersion` to match the Docker image tag
4. The parent deployment automatically uses the sub-chart's `appVersion` as the image tag

**Example for API Server CI/CD:**

```yaml
# charts/api-server/Chart.yaml gets updated by CI/CD
apiVersion: v2
name: api-server
version: 0.0.2          # CI/CD increments this
appVersion: v1.2.3      # CI/CD updates this to match Docker image tag
```

The deployment template uses this `appVersion`:

```yaml
image: "{{ .Values.api-server.image.repository }}:{{ .Subcharts.api-server.Chart.AppVersion }}"
#                                                    ↑ Uses the sub-chart's appVersion
```

## Installation

```bash
# Update dependencies (pulls sub-charts)
helm dependency update ./ixo-firecrawler

# Install the chart
helm install firecrawler ./ixo-firecrawler -f values.yaml
```

## Configuration

### API Server Configuration

Configure in the parent `values.yaml` under the `api-server` key:

```yaml
api-server:
  image:
    repository: ghcr.io/firecrawl/firecrawl
    pullPolicy: IfNotPresent
    # tag defaults to api-server sub-chart's Chart.AppVersion
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
  env:
    - name: HOST
      value: "0.0.0.0"
    - name: PORT
      value: "3002"
    - name: PLAYWRIGHT_MICROSERVICE_URL
      value: "http://localhost:3000/scrape"
    # Add more environment variables as needed
```

### MCP Server Configuration

```yaml
mcp-server:
  image:
    repository: ghcr.io/firecrawl/firecrawl-mcp-server
    pullPolicy: IfNotPresent
    # tag defaults to mcp-server sub-chart's Chart.AppVersion
  resources:
    limits:
      cpu: 500m
      memory: 1Gi
    requests:
      cpu: 250m
      memory: 512Mi
  env:
    - name: FIRECRAWL_API_KEY
      value: "no-auth-required"
    - name: FIRECRAWL_API_URL
      value: "http://localhost:3002"
```

### Playwright Service Configuration

```yaml
playwright-service:
  image:
    repository: ghcr.io/firecrawl/playwright-service
    pullPolicy: IfNotPresent
    # tag defaults to playwright-service sub-chart's Chart.AppVersion
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
  env:
    - name: PORT
      value: "3000"
```

## Services

The chart creates three Kubernetes services:

- `{{ release-name }}-ixo-firecrawler-api`: API Server (port 3002)
- `{{ release-name }}-ixo-firecrawler-mcp`: MCP Server (port 3000, admin port 8080)
- `{{ release-name }}-ixo-firecrawler-playwright`: Playwright Service (port 3000)

## Required Environment Variables

### API Server

Configure in `api-server.env`:

- `HOST`: "0.0.0.0"
- `PORT`: "3002"
- `USE_DB_AUTHENTICATION`: "false"
- `PLAYWRIGHT_MICROSERVICE_URL`: "http://localhost:3000/scrape"
- `REDIS_URL`: Redis connection URL
- `REDIS_RATE_LIMIT_URL`: Redis rate limit URL

For AI features:
- `OPENROUTER_API_KEY`
- `OPENAI_API_KEY`
- `LLM_PROVIDER`
- `MODEL_NAME`
- `OPENAI_BASE_URL`
- `VLM_MODEL_NAME`

For embeddings:
- `IXO_API_KEY`
- `EMBEDDING_PROVIDER`
- `IXO_BASE_URL`

### MCP Server

Configure in `mcp-server.env`:

- `FIRECRAWL_API_KEY`: "no-auth-required"
- `FIRECRAWL_API_URL`: "http://localhost:3002"
- `HTTP_STREAMABLE_SERVER`: "true"
- `HTTP_STREAMABLE_HOST`: "0.0.0.0"
- `HOST`: "0.0.0.0"
- `PORT`: "3000"

### Playwright Service

Configure in `playwright-service.env`:

- `PORT`: "3000"

## CI/CD Integration Example

### For Forked API Server

Your CI/CD pipeline should:

```bash
# 1. Build and push Docker image
docker build -t ghcr.io/your-org/firecrawl:v1.2.3 .
docker push ghcr.io/your-org/firecrawl:v1.2.3

# 2. Update the api-server sub-chart
cd charts/devnet/ixoworld/ixo-firecrawler/charts/api-server
yq -i '.version = "0.0.2"' Chart.yaml
yq -i '.appVersion = "v1.2.3"' Chart.yaml

# 3. Commit and push
git add Chart.yaml
git commit -m "chore: bump api-server to v1.2.3"
git push

# 4. Redeploy (helm will use the new appVersion automatically)
helm upgrade firecrawler ./ixo-firecrawler
```

### For Future MCP Server Fork

When you fork the MCP server, its CI/CD will update only `charts/mcp-server/Chart.yaml`, keeping it independent from the API server updates.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod scheduling |
| api-server.env | list | `[]` | Environment variables for API server |
| api-server.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| api-server.image.repository | string | `"ghcr.io/firecrawl/firecrawl"` | API server image repository |
| api-server.resources | object | `{}` | Resource limits and requests for API server |
| autoscaling.enabled | bool | `false` | Enable horizontal pod autoscaling |
| autoscaling.maxReplicas | int | `100` | Maximum replicas |
| autoscaling.minReplicas | int | `1` | Minimum replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage |
| fullnameOverride | string | `""` | Override full name |
| imagePullSecrets | list | `[]` | Image pull secrets |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific","service":"api"}]}]` | Ingress hosts configuration |
| ingress.tls | list | `[]` | Ingress TLS configuration |
| mcp-server.env | list | `[]` | Environment variables for MCP server |
| mcp-server.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| mcp-server.image.repository | string | `"ghcr.io/firecrawl/firecrawler-mcp-server"` | MCP server image repository |
| mcp-server.resources | object | `{}` | Resource limits and requests for MCP server |
| nameOverride | string | `""` | Override chart name |
| nodeSelector | object | `{}` | Node selector for pod scheduling |
| playwright-service.env | list | `[]` | Environment variables for Playwright service |
| playwright-service.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| playwright-service.image.repository | string | `"ghcr.io/firecrawl/playwright-service"` | Playwright service image repository |
| playwright-service.resources | object | `{}` | Resource limits and requests for Playwright service |
| podAnnotations | object | `{}` | Pod annotations |
| podSecurityContext | object | `{}` | Pod security context |
| replicaCount | int | `1` | Number of replicas |
| securityContext | object | `{}` | Container security context |
| service.apiPort | int | `3002` | API server service port |
| service.mcpPort | int | `3000` | MCP server service port |
| service.playwrightPort | int | `3000` | Playwright service port |
| service.type | string | `"ClusterIP"` | Service type |
| serviceAccount.annotations | object | `{}` | Service account annotations |
| serviceAccount.create | bool | `true` | Create service account |
| serviceAccount.name | string | `""` | Service account name |
| tolerations | list | `[]` | Tolerations for pod scheduling |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
