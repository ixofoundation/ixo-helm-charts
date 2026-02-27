# ixo-matrix-whatsapp

Helm chart for [mautrix-whatsapp](https://github.com/mautrix/whatsapp) (Matrix ↔ WhatsApp bridge) on Kubernetes. Implements [Linear IXO-636](https://linear.app/ixo-world/issue/IXO-636/whatsapp-matrix-bridge).

The official [matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy) and community Helm charts are either Ansible-based or outdated; this chart provides a standalone, up-to-date Kubernetes deployment.

## Requirements

- Kubernetes cluster
- Matrix homeserver (Synapse or compatible) with appservice support
- PostgreSQL (recommended) or SQLite for bridge database
- WhatsApp client (phone or emulator) to link via QR code

## Install

1. Create a namespace and (if using Postgres) a secret with the database URI:
   ```bash
   kubectl create secret generic mautrix-whatsapp-db --from-literal=uri='postgres://user:pass@host:5432/mautrix_whatsapp?sslmode=disable'
   ```

2. Copy [values.yaml](values.yaml) and set at least:
   - `homeserver.address` – URL your Synapse is reachable at from the cluster (e.g. `http://synapse:8008`)
   - `homeserver.domain` – your Matrix server name (e.g. `mx.ixo.earth`)
   - `appservice.address` – URL Synapse will use to reach this bridge (e.g. `http://ixo-matrix-whatsapp:8008` or your release name)
   - `database.uri` or `database.existingSecret` (e.g. `mautrix-whatsapp-db`)

3. Install:
   ```bash
   helm install ixo-matrix-whatsapp . -f my-values.yaml -n matrix
   ```

4. After the first run, copy the registration file into Synapse and add it to `app_service_config_files`, then restart Synapse. See [NOTES.txt](templates/NOTES.txt) for the exact `kubectl exec` command.

5. In Matrix, DM `@whatsappbot:<your-domain>` and send `login` to link WhatsApp.

## Configuration

| Section | Key | Description |
|--------|-----|-------------|
| `homeserver` | `address`, `domain` | Synapse URL and server name |
| `appservice` | `address`, `hostname`, `port` | Bridge listen and registration URL |
| `database` | `type`, `uri` or `existingSecret` | Postgres or SQLite |
| `permissions` | Map of mxid/domain → relay/commands/user/admin | Who can use the bridge |
| `encryption` | `allow`, `default`, `pickle_key` | End-to-bridge encryption |

See [values.yaml](values.yaml) and [mautrix docs](https://docs.mau.fi/bridges/go/whatsapp/) for full options.

## Image

Uses the official image: `dock.mau.dev/mautrix/whatsapp`. Prefer a tagged version (e.g. `v26.02`) over `latest` in production.
