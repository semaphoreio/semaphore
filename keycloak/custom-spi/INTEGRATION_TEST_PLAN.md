# MCP OAuth Integration Test Plan

## Overview

This document outlines the integration test plan for Phase 4: OAuth Consent Flow Integration.

## Prerequisites

### 1. Build and Deploy Keycloak SPI

```bash
cd /Users/amir/Documents/renderedtext/semaphore/keycloak/custom-spi
mvn clean package
cp target/mcp-grant-action-1.0.0.jar /path/to/keycloak/deployments/
```

### 2. Configure Keycloak

**Register Required Action:**
1. Navigate to Keycloak Admin Console
2. Go to Authentication → Required Actions
3. Click "Register" and select "MCP Grant Selection"
4. Enable the action (check "Enabled")

**Set Environment Variables:**
```bash
export GUARD_BASE_URL=https://id.semaphoreci.com
export KEYCLOAK_BASE_URL=http://localhost:8080
```

### 3. Verify Guard Service

**Check Guard is running:**
```bash
curl http://localhost:4000/health
```

**Verify gRPC endpoints:**
- MCP Grant Create endpoint should be available
- FindExistingGrant endpoint should be available

### 4. Verify Database

```sql
-- Verify mcp_grants table exists
SELECT * FROM mcp_grants LIMIT 1;

-- Verify mcp_grant_orgs table exists
SELECT * FROM mcp_grant_orgs LIMIT 1;

-- Verify mcp_grant_projects table exists
SELECT * FROM mcp_grant_projects LIMIT 1;
```

## Test Scenarios

### Test 1: First-Time OAuth Flow (No Existing Grant)

**Objective:** Verify full OAuth consent flow with grant creation

**Steps:**

1. **Initiate OAuth Authorization Request**
   ```bash
   curl -X GET "http://localhost:8080/auth/realms/semaphore/protocol/openid-connect/auth?\
   client_id=test-mcp-client&\
   response_type=code&\
   scope=openid%20mcp&\
   redirect_uri=http://localhost:3000/callback&\
   state=test-state-123"
   ```

2. **User Authentication**
   - Browser redirects to Keycloak login page
   - Enter username and password
   - Submit authentication form

3. **MCP_GRANT_SELECTION Required Action Triggered**
   - **Expected:** Keycloak checks for "mcp" scope
   - **Expected:** Calls `evaluateTriggers()` in Required Action
   - **Expected:** Finds no existing grant (placeholder returns false)
   - **Expected:** Adds MCP_GRANT_SELECTION to required actions

4. **Redirect to Guard Grant Selection UI**
   - **Expected:** Browser redirects to:
     ```
     https://id.semaphoreci.com/mcp/oauth/grant-selection?
       state={tab_id}&
       client_id=test-mcp-client&
       user_id={keycloak_user_id}&
       scopes=openid%20mcp
     ```
   - **Expected:** Guard UI displays grant selection page
   - **Expected:** Shows client_id and requested scopes

5. **User Authorizes Grant**
   - Click "Authorize Access" button
   - **Expected:** POST request to `/mcp/oauth/grant-selection`
   - **Expected:** Guard maps OIDC user ID to Semaphore user ID
   - **Expected:** Guard creates MCP grant via gRPC
   - **Expected:** Returns grant_id

6. **Guard Redirects to Keycloak**
   - **Expected:** 302 redirect to:
     ```
     http://localhost:8080/auth/realms/semaphore/login-actions/required-action?
       session_code={tab_id}&
       execution=MCP_GRANT_SELECTION&
       mcp_grant_id={grant_id}&
       mcp_tool_scopes=openid%20mcp
     ```

7. **Keycloak Processes Required Action**
   - **Expected:** `processAction()` is called
   - **Expected:** Reads `mcp_grant_id` from query parameters
   - **Expected:** Reads `mcp_tool_scopes` from query parameters
   - **Expected:** Sets session notes:
     - `mcp_grant_id` = {grant_id}
     - `mcp_tool_scopes` = "openid mcp"
   - **Expected:** Marks Required Action as complete
   - **Expected:** Continues OAuth flow

8. **Authorization Code Issued**
   - **Expected:** Keycloak redirects to client callback:
     ```
     http://localhost:3000/callback?code={auth_code}&state=test-state-123
     ```

9. **Token Exchange**
   ```bash
   curl -X POST "http://localhost:8080/auth/realms/semaphore/protocol/openid-connect/token" \
     -d "grant_type=authorization_code" \
     -d "code={auth_code}" \
     -d "client_id=test-mcp-client" \
     -d "client_secret={client_secret}" \
     -d "redirect_uri=http://localhost:3000/callback"
   ```

10. **Verify JWT Claims**
    - **Expected:** JWT includes:
      ```json
      {
        "iss": "http://localhost:8080/auth/realms/semaphore",
        "sub": "{keycloak_user_id}",
        "semaphore_user_id": "{rbac_user_id}",
        "mcp_grant_id": "{grant_id}",
        "mcp_tool_scopes": ["openid", "mcp"]
      }
      ```

