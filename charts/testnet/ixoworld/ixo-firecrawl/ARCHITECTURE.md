# Firecrawler Helm Chart Architecture

## Overview

This Helm chart uses a **sub-chart architecture** to enable independent CI/CD pipelines for each component while deploying all three containers in a single pod.

## Architecture Design

### Single Pod, Multiple Containers
```
┌─────────────────────────────────────────────────────────┐
│  Pod: ixo-firecrawler                                   │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────┐│
│  │ API Server      │  │ MCP Server      │  │ Playwright│
│  │ Port: 3002      │  │ Port: 3000      │  │ Port: 3000│
│  │ Image: v1.2.3   │  │ Image: latest   │  │ Image: latest│
│  └─────────────────┘  └─────────────────┘  └─────────┘│
│          ↓                    ↓                   ↓     │
│        localhost:3002    localhost:3000    localhost:3000│
└─────────────────────────────────────────────────────────┘
```

**Benefits:**
- ✅ Zero network latency between containers (localhost)
- ✅ Shared network namespace
- ✅ Simplified service discovery
- ✅ Single deployment to manage

### Independent Sub-Charts

```
ixo-firecrawler/
├── Chart.yaml                      # Parent chart
│   └── dependencies:
│       ├── api-server (v0.0.1)
│       ├── mcp-server (v0.0.1)
│       └── playwright-service (v0.0.1)
│
├── values.yaml                     # Override values for all sub-charts
│
└── charts/
    ├── api-server/
    │   ├── Chart.yaml             # appVersion: v1.2.3 (CI/CD updates)
    │   └── values.yaml            # Default values
    │
    ├── mcp-server/
    │   ├── Chart.yaml             # appVersion: latest (CI/CD updates)
    │   └── values.yaml            # Default values
    │
    └── playwright-service/
        ├── Chart.yaml              # appVersion: latest (CI/CD updates)
        └── values.yaml             # Default values
```

## How It Works

### 1. Image Tag Resolution

Each container's image tag is resolved from its sub-chart's `appVersion`:

```yaml
# In deployment.yaml
image: "{{ index .Values "api-server" "image" "repository" }}:{{ (index .Subcharts "api-server").Chart.AppVersion }}"
#                                                               ↑ Uses sub-chart's appVersion
```

**Flow:**
1. Sub-chart `charts/api-server/Chart.yaml` has `appVersion: v1.2.3`
2. Deployment template reads this value: `.Subcharts.api-server.Chart.AppVersion`
3. Final image: `ghcr.io/ixoworld/firecrawl:v1.2.3`

### 2. Independent CI/CD Pipelines

#### API Server Pipeline
```bash
# Forked repository: github.com/ixoworld/firecrawler-api
1. Trigger: Push to main or tag
2. Build: docker build -t ghcr.io/ixoworld/firecrawl:v1.2.3
3. Push: docker push ghcr.io/ixoworld/firecrawl:v1.2.3
4. Update: charts/api-server/Chart.yaml
   - version: 0.0.2 (increment)
   - appVersion: v1.2.3 (match Docker tag)
5. Commit: git commit -m "chore: bump api-server to v1.2.3"
6. Deploy: helm upgrade firecrawler ./ixo-firecrawler
```

#### MCP Server Pipeline (Future)
```bash
# Forked repository: github.com/ixoworld/firecrawler-mcp
1. Trigger: Push to main or tag
2. Build: docker build -t ghcr.io/ixoworld/firecrawl-mcp:v2.0.0
3. Push: docker push ghcr.io/ixoworld/firecrawl-mcp:v2.0.0
4. Update: charts/mcp-server/Chart.yaml
   - version: 0.0.2 (increment)
   - appVersion: v2.0.0 (match Docker tag)
5. Commit: git commit -m "chore: bump mcp-server to v2.0.0"
6. Deploy: helm upgrade firecrawler ./ixo-firecrawler
```

**Key Points:**
- ✅ Each CI/CD only updates its own sub-chart's `Chart.yaml`
- ✅ No conflicts between pipelines
- ✅ Clear version history per component
- ✅ Can deploy components independently

