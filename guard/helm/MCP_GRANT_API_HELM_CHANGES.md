# MCP Grant API Helm Configuration Changes

## Overview

This document describes the Helm chart changes made to enable the MCP Grant API gRPC server in the Guard service.

## Changes Made

### 1. New Deployment: `mcp-grant-api-dpl.yaml`

Created a dedicated deployment for the MCP Grant API gRPC server.

**File:** `helm/templates/mcp-grant-api-dpl.yaml`

**Key Configuration:**
- **Replicas:** Configurable via `{{ .Values.mcpGrantApi.replicas }}`
- **Environment Variables:**
  - `START_GRPC_MCP_GRANT_API=true` - Enables the MCP Grant gRPC server
  - `START_GPRC_GUARD_API=false` - Disables the main Guard API
  - `START_GPRC_HEALTH_CHECK=true` - Enables health checks
  - `GRPC_API=true` - Enables gRPC mode
- **Resources:** Configurable via `{{ .Values.mcpGrantApi.resources }}`
- **Database Pool Size:** Configurable via `{{ .Values.mcpGrantApi.dbPoolSize }}`
- **Port:** Exposes port 50051 for gRPC
- **Probes:** gRPC-based startup, readiness, and liveness probes

**Deployment Strategy:**
- Rolling update with 25% max surge and 0 max unavailable
- Only deployed when `minimalDeployment` is false

### 2. New Service: `guard-mcp-grant-api`

Added Kubernetes service to expose the MCP Grant API deployment.

**File:** `helm/templates/service.yaml`

**Configuration:**
- **Service Name:** `{{ .Chart.Name }}-mcp-grant-api` (e.g., `guard-mcp-grant-api`)
- **Type:** NodePort
- **Selector:** Routes to `guard-mcp-grant-api` pods (or `guard` in minimal deployment)
- **Port:** 50051 (gRPC)

### 3. Values Configuration

Added MCP Grant API configuration section to values.yaml.

**File:** `helm/values.yaml`

```yaml
mcpGrantApi:
  logging:
    level: info
  replicas: 1
  dbPoolSize: 2
  resources:
    limits:
      cpu: 100m
      memory: 300Mi
    requests:
      cpu: 25m
      memory: 150Mi
```

**Tunable Parameters:**
- `mcpGrantApi.logging.level` - Log level (info, debug, warn, error)
- `mcpGrantApi.replicas` - Number of replicas for horizontal scaling
- `mcpGrantApi.dbPoolSize` - Database connection pool size
- `mcpGrantApi.resources.limits` - CPU and memory limits
- `mcpGrantApi.resources.requests` - CPU and memory requests

### 4. Main API Deployment Update

Enabled MCP Grant API on the main Guard API deployment.

**File:** `helm/templates/dpl-api.yaml`

**Added Environment Variable:**
```yaml
- name: START_GRPC_MCP_GRANT_API
  value: "true"
```

This allows the main Guard API to also serve MCP Grant API requests, providing redundancy.

### 5. Minimal Deployment Update

Enabled MCP Grant API in the minimal deployment (used for development).

**File:** `helm/templates/minimal-deployment.yaml`

**Added Environment Variable:**
```yaml
- name: START_GRPC_MCP_GRANT_API
  value: "true"
```

The minimal deployment runs all Guard services in a single container for local development.

## Deployment Architecture

### Production Deployment (minimalDeployment: false)