11. **Verify Database**
    ```sql
    SELECT * FROM mcp_grants WHERE client_id = 'test-mcp-client';
    ```
    - **Expected:** One grant exists
    - **Expected:** `user_id` matches rbac_user
    - **Expected:** `client_id` = 'test-mcp-client'
    - **Expected:** `tool_scopes` includes 'mcp'
    - **Expected:** `revoked_at` is NULL
    - **Expected:** `created_at` is recent

**Success Criteria:**
- ✅ User successfully authenticates
- ✅ Grant selection UI is shown
- ✅ MCP grant is created in database
- ✅ JWT token includes mcp_grant_id and mcp_tool_scopes
- ✅ No errors in Keycloak logs
- ✅ No errors in Guard logs

---

### Test 2: OAuth Flow with Existing Grant (Grant Reuse)

**Objective:** Verify existing grants are reused without showing UI

**Prerequisites:**
- Complete Test 1 to create initial grant
- Or manually insert grant into database

**Steps:**

1. **Initiate Second OAuth Request (Same Client)**
   ```bash
   curl -X GET "http://localhost:8080/auth/realms/semaphore/protocol/openid-connect/auth?\
   client_id=test-mcp-client&\
   response_type=code&\
   scope=openid%20mcp&\
   redirect_uri=http://localhost:3000/callback&\
   state=test-state-456"
   ```

2. **User Already Authenticated**
   - User has existing Keycloak session
   - **Expected:** Skip login page

3. **MCP_GRANT_SELECTION Checks for Existing Grant**
   - **Expected:** `evaluateTriggers()` is called
   - **Expected:** Calls Guard gRPC `FindExistingGrant` endpoint
   - **Note:** In current Phase 4 implementation, `hasExistingGrant()` returns false (placeholder)
   - **Expected (Future):** Finds existing grant and skips UI

4. **Current Behavior (Placeholder Logic)**
   - **Expected:** Grant selection UI is shown again
   - **Expected:** New grant is created

5. **Future Behavior (When gRPC Integration Complete)**
   - **Expected:** Grant selection UI is skipped
   - **Expected:** Existing grant_id is reused
   - **Expected:** Session notes are set with existing grant_id
   - **Expected:** OAuth flow completes without showing UI

**Success Criteria (Phase 4 - Current):**
- ✅ OAuth flow completes successfully
- ✅ UI is shown (placeholder behavior)
- ⏳ Grant reuse logic deferred (requires gRPC client in Keycloak)

**Success Criteria (Future Enhancement):**
- ✅ Existing grant is detected via gRPC
- ✅ UI is skipped for returning users
- ✅ OAuth flow completes faster

---

### Test 3: OAuth Flow with Non-MCP Scope

**Objective:** Verify Required Action is skipped for non-MCP requests

**Steps:**

1. **Initiate OAuth Request WITHOUT 'mcp' Scope**
   ```bash
   curl -X GET "http://localhost:8080/auth/realms/semaphore/protocol/openid-connect/auth?\
   client_id=regular-client&\
   response_type=code&\
   scope=openid%20email&\
   redirect_uri=http://localhost:3000/callback&\
   state=test-state-789"
   ```

2. **User Authentication**
   - Enter credentials and login

3. **MCP_GRANT_SELECTION Should Be Skipped**
   - **Expected:** `evaluateTriggers()` checks scope
   - **Expected:** Scope does not contain "mcp"
   - **Expected:** Required Action is NOT added
   - **Expected:** OAuth flow proceeds normally

4. **Authorization Code Issued**
   - **Expected:** Redirect to callback without Grant Selection UI

5. **Token Exchange**
   - **Expected:** JWT does NOT include mcp_grant_id or mcp_tool_scopes

**Success Criteria:**
- ✅ Required Action is skipped
- ✅ No grant created
- ✅ OAuth flow completes normally
- ✅ JWT does not include MCP claims

---

### Test 4: Error Handling - User Not Found

**Objective:** Verify graceful error handling when OIDC user not in rbac_users

**Steps:**

1. **Create Keycloak User Without rbac_user Entry**
   - Create user in Keycloak Admin UI
   - Do NOT create corresponding rbac_user

2. **Initiate OAuth Flow**
   - Authenticate as the new user
   - Grant Selection UI should be shown

3. **User Clicks Authorize**
   - **Expected:** Guard tries to map OIDC user to rbac_user
   - **Expected:** `fetch_by_oidc_id()` returns `{:error, :not_found}`
   - **Expected:** 404 error page is shown
   - **Expected:** Error message: "Could not find user account"

**Success Criteria:**
- ✅ Error is caught gracefully
- ✅ User-friendly error page is shown
- ✅ No 500 errors
- ✅ Error is logged in Guard logs

---

### Test 5: Error Handling - Grant Creation Failure

**Objective:** Verify error handling when grant creation fails

