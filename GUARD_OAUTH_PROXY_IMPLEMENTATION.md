# Guard OAuth Proxy Implementation - Complete

## Overview

Successfully implemented the **Guard OAuth Proxy** pattern for MCP OAuth flows. This approach eliminates the need for Java Keycloak Required Actions and keeps all logic in Elixir.

**Key Achievement:** Pure Elixir implementation - no Java SPI code needed!

## What Was Implemented

### 1. Auth Service Changes

**New Module:** `lib/auth/oauth_session.ex`
- Cachex-backed session management for OAuth flow correlation
- 5-minute TTL for sessions
- Functions: create, get, update, store_grant, store_auth_code, get_by_auth_code, delete

**New Routes:**
- `GET /exauth/oauth/authorize` - Intercepts MCP OAuth authorization requests
- `POST /exauth/oauth/token` - Proxies token exchange and injects grant info
- `POST /exauth/internal/oauth-session/:correlation_id/grant` - Internal API for Guard to store grant_id
- `POST /exauth/internal/oauth-session/:correlation_id/auth-code` - Internal API for Guard to store auth code

**Modified Routes (CRITICAL FIX):**
- `GET /exauth/.well-known/oauth-authorization-server` (id. subdomain) - **Now rewrites OAuth endpoint URLs**
- `GET /exauth/.well-known/oauth-authorization-server` (mcp. subdomain) - **NEW: Added with URL rewriting**
- `GET /exauth/.well-known/oauth-authorization-server/*issuer_path` (id. subdomain) - **Now rewrites OAuth endpoint URLs**

**Discovery Metadata URL Rewriting (OAuth Proxy Pattern):**
- Intercepts Keycloak's OIDC discovery response
- Rewrites `authorization_endpoint` to point to `https://mcp.{domain}/exauth/oauth/authorize`
- Rewrites `token_endpoint` to point to `https://mcp.{domain}/exauth/oauth/token`
- Rewrites `registration_endpoint` to point to `https://mcp.{domain}/oauth/register`
- Keeps `issuer` unchanged (must match JWT issuer claim from Keycloak)
- **This ensures MCP clients use the Auth service's OAuth proxy endpoints instead of going directly to Keycloak**

**Modified:** `lib/auth/application.ex`
- Added `:oauth_sessions` Cachex cache to application supervision tree

**Modified:** `lib/auth.ex` (Router Configuration + All POST Routes)
- **CRITICAL FIX #1:** Added `Plug.Parsers` middleware to parse query parameters and request bodies
  - Without this, `conn.params` was empty and OAuth flow couldn't detect MCP scope
  - Must be configured BEFORE `:match` plug to populate params
- **CRITICAL FIX #2:** Changed all POST routes to use `conn.body_params` instead of `Plug.Conn.read_body(conn)`
  - After adding `Plug.Parsers`, it consumes the request body stream
  - Subsequent `read_body` calls return empty body, breaking DCR and token exchange
  - Now uses `conn.body_params` (already parsed by Plug.Parsers)
  - Affected routes: DCR, token exchange, internal grant/auth-code APIs

**New Helper Function:** `proxy_token_to_keycloak/1`
- Proxies token requests to Keycloak
- Parses and returns token response as Elixir map

### 2. Guard Service Changes

**Modified:** `lib/guard/id/mcp_oauth.ex`

**New Routes:**
- `GET /mcp/oauth/pre-authorize` - Shows grant selection UI (with grant reuse logic)
- `POST /mcp/oauth/pre-authorize` - Creates grant and forwards to Keycloak
- `GET /mcp/oauth/callback` - Handles Keycloak OAuth callback

**Key Functions:**
- `get_current_guard_user/1` - Checks if user is authenticated
- `redirect_to_keycloak_login/2` - Redirects to Keycloak for login
- `show_grant_selection_ui/4` - Displays grant selection HTML form
- `forward_to_keycloak/4` - Updates Auth session and forwards to Keycloak
- `parse_tool_scopes/1` - Parses space-separated scope strings

**Old Routes (Kept for Backward Compat):**
- `GET /mcp/oauth/grant-selection` - Deprecated Required Action route
- `POST /mcp/oauth/grant-selection` - Deprecated Required Action route

## Complete OAuth Flow

