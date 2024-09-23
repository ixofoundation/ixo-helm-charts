# Hummingbot Helm Chart

This Helm chart deploys the Hummingbot Dashboard, Backend API, and EMQX message broker.

## Dashboard

The Hummingbot Dashboard allows users to interact with the bot's functionalities through a web-based UI.

### Configuration

- **Image**: `hummingbot/dashboard:latest`
- **Replica Count**: `1`
- **Service Type**: `ClusterIP`
- **Service Port**: `8501`

### Environment Variables

- `AUTH_SYSTEM_ENABLED`: `"False"` - Disable authentication.
- `BACKEND_API_HOST`: `"backend-api"` - Hostname of the backend API.
- `BACKEND_API_PORT`: `"8000"` - Port of the backend API.

### Ports

- **Container Port**: `8501`

### Volume Mounts

- **Credentials**:
    - Mount Path: `/home/dashboard/credentials.yml`
    - Host Path: `./credentials.yml`
- **Pages**:
    - Mount Path: `/home/dashboard/frontend/pages`
    - Host Path: `./pages`

---

## Backend API

The Hummingbot Backend API manages bot logic and interacts with the MQTT broker for communication.

### Configuration

- **Image**: `hummingbot/backend-api:latest`
- **Replica Count**: `1`
- **Service Type**: `ClusterIP`
- **Service Port**: `8000`

### Environment Variables

- `BROKER_HOST`: `"emqx"` - MQTT broker host.
- `BROKER_PORT`: `"1883"` - MQTT broker port.
- **Environment File**: `.env`

### Ports

- **Container Port**: `8000`

### Volume Mounts

- **Bots**:
    - Mount Path: `/backend-api/bots`
    - Host Path: `./bots`
- **Docker Socket**:
    - Mount Path: `/var/run/docker.sock`
    - Host Path: `/var/run/docker.sock`

---

## EMQX

EMQX is an MQTT broker used for real-time messaging between services.

### Configuration

- **Image**: `emqx:5`
- **Replica Count**: `1`
- **Service Type**: `ClusterIP`

### Ports

- `1883`: MQTT (TCP)
- `8883`: MQTT (SSL)
- `8083`: MQTT (WebSocket)
- `8084`: MQTT (WebSocket SSL)
- `8081`: HTTP Management API
- `18083`: HTTP Dashboard
- `61613`: Web Stomp

### Environment Variables

- `EMQX_NAME`: `"emqx"` - EMQX instance name.
- `EMQX_HOST`: `"node1.emqx.local"` - Hostname of the EMQX node.
- `EMQX_CLUSTER__DISCOVERY_STRATEGY`: `"static"` - Static discovery for EMQX cluster.
- `EMQX_CLUSTER__STATIC__SEEDS`: `"[emqx@node1.emqx.local]"` - Seed nodes for EMQX cluster.
- `EMQX_LOADED_PLUGINS`: `"emqx_recon,emqx_retainer,emqx_management,emqx_dashboard"` - Loaded plugins for EMQX.

### Volume Mounts

- **Data**:
    - Mount Path: `/opt/emqx/data`
    - Persistent Volume Claim: `emqx-data-pvc`
- **Log**:
    - Mount Path: `/opt/emqx/log`
    - Persistent Volume Claim: `emqx-log-pvc`
- **Etc**:
    - Mount Path: `/opt/emqx/etc`
    - Persistent Volume Claim: `emqx-etc-pvc`

### Health Check

- **Enabled**: `true`
- **Initial Delay**: `30 seconds`
- **Period**: `5 seconds`
- **Timeout**: `25 seconds`
- **Failure Threshold**: `5`

---