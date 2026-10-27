# memory-engine-graphiti

![Version: 0.1.18](https://img.shields.io/badge/Version-0.1.18-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0-develop.17](https://img.shields.io/badge/AppVersion-1.0.0--develop.17-informational?style=flat-square)

Memory engine (memory-engine-ts) — single service serving REST + MCP on one port

## Operations

### Runtime posture: one replica, `Recreate`

The engine owns `/data/spaces` exclusively. kuzu, LanceDB and SQLite files are
single-process: two processes on one space have torn the kuzu write-ahead log twice
in production. So the chart renders exactly one replica with `strategy: Recreate`,
no HPA and no PodDisruptionBudget (a PDB on a single replica would only block node
drains). The cost is a conscious SLO: every rollout, node move or restart is an
outage of up to `terminationGracePeriodSeconds` (200 s: stop ingest, let the
in-flight cognify finish, write registries, flush owner copies) plus the RWO volume
detach/attach plus startup. There is no canary. Callers retry; episodes already
accepted are journaled on the volume, not held in memory.

### Memory, QoS and the `MAX_OPEN_SPACES` knob

`containers.memoryEngine.resources` is the single memory knob. Requests equal limits
(3Gi on all three environments today) and the CPU request is 500m, with no CPU
limit. A kill (container OOM or node-pressure eviction) is a SIGKILL, and a SIGKILL
inside a commit can tear a space's kuzu WAL; with requests equal to the limit the pod
is never over its request, which is what the kubelet ranks eviction on, and the
scheduler reserves the whole budget. The QoS class is nevertheless **Burstable, not
Guaranteed**: Guaranteed would also need a CPU limit, and that would throttle gzip,
cognify post-processing and search ranking. Do not add one without measuring.

`MAX_OPEN_SPACES` must be sized against that limit:

    MAX_OPEN_SPACES <= (limit_MiB - 700) / 150

(about 700 MB baseline, 100-150 MB per open space). At 3Gi the ceiling is 15; the
chart sets 12, the value live on devnet, which leaves room for the largest space,
which alone sits about 1.1 GB above baseline, and for memory Node and LanceDB do not
hand back promptly. The pool itself does not overshoot: a cold open evicts an idle
space before it opens one, and when every pooled space is busy it waits
`OPEN_WAIT_MS` (5 s) and then answers 503 `ENGINE_BUSY`. Change the limit and
`MAX_OPEN_SPACES` together. The engine default is 64, which is about 10 GB and larger
than the limit; the engine caps a configured value that does not fit the formula
and logs the cap at error.

### Memory watermark and alerts

Since memory-engine-ts 2.1.1 (devnet `1.0.0-develop.15`) memory never refuses,
holds back or un-readies anything. When RSS crosses `MEMORY_HIGH_WATER_PCT` of the
limit (engine default 75; this chart does not set it) the engine closes every idle
space once and logs one warning; the next crossing is armed only after RSS has
fallen 5 points below the mark. `MEMORY_LOW_WATER_PCT` is ignored (one info line at
startup when it is set): remove it wherever it is still set (Vault). A working set
that really exceeds the limit is left to the cgroup OOM kill; the pod restarts and
journaled writes replay. The engine's own gauges `memory_limit_bytes` and
`memory_over_watermark` (1 while RSS is over the mark) are on `/metrics`.

What tells devops to raise `containers.memoryEngine.resources.limits.memory` is the
chart's `PrometheusRule` (`templates/prometheusrule.yaml`, rendered while
`alerts.enabled`):

| Alert | Fires when | Severity |
|---|---|---|
| `MemoryEngineNearMemoryLimit` | the `memory-engine` container's `container_memory_working_set_bytes` / `kube_pod_container_resource_limits{resource="memory"}` stays above `alerts.nearLimitRatio` (0.85) for `alerts.nearLimitFor` (10m) | warning |
| `MemoryEngineOOMKilled` | the container restarted in the last 15 min and its last termination reason is `OOMKilled` | critical |