```
1. Client → Auth: GET https://mcp.{domain}/exauth/oauth/authorize
   - Auth creates OAuth session with correlation_id
   - Auth redirects to Guard pre-authorize

2. Guard: GET https://id.{domain}/mcp/oauth/pre-authorize?correlation_id=...
   - Checks if user authenticated (Keycloak session)
   - If not: redirects to Keycloak login
   - If yes: checks for existing grant
     - If exists: reuses grant, skips UI
     - If not: shows grant selection form

3. User: Fills grant selection form, clicks "Authorize"

4. Guard: POST https://id.{domain}/mcp/oauth/pre-authorize
   - Creates MCP grant via Guard.McpGrant.Actions.create/1
   - Calls Auth internal API to store grant_id in OAuth session
   - Redirects to Keycloak authorization endpoint

5. Keycloak: User already authenticated, issues auth code immediately
   - Redirects to Guard callback: https://id.{domain}/mcp/oauth/callback

6. Guard: GET https://id.{domain}/mcp/oauth/callback?code=...&state=correlation_id
   - Calls Auth internal API to store auth_code in OAuth session
   - Auth returns client's original redirect_uri and state
   - Guard redirects to client's callback with auth code

7. Client: POST https://mcp.{domain}/exauth/oauth/token
   - Auth proxies request to Keycloak
   - Auth looks up grant_id using auth_code
   - Auth injects mcp_grant_id and mcp_tool_scopes into response
   - Auth cleans up OAuth session

8. Client receives token response:
   {
     "access_token": "...",
     "token_type": "Bearer",
     "expires_in": 3600,
     "refresh_token": "...",
     "mcp_grant_id": "grant-uuid",        ← Injected by Auth
     "mcp_tool_scopes": ["mcp", "..."]    ← Injected by Auth
   }
```

## Keycloak Configuration Required

### 1. Add Guard Callback to MCP Client

In Keycloak Admin Console:

1. Navigate to **Clients** → (your MCP client)
2. Go to **Settings** tab
3. Find **Valid Redirect URIs** field
4. Add: `https://id.{your-domain}/mcp/oauth/callback`
5. Click **Save**

Example:
```
Valid Redirect URIs:
  - http://localhost:*/callback
  - https://id.semaphoreci.com/mcp/oauth/callback   ← ADD THIS
```

### 2. Guard Client (Now Automated via Terraform)

The Guard service needs its own Keycloak client for user authentication during the grant selection flow.

**Status:** ✅ **Automated** - Guard client is now defined in `keycloak/setup/main.tf`

The Terraform configuration creates:
- **Client ID:** `guard`
- **Client Protocol:** openid-connect
- **Access Type:** PUBLIC
- **Valid Redirect URIs:** `https://id.{domain}/oidc/callback*`

**No manual configuration needed** - This will be created automatically when you run:
```bash
cd keycloak/setup
terraform apply
```

### 3. OAuth 2.0 Authorization Server Metadata

No changes needed - Auth service already proxies OIDC discovery at:
- `https://id.{domain}/exauth/.well-known/oauth-authorization-server`

## Environment Variables