```
┌─────────────────────────────────────────────────────────────┐
│                       Guard Namespace                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐     ┌──────────────────┐             │
│  │  guard-api       │     │ guard-mcp-grant  │             │
│  │                  │     │     -api         │             │
│  │  Port: 50051     │     │  Port: 50051     │             │
│  │  START_GRPC:     │     │  START_GRPC:     │             │
│  │  - GUARD_API ✓   │     │  - MCP_GRANT ✓   │             │
│  │  - MCP_GRANT ✓   │     │  - GUARD_API ✗   │             │
│  └────────┬─────────┘     └────────┬─────────┘             │
│           │                        │                         │
│           │                        │                         │
│  ┌────────▼────────┐      ┌────────▼─────────┐             │
│  │ guard Service   │      │ guard-mcp-grant  │             │
│  │ (NodePort)      │      │ -api Service     │             │
│  │ Port: 50051     │      │ (NodePort)       │             │
│  └─────────────────┘      │ Port: 50051      │             │
│                            └──────────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- **Dedicated MCP Grant API pods:** Separate deployment for scalability
- **Main API also serves MCP Grant:** Redundancy and backward compatibility
- **Independent scaling:** Each deployment can scale independently

### Minimal Deployment (minimalDeployment: true)

```
┌─────────────────────────────────────┐
│        Guard Namespace              │
├─────────────────────────────────────┤
│                                     │
│  ┌────────────────────────────┐    │
│  │  guard (all-in-one)        │    │
│  │                            │    │
│  │  Port: 50051               │    │
│  │  START_GRPC:               │    │
│  │  - GUARD_API ✓             │    │
│  │  - AUTH_API ✓              │    │
│  │  - USER_API ✓              │    │
│  │  - ORGANIZATION_API ✓      │    │
│  │  - INSTANCE_CONFIG_API ✓   │    │
│  │  - MCP_GRANT_API ✓         │    │
│  └──────────┬─────────────────┘    │
│             │                       │
│  ┌──────────▼─────────────┐        │
│  │  guard Service         │        │
│  │  (NodePort)            │        │
│  │  Port: 50051           │        │
│  └────────────────────────┘        │
└─────────────────────────────────────┘
```

**Key Points:**
- All gRPC APIs run in single container
- Used for local development and testing
- Lower resource footprint

## Environment Variables

The MCP Grant API is controlled by the following environment variable:

- **`START_GRPC_MCP_GRANT_API`** - Set to `"true"` to enable the MCP Grant gRPC server

When enabled, the Guard application will start the `Guard.GrpcServers.McpGrantServer` module, which exposes these RPC methods:

- `Create` - Create a new MCP grant
- `List` - List MCP grants for a user
- `Describe` - Get details of a specific grant
- `Update` - Update grant permissions
- `Delete` - Delete a grant
- `Revoke` - Revoke a grant (soft delete)
- `CheckOrgAccess` - Check if grant allows org access
- `CheckProjectAccess` - Check if grant allows project access
- `GetGrant` - Get grant with validity check
- `FindExistingGrant` - Find existing valid grant for user + client

## Database Configuration

The MCP Grant API connects to the Guard PostgreSQL database using these tables:

- `mcp_grants` - Main grants table
- `mcp_grant_orgs` - Organization-level permissions
- `mcp_grant_projects` - Project-level permissions

**Database Pool Size:**
- Default: 2 connections
- Configurable via `mcpGrantApi.dbPoolSize`

**Migrations:**
- Migration: `20251223113239_create_mcp_grants.exs`
- Automatically applied on pod startup via init container

## Resource Recommendations

### Development
```yaml
mcpGrantApi:
  replicas: 1
  dbPoolSize: 2
  resources:
    limits:
      cpu: 100m
      memory: 300Mi
    requests:
      cpu: 25m
      memory: 150Mi
```

### Production (Low Traffic)
```yaml
mcpGrantApi:
  replicas: 2
  dbPoolSize: 5
  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 50m
      memory: 256Mi
```

### Production (High Traffic)
```yaml
mcpGrantApi:
  replicas: 3
  dbPoolSize: 10
  resources:
    limits:
      cpu: 500m
      memory: 1Gi
    requests:
      cpu: 100m
      memory: 512Mi
```

## Deployment Steps

### 1. Update Helm Values (Optional)

If you need to customize the configuration:

```bash
vim guard/helm/values.yaml
```

Modify `mcpGrantApi` section as needed.

### 2. Deploy with Helm

**For production deployment:**
```bash
helm upgrade guard ./helm \
  --namespace semaphore \
  --set global.development.minimalDeployment=false \
  --set mcpGrantApi.replicas=2
```

**For development/minimal deployment:**
```bash
helm upgrade guard ./helm \
  --namespace semaphore \
  --set global.development.minimalDeployment=true
```

### 3. Verify Deployment

**Check pods are running:**
```bash
kubectl get pods -n semaphore -l app=guard-mcp-grant-api
```

**Check service is created:**
```bash
kubectl get svc -n semaphore guard-mcp-grant-api
```

**Check logs:**
```bash
kubectl logs -n semaphore -l app=guard-mcp-grant-api --tail=50 -f
```

**Expected log output:**
```
[info] Starting Guard.GrpcServers.McpGrantServer on port 50051
[info] MCP Grant API server started successfully
```

### 4. Test gRPC Endpoint

**Port-forward to test locally:**
```bash
kubectl port-forward -n semaphore svc/guard-mcp-grant-api 50051:50051
```

**Test with grpcurl:**
```bash
# List services
grpcurl -plaintext localhost:50051 list

# Expected output should include:
# internal_api.mcp_grant.McpGrantService