Both read cAdvisor and kube-state-metrics series only, not the engine's `/metrics`.
The rule carries the label `release: <alerts.prometheusRelease>`
(`kube-prometheus-stack`), which the cluster's kube-prometheus-stack `ruleSelector`
matches; a cluster without the `PrometheusRule` CRD needs `alerts.enabled: false`.
Raise the limit and `MAX_OPEN_SPACES` together (above).

### Environment variables

Set in `containers.memoryEngine.env` (explicit entries win over the Vault-backed
secret on the same name, so these four values replace whatever Vault holds for them;
check Vault before the first sync of testnet and mainnet):

| Variable | Chart value | Meaning |
|---|---|---|
| `MAX_OPEN_SPACES` | `12` | Pooled open spaces; sized from the memory limit as above. |
| `INGEST_CONCURRENCY` | `4` | Concurrent ingest (cognify) batches across spaces. |
| `UV_THREADPOOL_SIZE` | `16` | libuv threadpool (fs, gzip, crypto); Node's default of 4 serialises snapshot and tar work. |
| `LOG_LEVEL` | `info` | Log level. |

Set by the chart from other values (entries with these names in `env` are ignored):

| Variable | From | Value |
|---|---|---|
| `PORT` | `service.port` | `3200` (REST and MCP share it) |
| `DATA_DIR` | `persistentVolume.mountPath` | `/data/spaces` |
| `MATRIX_STORE_PATH` | `persistentVolume.mountPath` | `/data/matrix-store` |
| `METRICS_PORT` | `metrics.port` | `9464` |

`APP_VERSION` and `GIT_SHA` are baked into the image and deliberately not set here.
Every other variable comes from the Vault-backed secret (`externalSecret`) or the
engine's own defaults. The top-level `env` list is still appended to the engine's
container (and is shared with the legacy Deployments); on a name clash the later
entry wins.

### Probes

| Probe | Path | Period | Timeout | Failure threshold | Effect |
|---|---|---|---|---|---|
| startup | `/healthcheck` | 10 s | default | 30 (300 s) | Boot guard; unchanged. |
| readiness | `/healthcheck/ready` | 10 s | 5 s | 3 | Engine-defined readiness: 503 while the post-listen startup work is unfinished, once shutdown has begun, when event-loop lag exceeds 5 s, or when the data volume cannot be measured; never because of memory. Removes the pod from the Service, never restarts it. |
| liveness | `/healthcheck` | 30 s | 10 s | 6 | Restarts only after about 3 minutes of a stuck event loop. |

A restart is a SIGKILL risk for the kuzu WAL, which is why liveness stays trivial and
tolerant while readiness carries the state. `/healthcheck/ready` must be served by the
engine image (a memory-engine-ts change made alongside this chart); an image that
does not have it answers 404, so the readiness probe fails and the pod never becomes
Ready. **Roll the image and this chart together.**

### Security context and filesystem

The image runs as `USER node` (uid 1000, gid 1000). The pod sets `runAsNonRoot`,
`runAsUser`/`runAsGroup` 1000, `fsGroup: 1000` with
`fsGroupChangePolicy: OnRootMismatch`, and the container drops all capabilities,
forbids privilege escalation and has a read-only root filesystem
(`containers.memoryEngine.podSecurityContext` / `.securityContext`). Existing `/data`
volumes hold root-owned files: on the first start the kubelet chowns the volume to gid
1000 once (`OnRootMismatch` makes later starts skip it when the volume root is
already right). On a large volume that first start spends time recursing before the
container begins; the startup probe's 300 s starts counting only when the container
runs.

**The app writes only under `/data` (the PVC), `/tmp` and `/app/logs`.** `/tmp` is an
`emptyDir` (Node and tar/gzip need it); it is not size-limited, so it counts against
the node's ephemeral storage. `/app/logs` is an `emptyDir` capped at 1Gi for the
Matrix client's logger, which opens `logs/*.log` relative to the working directory
and otherwise fails to initialise on the read-only root filesystem (seen on devnet
Oct 14 2026: "Matrix initialization failed — event logging disabled"). Those files
duplicate stdout and are lost with the pod on purpose. The legacy Deployments keep the shared top-level
`podSecurityContext`/`securityContext` (empty), so the rollback path still runs as
root.