### 3. Values Override

The parent `values.yaml` overrides all sub-chart values:

```yaml
# Parent values.yaml
api-server:  # Overrides charts/api-server/values.yaml
  image:
    repository: ghcr.io/ixoworld/firecrawl  # Your fork
  env:
    - name: PORT
      value: "3002"

mcp-server:  # Overrides charts/mcp-server/values.yaml
  image:
    repository: ghcr.io/firecrawl/firecrawl-mcp-server  # Upstream
  env:
    - name: PORT
      value: "3000"
```

## Deployment Workflow

### Initial Setup
```bash
# 1. Update dependencies (generates .tgz files and Chart.lock)
helm dependency update ./ixo-firecrawler

# 2. Install
helm install firecrawler ./ixo-firecrawler -f values-production.yaml
```

### Updating a Component

**Option 1: CI/CD automatically updates and deploys**
```bash
# CI/CD pipeline handles everything
# Just push code to the component's repository
```

**Option 2: Manual update**
```bash
# 1. Update the sub-chart's Chart.yaml
cd charts/api-server
yq -i '.appVersion = "v1.2.4"' Chart.yaml

# 2. Update dependencies
cd ../..
helm dependency update

# 3. Upgrade deployment
helm upgrade firecrawler ./ixo-firecrawler
```

## Version Management

### Chart Versions vs App Versions

| Type | Location | Purpose | Updated By |
|------|----------|---------|------------|
| **Chart Version** | `charts/*/Chart.yaml → version` | Helm chart version | CI/CD |
| **App Version** | `charts/*/Chart.yaml → appVersion` | Docker image tag | CI/CD |
| **Parent Version** | `Chart.yaml → version` | Overall chart version | Manual |

**Example:**
```yaml
# charts/api-server/Chart.yaml
version: 0.0.5        # Helm chart version (incremented with each release)
appVersion: v1.2.3    # Docker image tag (semantic versioning)
```

**Deployment uses:**
```yaml
image: ghcr.io/ixoworld/firecrawl:v1.2.3  # ← appVersion
```

## Benefits of This Architecture

### ✅ Independent CI/CD
- Each component has its own repository and pipeline
- No merge conflicts in Chart.yaml
- Clear ownership and version history

### ✅ Simplified Deployment
- Single `helm upgrade` deploys all components
- All containers in one pod (no network overhead)
- Atomic updates (all or nothing)

### ✅ Flexible Configuration
- Override any component's values independently
- Mix forked and upstream images
- Environment-specific configurations

### ✅ Clear Version Tracking
```bash
# Check current versions
helm list
kubectl describe pod firecrawler-xxx

# Output shows each container's image:
# - api: ghcr.io/ixoworld/firecrawl:v1.2.3
# - mcp-server: ghcr.io/firecrawl/mcp-server:latest
# - playwright: ghcr.io/firecrawl/playwright:latest
```

## Troubleshooting

### Sub-charts not found
```bash
# Run dependency update
helm dependency update ./ixo-firecrawler
```

### Wrong image version deployed
```bash
# Check sub-chart's appVersion
cat charts/api-server/Chart.yaml | grep appVersion

# Check what Helm will deploy
helm template test ./ixo-firecrawler | grep "image:"
```

### CI/CD conflicts
```bash
# Each CI/CD should only touch its own sub-chart:
# ✅ API Server CI/CD → charts/api-server/Chart.yaml
# ✅ MCP Server CI/CD → charts/mcp-server/Chart.yaml
# ❌ Never let multiple CI/CDs edit the parent Chart.yaml
```

## Migration from Monolithic Chart

If you had a single chart before:

```yaml
# Old structure
values.yaml:
  api:
    image:
      tag: v1.2.3  # Hard to manage with CI/CD
```

```yaml
# New structure
charts/api-server/Chart.yaml:
  appVersion: v1.2.3  # CI/CD updates this

values.yaml:
  api-server:
    image:
      # tag defaults to Chart.AppVersion
```

**Benefits:** CI/CD directly updates the Chart.yaml, not values.yaml. This follows Helm best practices.