No new environment variables required! Existing variables are sufficient:
- `BASE_DOMAIN` - Used by both Auth and Guard services
- `KEYCLOAK_BASE_URL` - Keycloak base URL (optional, defaults to https://id.{domain})

## File Changes Summary

### Auth Service (`/Users/amir/Documents/renderedtext/semaphore/auth/`)

**New Files:**
- `lib/auth/oauth_session.ex` (283 lines)

**Modified Files:**
- `lib/auth.ex` - **CRITICAL FIXES + New Features:**
  - Added `Plug.Parsers` middleware (fixes empty conn.params bug)
  - Fixed 3 discovery routes to rewrite OAuth endpoint URLs
  - Added 4 new OAuth proxy routes
  - Added 1 helper function for token proxying
  - Total: ~220 lines added/modified
- `lib/auth/application.ex` - Added oauth_sessions cache (4 lines)

**Bug Fixes Documentation:**
- `OAUTH_PARAMS_BUG_FIX.md` - Documents the empty conn.params bug and fix

### Guard Service (`/Users/amir/Documents/renderedtext/semaphore/guard/`)

**Modified Files:**
- `lib/guard/id/mcp_oauth.ex` - **CRITICAL FIXES + Proxy Pattern:**
  - Added `Plug.Parsers` middleware (fixes empty conn.params bug)
  - Fixed `redirect_to_keycloak_login/2` to properly URL-encode query parameters
  - Complete refactor for OAuth proxy pattern
  - Total: ~280 lines modified

**Bug Fixes:**
- **URL Encoding Bug**: The `return_to` parameter was not properly encoded, causing query parameters to be misinterpreted
  - Before: `redirect_uri=.../oidc/callback?return_to=/pre-authorize?correlation_id=...&client_id=...`
  - Problem: The `&client_id=...` was interpreted as a top-level parameter, not part of `return_to`
  - After: Uses `URI.encode_query/1` to properly encode all parameters
  - Result: Keycloak receives correct `redirect_uri` with properly encoded `return_to`

### Helm Chart (`/Users/amir/Documents/renderedtext/semaphore/helm-chart/`)

**Modified Files:**
- `templates/emissary-ingress/mappings.yaml` - Added 7 new Emissary mappings for OAuth proxy routes

## Testing Checklist

- [ ] **Auth Service**
  - [ ] OAuth session CRUD operations work
  - [ ] `/exauth/oauth/authorize` intercepts MCP flows
  - [ ] `/exauth/oauth/token` injects grant info
  - [ ] Internal APIs accept Guard's requests

- [ ] **Guard Service**
  - [ ] `/mcp/oauth/pre-authorize` shows UI when user logged in
  - [ ] `/mcp/oauth/pre-authorize` redirects to login when not authenticated
  - [ ] Grant reuse works (existing grants skip UI)
  - [ ] POST creates grant and stores in database
  - [ ] `/mcp/oauth/callback` redirects correctly to client

- [ ] **End-to-End OAuth Flow**
  - [ ] Client can complete full authorization flow
  - [ ] Grant selection UI appears
  - [ ] Token response includes `mcp_grant_id` and `mcp_tool_scopes`
  - [ ] MCP grant is persisted in database
  - [ ] OAuth sessions are cleaned up after token exchange

- [ ] **Keycloak Configuration**
  - [ ] Guard callback URL added to MCP client
  - [ ] Guard client exists for user authentication

## Migration from Required Action Approach

### What to Remove (Eventually)

1. **Keycloak Java SPI:**
   - `/Users/amir/Documents/renderedtext/semaphore/keycloak/custom-spi/`
   - Remove JAR from Keycloak deployments
   - Unregister Required Action from Keycloak Admin UI

2. **Old Guard Routes:**
   - Currently kept for backward compatibility
   - Can be removed after confirming proxy approach works

### Backward Compatibility

The old `/mcp/oauth/grant-selection` routes are kept as DEPRECATED but functional. This allows gradual migration:

1. Deploy new code (both Auth and Guard)
2. Update Keycloak MCP client redirect URIs
3. Test new OAuth proxy flow
4. Once confirmed working, remove old routes and Keycloak SPI

## Advantages of This Approach

✅ **No Java Code** - Everything in Elixir (Auth + Guard)
✅ **No Keycloak Customization** - Only config changes, no JAR deployment
✅ **Standard OAuth Flow** - Mostly compliant with OAuth 2.0/2.1
✅ **Centralized Control** - Guard owns grant selection UX
✅ **Flexible Token Response** - Can add grant info without JWT modification
✅ **Testable** - All logic in Elixir, easier to test than Java SPI
✅ **Grant Reuse** - Existing grants skip UI for better UX

## Known Limitations

⚠️ **Grant Info Not in JWT** - mcp_grant_id is in token response, not JWT claims
   - Clients must parse response to extract grant_id
   - Clients must send grant_id as X-MCP-Grant-ID header on API requests

⚠️ **Extra Redirects** - More hops than standard OAuth
   - Client → Auth → Guard → Keycloak → Guard → Client
   - May feel slightly slower (but likely imperceptible)

⚠️ **Session State in Cachex** - Auth service has stateful component
   - Sessions expire after 5 minutes (sufficient for OAuth flows)
   - TTL prevents stale data accumulation

⚠️ **Inter-Service HTTP Calls** - Guard calls Auth's internal APIs
   - Simple HTTP calls, minimal overhead
   - Could be optimized with shared cache in future if needed

## Next Steps

1. **Deploy Changes**
   - Deploy Auth service with new OAuth session management
   - Deploy Guard service with new pre-authorize routes

2. **Configure Keycloak**
   - Add Guard callback URL to MCP client redirect URIs
   - Verify Guard client exists for user authentication

3. **Test End-to-End**
   - Use real MCP client (e.g., Claude Desktop)
   - Verify full OAuth flow works
   - Confirm token response includes grant info
   - Check grant persistence in database

4. **Monitor & Iterate**
   - Watch logs for OAuth flow progression
   - Monitor Cachex session cleanup (no leaks)
   - Gather user feedback on grant selection UX

5. **Future Enhancements**
   - Add org/project selection checkboxes to grant UI
   - Implement grant management UI (view/revoke grants)
   - Add grant expiration and renewal flows
   - Optimize inter-service calls if needed

## Troubleshooting

### Issue: "Session not found" error

**Cause:** OAuth session expired or correlation_id mismatch
**Solution:** Check session TTL (5 minutes), verify correlation_id passed correctly through redirects

### Issue: Grant not showing in token response

**Cause:** Grant not stored in OAuth session before token exchange
**Solution:** Check Guard logs for "Stored grant" message, verify Auth internal API calls succeed

### Issue: User not authenticated in Guard

**Cause:** Keycloak session expired or Guard session cookie missing
**Solution:** Verify Guard client configuration in Keycloak, check cookie domain settings

### Issue: Infinite redirect loop

**Cause:** Guard callback URL not in Keycloak allowed redirect URIs
**Solution:** Add `https://id.{domain}/mcp/oauth/callback` to MCP client's Valid Redirect URIs

## Support & Documentation

- **Implementation Plan:** `/Users/amir/.claude/plans/guard-oauth-proxy-pattern.md`
- **Phase 4 Original Plan:** `/Users/amir/.claude/plans/encapsulated-sprouting-wolf.md`
- **Guard gRPC Server:** `guard/lib/guard/grpc_servers/mcp_grant_server.ex`
- **MCP Grant Actions:** `guard/lib/guard/mcp_grant/actions.ex`
- **Database Schema:** `guard/priv/repo/migrations/20251223113239_create_mcp_grants.exs`

---

**Implementation Status:** ✅ **COMPLETE**
**Date:** December 23, 2024
**Approach:** Guard OAuth Proxy (No Java Required)