**Steps:**

1. **Simulate Database Failure**
   - Temporarily break database connection
   - Or insert invalid data to trigger constraint violation

2. **Complete OAuth Flow**
   - Authenticate and reach Grant Selection UI
   - Click "Authorize Access"

3. **Grant Creation Fails**
   - **Expected:** `Actions.create()` returns `{:error, reason}`
   - **Expected:** 500 error page is shown
   - **Expected:** Error message: "Failed to create MCP grant"
   - **Expected:** Error details in response

**Success Criteria:**
- ✅ Error is caught gracefully
- ✅ User-friendly error page is shown
- ✅ Error details are logged
- ✅ No data corruption

---

## Logs to Monitor

### Keycloak Logs

```bash
tail -f /path/to/keycloak/data/log/keycloak.log | grep -E "MCP|grant"
```

**Expected Log Messages:**
```
INFO  [com.semaphoreci.keycloak.McpGrantSelectionRequiredAction] Evaluating MCP grant selection for user=..., client=...
INFO  [com.semaphoreci.keycloak.McpGrantSelectionRequiredAction] No existing grant for user=..., client=... - triggering grant selection
INFO  [com.semaphoreci.keycloak.McpGrantSelectionRequiredAction] Redirecting to MCP grant selection UI: ...
INFO  [com.semaphoreci.keycloak.McpGrantSelectionRequiredAction] Processing MCP grant selection action for user=...
INFO  [com.semaphoreci.keycloak.McpGrantSelectionRequiredAction] Set session note mcp_grant_id=...
INFO  [com.semaphoreci.keycloak.McpGrantSelectionRequiredAction] Set session note mcp_tool_scopes=...
```

### Guard Logs

```bash
tail -f /path/to/guard/logs/console.log | grep -E "McpOAuth|mcp_grant"
```

**Expected Log Messages:**
```
[info] [McpOAuth] Grant selection requested for client=..., user=..., scopes=...
[info] [McpOAuth] Processing grant creation for client=..., user=...
[info] [McpOAuth] Created grant ... for user=..., client=...
[info] [McpOAuth] Redirecting back to Keycloak: ...
[info] grpc.mcp_grant.create: user_id=..., client_id=...
```

## Debugging Tips

### 1. Enable Debug Logging in Keycloak

Edit `standalone.xml`:
```xml
<logger category="com.semaphoreci.keycloak">
    <level name="DEBUG"/>
</logger>
```

### 2. Check Keycloak Session Notes

Use Admin API to inspect session:
```bash
kcadm.sh get users/{user-id}/sessions --fields id,username,notes
```

### 3. Verify JWT Mappers

In Keycloak Admin Console:
- Navigate to Clients → {client-id} → Mappers
- Verify "mcp_grant_id" and "mcp_tool_scopes" mappers exist
- Check "User Session Note" claim source

### 4. Test Guard gRPC Endpoints

```bash
# Test FindExistingGrant
grpcurl -d '{"user_id": "...", "client_id": "test-mcp-client"}' \
  localhost:50051 \
  internal_api.mcp_grant.McpGrantService/FindExistingGrant
```

### 5. Check Database State

```sql
-- List all grants
SELECT id, user_id, client_id, created_at, revoked_at
FROM mcp_grants
ORDER BY created_at DESC;

-- Check for duplicate grants (should be prevented)
SELECT user_id, client_id, COUNT(*)
FROM mcp_grants
WHERE revoked_at IS NULL
GROUP BY user_id, client_id
HAVING COUNT(*) > 1;
```

## Success Criteria for Phase 4

Phase 4 is complete when:

- ✅ User can complete OAuth flow with grant selection
- ✅ Grant Selection UI is shown during first-time authorization
- ✅ MCP grant is created in database
- ✅ JWT tokens include `mcp_grant_id` from session notes
- ✅ JWT tokens include `mcp_tool_scopes` from session notes
- ✅ OAuth state correlation works correctly (tab_id → callback)
- ✅ Keycloak Required Action properly redirects and returns
- ✅ Error handling works gracefully
- ✅ No errors in production logs

## Known Limitations (Phase 4)

- ⚠️ Grant reuse logic uses placeholder (always shows UI)
  - Requires gRPC client in Keycloak Java code
  - Will be enhanced in future iteration

- ⚠️ Grant Selection UI is minimal (no org/project selection)
  - Creates grant with empty org_grants and project_grants
  - Full UI deferred to future phase

- ⚠️ Session notes set via query parameters, not Admin API
  - Admin API approach was attempted but not supported
  - Current approach is cleaner and more reliable

## Next Steps

After Phase 4 integration testing:

- **Phase 2:** Front UI for grant management (view/revoke grants in user dashboard)
- **Phase 3:** MCP server enforcement (validate grants on tool execution)
- **Enhancement:** Implement full gRPC client in Keycloak for grant reuse
- **Enhancement:** Build rich Grant Selection UI with org/project checkboxes
