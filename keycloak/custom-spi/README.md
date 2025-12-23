# MCP Grant Selection Required Action

Keycloak Required Action SPI for MCP OAuth grant selection flow.

## Overview

This Required Action intercepts the OAuth authorization flow when a client requests the `mcp` scope. It checks if the user has an existing valid grant for the requesting client and either:
- **Reuses the existing grant** (skips UI) if a valid grant exists
- **Redirects to Guard's grant selection UI** if no grant exists

## Components

- `McpGrantSelectionRequiredAction.java` - Main Required Action implementation
- `McpGrantSelectionRequiredActionFactory.java` - Factory for SPI registration
- `META-INF/services/org.keycloak.authentication.RequiredActionProvider` - SPI registration file

## Build

Build the JAR using Maven:

```bash
cd /Users/amir/Documents/renderedtext/semaphore/keycloak/custom-spi
mvn clean package
```

This produces: `target/mcp-grant-action-1.0.0.jar`

## Deploy

### Option 1: Keycloak Deployments Directory

Copy the JAR to Keycloak's deployments directory:

```bash
cp target/mcp-grant-action-1.0.0.jar /path/to/keycloak/deployments/
```

Keycloak will auto-deploy the JAR on startup or hot-reload it.

### Option 2: Keycloak Providers Directory

For production deployments:

```bash
cp target/mcp-grant-action-1.0.0.jar /path/to/keycloak/providers/
/path/to/keycloak/bin/kc.sh build
```

## Configuration

### 1. Register Required Action

In Keycloak Admin Console:

1. Navigate to **Authentication** → **Required Actions**
2. Click **Register**
3. Select **MCP Grant Selection** from the dropdown
4. Click **OK**

### 2. Enable Required Action

1. Find **MCP Grant Selection** in the Required Actions list
2. Check **Enabled**
3. Check **Default Action** (optional - makes it apply to all users)

### 3. Configure Environment Variables

Set in Keycloak deployment:

```bash
GUARD_BASE_URL=https://id.semaphoreci.com
```

This URL is used to construct the redirect to Guard's grant selection UI.

## OAuth Flow Integration

When an OAuth client requests authorization with `scope=mcp`:

1. User authenticates with Keycloak (if not already logged in)
2. **MCP_GRANT_SELECTION** Required Action is triggered
3. Required Action checks for existing grant via Guard gRPC API
4. If grant exists:
   - Sets session notes: `mcp_grant_id`, `mcp_tool_scopes`
   - Continues OAuth flow (no UI shown)
5. If no grant:
   - Redirects to: `{GUARD_BASE_URL}/mcp/oauth/grant-selection?state={tab_id}&client_id={client}&user_id={user}&scopes={scopes}`
   - User selects organizations and projects
   - Guard creates grant and sets session notes via Keycloak Admin API
   - Redirects back to Keycloak to complete OAuth flow

## Session Notes

The Required Action sets these session notes (read by JWT mappers):

- **mcp_grant_id** - UUID of the MCP grant
- **mcp_tool_scopes** - JSON array of granted tool scopes

These are mapped to JWT claims by Keycloak's protocol mappers (configured in Phase 1).

## Development

### Testing Locally

1. Build and deploy the JAR
2. Restart Keycloak
3. Initiate OAuth flow with `scope=mcp`
4. Observe logs:

```bash
tail -f /path/to/keycloak/data/log/keycloak.log | grep "MCP_GRANT_SELECTION"
```

### Debugging

Enable debug logging in Keycloak:

```bash
/path/to/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin
/path/to/keycloak/bin/kcadm.sh update realms/semaphore -s 'attributes."_browser_header.contentSecurityPolicy"="frame-src '\''self'\''; frame-ancestors '\''self'\''; object-src '\''none'\'';"'
```

Or set log level in `standalone.xml`:

```xml
<logger category="com.semaphoreci.keycloak">
    <level name="DEBUG"/>
</logger>
```

## Dependencies

- Keycloak 23.0.0 (or compatible version)
- Java 11+
- Maven 3.6+

## Phase 4 Implementation

This SPI is part of **Phase 4: OAuth Consent Flow Integration** for the MCP Permissions System.

**Related Components:**
- Guard Grant Selection UI: `guard/lib/guard/id/mcp_oauth.ex`
- Grant Reuse Logic: `guard/lib/guard/mcp_grant/actions.ex`
- gRPC API: `guard/lib/guard/grpc_servers/mcp_grant_server.ex`

**Previous Phase (Complete):**
- Phase 1: Database schema, gRPC API, JWT mappers, Auth service integration

**Next Phases:**
- Phase 2: Front UI for grant management
- Phase 3: MCP server enforcement
