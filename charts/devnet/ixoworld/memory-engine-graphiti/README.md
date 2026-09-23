# memory-engine-graphiti

Deploys **memory-engine-ts** (`ghcr.io/ixoworld/memory-engine-graphiti-memory-engine-ts`):
one container serving REST and MCP (`/mcp`) on a single port, with its own PVC
mounted at `/data` (`DATA_DIR=/data/spaces`, `MATRIX_STORE_PATH=/data/matrix-store`).

The image tag defaults to `appVersion`, which the memory-engine-ts CI bumps on
`develop` pushes. Leave `image.tag` empty unless you need to pin.

## Resources

| Resource | Name | Notes |
|---|---|---|
| Deployment | `<fullname>-ts` | 1 replica, `Recreate` (kuzu/SQLite are single-writer) |
| PVC | `<fullname>-ts-storage` | `persistentVolume.*` |
| Service | `<fullname>` | `service.port` and `service.portMcp` both target the container port |
| Ingress | `<fullname>`, `mcp-<fullname>` | unchanged; now route to memory-engine-ts |

No HPA is rendered: the engine must run as a single replica.

## Legacy stack (migration)

While `legacy.enabled: true` the old python Deployment (`<fullname>`: worker,
api-server, mcp-server) and the matrix-bridge-api Deployment stay rendered at
**0 replicas**, so their PVCs stay bound for migrating data into
`<fullname>-ts-storage`:

- `<fullname>-storage` — python stack (`/storage/matrix_bot_store`)
- `<fullname>-matrix-bridge-storage` — matrix-bridge-api (`/storage/matrix_bridge_store`)

Both legacy PVCs are annotated `argocd.argoproj.io/sync-options: Prune=false`,
so they are **not** deleted when `legacy.enabled` is set to `false`; delete them
by hand once the migration is verified.

Rollback: set `legacy.replicaCount: 1` and `matrix-bridge-api.replicaCount: 1`,
and point the Service back at the legacy pods (it now selects memory-engine-ts).