### Metrics

The engine serves Prometheus metrics on `metrics.port` (9464, container port named
`metrics`). The pod carries `prometheus.io/scrape: "true"` and
`prometheus.io/port: "9464"`. There is no Service port and no ingress for it, so it is
reachable inside the cluster only (`METRICS_PORT=0` would turn it off). The memory
alerts above do not depend on it.

### Storage

`persistentVolume.size` should satisfy
`spaces x p50 space size x 1.5 + 2 x largest space x 1.5 + 20 %` (the second term is
headroom for two concurrent owner-copy flushes of the largest space; quarantined
copies share the volume). At 40Gi the byte ceiling is roughly 1,500-2,000 median
spaces. The class is `vultr-block-storage-hdd` on all three environments; cold opens,
the WAL and snapshot copies are disk-bound on it. **Open decision: storage class and
size per environment** (the SSD class name is unverified here). `storageClassName`
is immutable on a PVC, so a class change means a new volume and a data copy.
Growing `size` in place needs `allowVolumeExpansion: true` on the class (verify).

### VPA

`verticalPodAutoscaler.updateMode` must stay `Off` (or `Initial`). `Auto` and
`Recreate` evict the pod to apply recommendations, and an eviction is a SIGKILL.

### Image tags

The image tag is empty in `values.yaml` and comes from `Chart.appVersion`. Devnet
tracks branch builds (`develop-<sha>`); testnet follows `main` builds and mainnet
only ever receives a stable `MAJOR.MINOR.PATCH` release: the "Deploy to Mainnet"
workflow refuses any other tag instead of falling back to the newest one.

### Scaling further

