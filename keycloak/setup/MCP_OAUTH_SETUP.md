# MCP OAuth 2.1 Configuration Guide

## Terraform Configuration (Already Applied)

The following MCP OAuth resources are managed by Terraform in `main.tf`:

1. **MCP Client Scope** (`keycloak_openid_client_scope.mcp`)
   - Name: `mcp`
   - Description: "MCP server access scope for OAuth 2.1"
   - Used for Dynamic Client Registration (DCR) and token scoping

2. **Semaphore User ID Mapper** (`keycloak_openid_user_attribute_protocol_mapper.semaphore_user_id`)
   - Maps the `semaphore_user_id` user attribute to JWT claim
   - Mapper name: `semaphore-user-id-mapper`
   - Claim name: `semaphore_user_id`
   - Added to: ID token, access token, userinfo

3. **MCP Audience Mapper** (`keycloak_openid_audience_protocol_mapper.mcp_audience`)
   - Adds `aud` claim to tokens: `https://mcp.{base_domain}`
   - Required for JWT audience validation in auth service

4. **User Profile Attribute** (`semaphore_user_id`)
   - UUID format (36 characters)
   - Admin-only permissions
   - Synced from Guard service during user creation/login

## Manual Configuration Required

### 1. Client Registration Policies (Anonymous Access)

**Location**: Keycloak Admin → Clients → Client Registration (tab) → Anonymous Access (tab)

#### Required Policy: "Allowed Client Scopes"
- **Action**: Edit existing policy
- **Add scope**: `mcp`
- **Why**: Allows DCR clients to request the `mcp` scope

#### CRITICAL Policy: "Default Client Scopes"
- **Action**: Create or edit this policy
- **Add to default scopes**: `mcp`
- **Why**: Ensures all dynamically registered clients get the `mcp` scope by default
- **Effect**: Makes Claude Code and other MCP clients automatically use `scope=mcp` during authorization, even if they don't explicitly request it
- **How to configure**:
  1. Go to: Clients → Client Registration → Anonymous Access
  2. Click "Create policy" or edit existing "Default Client Scopes" policy
  3. Select "Default Client Scopes" from the policy type dropdown
  4. Add `mcp` to the list of default client scopes
  5. Save

#### Optional Policy: "Trusted Hosts"
- **Option A** (Recommended for dev/staging): Delete this policy entirely
- **Option B** (Production): Configure with these host patterns:
  - `10.*` (Kubernetes pod network CIDR)
  - `127.0.0.1`
  - `localhost`

**Important**: The auth service proxies DCR requests to Keycloak, so Keycloak sees the **auth pod IP** (e.g., 10.42.0.x), not the original client IP.

### 2. User Attribute Population

Each user must have the `semaphore_user_id` attribute set before they can use MCP OAuth.

**How to set**:
- **Option A**: Guard service should sync this attribute during login/user creation
- **Option B**: Manually set for testing:
  1. Keycloak Admin → Users → Select user
  2. Attributes tab
  3. Add: `semaphore_user_id` = `<user-uuid-from-guard>`

**Verification**: Check JWT token includes:
```json
{
  "semaphore_user_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "aud": "https://mcp.{domain}",
  "iss": "https://id.{domain}/realms/semaphore",
  "scope": "mcp"
}
```

## Testing MCP OAuth Flow

### 1. OAuth Metadata Discovery
```bash
curl https://mcp.{domain}/.well-known/oauth-authorization-server
```

Expected response:
```json
{
  "resource": "https://mcp.{domain}",
  "authorization_servers": ["https://id.{domain}/realms/semaphore"],
  "scopes_supported": ["mcp"],
  "bearer_methods_supported": ["header"],
  "resource_documentation": "https://docs.semaphoreci.com/mcp"
}
```

### 2. Dynamic Client Registration (DCR)
```bash
curl -X POST https://mcp.{domain}/oauth/register \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "Test MCP Client",
    "redirect_uris": ["http://localhost:3000/callback"]
  }'
```

Expected response (HTTP 201):
```json
{
  "client_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "client_secret": "xxxxxx-secret-xxxxx",
  "client_id_issued_at": 1234567890,
  "client_secret_expires_at": 0,
  "registration_access_token": "...",
  "registration_client_uri": "..."
}
```

### 3. Authorization & Token Exchange

Use the OAuth 2.1 authorization code flow:

1. **Authorization endpoint**: `https://id.{domain}/realms/semaphore/protocol/openid-connect/auth`
2. **Token endpoint**: `https://id.{domain}/realms/semaphore/protocol/openid-connect/token`
3. **Scope**: `mcp`

### 4. MCP Server Request
```bash
curl -X POST https://mcp.{domain}/mcp \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

## Troubleshooting

### DCR fails with "Policy 'Allowed Client Scopes' rejected"
- Verify `mcp` scope is added to the Allowed Client Scopes policy
- Check Client Scopes → mcp exists and is configured correctly

### DCR fails with "Policy 'Trusted Hosts' rejected"
- Option 1: Delete the Trusted Hosts policy (dev/staging)
- Option 2: Add pod network CIDR pattern (e.g., `10.*`)
- Remember: Auth service proxies requests, Keycloak sees auth pod IP

### JWT validation fails with "Token missing semaphore_user_id claim"
- User doesn't have the `semaphore_user_id` attribute set in Keycloak
- Check: Users → {user} → Attributes tab
- Guard service should populate this during login

### JWT validation fails with "Invalid issuer" or "Invalid audience"
- Check auth service logs for expected vs actual values
- Verify `base_domain` variable in Terraform matches deployment
- Audience should be: `https://mcp.{domain}`
- Issuer should be: `https://id.{domain}/realms/semaphore`

## Architecture

```
┌─────────────┐      ┌──────────────┐      ┌──────────────┐
│ MCP Client  │─────▶│  Ambassador  │─────▶│ Auth Service │
│  (Browser)  │      │   (bypass)   │      │  (proxy DCR) │
└─────────────┘      └──────────────┘      └──────┬───────┘
                                                   │
                                                   │ DCR Request
                                                   │ (from auth pod IP)
                                                   ▼
                                            ┌──────────────┐
                                            │  Keycloak    │
                                            │ (validates)  │
                                            └──────────────┘
```

**Key Points**:
- Ambassador bypasses ExtAuth for MCP OAuth endpoints (`.well-known` and `/oauth/register`)
- Auth service proxies DCR to avoid browser CORS issues
- Keycloak sees auth service pod IP, not client IP
- MCP tool requests still go through ExtAuth for JWT validation