# Test FindExistingGrant
grpcurl -plaintext -d '{
  "user_id": "00000000-0000-0000-0000-000000000000",
  "client_id": "test-client"
}' localhost:50051 internal_api.mcp_grant.McpGrantService/FindExistingGrant
```

## Troubleshooting

### Pod Fails to Start

**Check logs:**
```bash
kubectl logs -n semaphore -l app=guard-mcp-grant-api
```

**Common issues:**
- Database connection failure (check `POSTGRES_DB_*` env vars)
- Migration failure (check init container logs)
- Port conflict (check if port 50051 is already in use)

### Service Not Accessible

**Check service exists:**
```bash
kubectl get svc -n semaphore guard-mcp-grant-api
```

**Check endpoints:**
```bash
kubectl get endpoints -n semaphore guard-mcp-grant-api
```

If endpoints list is empty, pods are not ready. Check pod status and logs.

### gRPC Calls Failing

**Check gRPC health:**
```bash
grpc-health-probe -addr=guard-mcp-grant-api.semaphore.svc.cluster.local:50051
```

**Check environment variable:**
```bash
kubectl exec -n semaphore -it <pod-name> -- env | grep START_GRPC_MCP_GRANT_API
```

Should output: `START_GRPC_MCP_GRANT_API=true`

## Integration with Other Services

### Auth Service

The Auth service uses the MCP Grant API to validate MCP OAuth tokens.

**Connection:**
```
Auth Service → guard-mcp-grant-api:50051 → GetGrant RPC
```

### Keycloak Required Action

The Keycloak MCP Grant Selection Required Action calls the Guard MCP Grant API.

**Connection:**
```
Keycloak Required Action → guard-mcp-grant-api:50051 → FindExistingGrant RPC
```

**Note:** This requires gRPC client configuration in Keycloak Java code (future enhancement).

### Guard ID API

The Guard ID API (MCP OAuth controller) uses the MCP Grant API to create grants.

**Connection:**
```
Guard ID API → Guard.McpGrant.Actions.create → Database
```

This is an in-process call, not gRPC.

## Monitoring

### Metrics

If StatsD is enabled, the MCP Grant API emits these metrics:

- `grpc.mcp_grant.create` - Grant creation requests
- `grpc.mcp_grant.list` - Grant list requests
- `grpc.mcp_grant.describe` - Grant describe requests
- `grpc.mcp_grant.update` - Grant update requests
- `grpc.mcp_grant.delete` - Grant delete requests
- `grpc.mcp_grant.revoke` - Grant revoke requests
- `grpc.mcp_grant.check_org_access` - Org access check requests
- `grpc.mcp_grant.check_project_access` - Project access check requests
- `grpc.mcp_grant.get_grant` - Get grant requests
- `grpc.mcp_grant.find_existing_grant` - Find existing grant requests

### Health Checks

**Kubernetes Probes:**
- **Startup Probe:** gRPC on port 50051, 30 attempts
- **Readiness Probe:** gRPC on port 50051, every 10s
- **Liveness Probe:** gRPC on port 50051, every 10s

**Manual Health Check:**
```bash
grpc-health-probe -addr=localhost:50051
```

## Security Considerations

### Network Policies

Ensure network policies allow:
- Auth service → MCP Grant API (port 50051)
- Keycloak → MCP Grant API (port 50051) - if using gRPC client
- Guard ID API → MCP Grant API (in-process, not network)

### RBAC

The MCP Grant API uses the Guard RBAC system. Ensure:
- Users have appropriate permissions to create/update/delete grants
- Service accounts have proper gRPC access permissions

### TLS

For production deployments, enable TLS for gRPC:
```yaml
env:
  - name: GRPC_TLS_ENABLED
    value: "true"
  - name: GRPC_TLS_CERT_PATH
    value: "/certs/tls.crt"
  - name: GRPC_TLS_KEY_PATH
    value: "/certs/tls.key"
```

## Related Documentation

- **Phase 4 Implementation Plan:** `/Users/amir/.claude/plans/encapsulated-sprouting-wolf.md`
- **Integration Test Plan:** `/Users/amir/Documents/renderedtext/semaphore/keycloak/custom-spi/INTEGRATION_TEST_PLAN.md`
- **Keycloak SPI README:** `/Users/amir/Documents/renderedtext/semaphore/keycloak/custom-spi/README.md`
- **Guard gRPC Server:** `lib/guard/grpc_servers/mcp_grant_server.ex`
- **Database Migration:** `priv/repo/migrations/20251223113239_create_mcp_grants.exs`