This chart serves one pod. Past the vertical limits of one node (the volume, the
number of warm spaces that fit in memory, startup work that grows with the number of
spaces) the next step is horizontal sharding: a StatefulSet with one PVC per shard,
a space-to-shard map, routing or in-app forwarding of requests to the owning shard,
and a decision on where the shared oracle spaces live. **That design is not
implemented and not decided**; it is a decision for the owners. Every single-pod
fix above (memory admission, probes, QoS, disk guard) carries over to each shard, and
a PDB with `maxUnavailable: 1` would be added with it.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| alerts.enabled | bool | `true` |  |
| alerts.nearLimitFor | string | `"10m"` |  |
| alerts.nearLimitRatio | float | `0.85` |  |
| alerts.prometheusRelease | string | `"kube-prometheus-stack"` |  |
| containers.apiServer.image | string | `"ghcr.io/ixoworld/memory-engine-graphiti-api-server"` |  |
| containers.apiServer.resources | object | `{}` |  |
| containers.mcpServer.image | string | `"ghcr.io/ixoworld/memory-engine-graphiti-mcp-server"` |  |
| containers.mcpServer.resources | object | `{}` |  |
| containers.memoryEngine.env[0].name | string | `"MAX_OPEN_SPACES"` |  |
| containers.memoryEngine.env[0].value | string | `"12"` |  |
| containers.memoryEngine.env[1].name | string | `"INGEST_CONCURRENCY"` |  |
| containers.memoryEngine.env[1].value | string | `"4"` |  |
| containers.memoryEngine.env[2].name | string | `"UV_THREADPOOL_SIZE"` |  |
| containers.memoryEngine.env[2].value | string | `"16"` |  |
| containers.memoryEngine.env[3].name | string | `"LOG_LEVEL"` |  |
| containers.memoryEngine.env[3].value | string | `"info"` |  |
| containers.memoryEngine.fixVolumeOwnership.enabled | bool | `true` |  |
| containers.memoryEngine.fixVolumeOwnership.force | bool | `false` |  |
| containers.memoryEngine.podSecurityContext.fsGroup | int | `1000` |  |
| containers.memoryEngine.podSecurityContext.fsGroupChangePolicy | string | `"OnRootMismatch"` |  |
| containers.memoryEngine.podSecurityContext.runAsGroup | int | `1000` |  |
| containers.memoryEngine.podSecurityContext.runAsNonRoot | bool | `true` |  |
| containers.memoryEngine.podSecurityContext.runAsUser | int | `1000` |  |
| containers.memoryEngine.resources.limits.memory | string | `"3Gi"` |  |
| containers.memoryEngine.resources.requests.cpu | string | `"500m"` |  |
| containers.memoryEngine.resources.requests.memory | string | `"3Gi"` |  |
| containers.memoryEngine.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| containers.memoryEngine.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| containers.memoryEngine.securityContext.readOnlyRootFilesystem | bool | `true` |  |
| containers.worker.image | string | `"ghcr.io/ixoworld/memory-engine-graphiti-community-worker"` |  |
| containers.worker.resources | object | `{}` |  |
| env | list | `[]` |  |
| externalSecret.enabled | bool | `false` |  |
| externalSecret.refreshInterval | string | `"1m"` |  |
| externalSecret.storeName | string | `"vault"` |  |
| externalSecret.vaultPath | string | `""` |  |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/ixoworld/memory-engine-graphiti-memory-engine-ts"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| ingressMcp.annotations | object | `{}` |  |
| ingressMcp.className | string | `""` |  |
| ingressMcp.enabled | bool | `false` |  |
| ingressMcp.hosts[0].host | string | `"chart-example.local"` |  |
| ingressMcp.hosts[0].paths[0].path | string | `"/"` |  |
| ingressMcp.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingressMcp.tls | list | `[]` |  |
| legacy.enabled | bool | `true` |  |
| legacy.image.tag | string | `"main-2ad8596"` |  |
| legacy.persistentVolume.accessModes[0] | string | `"ReadWriteOnce"` |  |
| legacy.persistentVolume.mountPath | string | `"/storage/matrix_bot_store"` |  |
| legacy.persistentVolume.size | string | `"40Gi"` |  |
| legacy.persistentVolume.storageClass | string | `"vultr-block-storage-hdd"` |  |
| legacy.replicaCount | int | `0` |  |
| matrix-bridge-api.enabled | bool | `false` |  |
| matrix-bridge-api.env | list | `[]` |  |
| matrix-bridge-api.image.pullPolicy | string | `"IfNotPresent"` |  |
| matrix-bridge-api.image.repository | string | `"ghcr.io/ixoworld/memory-engine-graphiti"` |  |
| matrix-bridge-api.image.tag | string | `"v1.3.1"` |  |
| matrix-bridge-api.persistentVolume.accessModes[0] | string | `"ReadWriteOnce"` |  |
| matrix-bridge-api.persistentVolume.mountPath | string | `"/storage/matrix_bridge_store"` |  |
| matrix-bridge-api.persistentVolume.size | string | `"40Gi"` |  |
| matrix-bridge-api.persistentVolume.storageClass | string | `"vultr-block-storage-hdd"` |  |
| matrix-bridge-api.port | int | `3100` |  |
| matrix-bridge-api.replicaCount | int | `0` |  |
| matrix-bridge-api.resources | object | `{}` |  |
| matrix-bridge-api.verticalPodAutoscaler.enabled | bool | `false` |  |
| matrix-bridge-api.verticalPodAutoscaler.resourcePolicy | object | `{}` |  |
| matrix-bridge-api.verticalPodAutoscaler.updateMode | string | `"Off"` |  |
| metrics.port | int | `9464` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| persistentVolume.accessModes[0] | string | `"ReadWriteOnce"` |  |
| persistentVolume.mountPath | string | `"/data"` |  |
| persistentVolume.size | string | `"40Gi"` |  |
| persistentVolume.storageClass | string | `"vultr-block-storage-hdd"` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| replicaCount | int | `1` |  |
| securityContext | object | `{}` |  |
| service.port | int | `3200` |  |
| service.portMcp | int | `8080` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| strategy.type | string | `"Recreate"` |  |
| terminationGracePeriodSeconds | int | `200` |  |
| tolerations | list | `[]` |  |
| verticalPodAutoscaler.enabled | bool | `false` |  |
| verticalPodAutoscaler.resourcePolicy | object | `{}` |  |
| verticalPodAutoscaler.updateMode | string | `"Off"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
