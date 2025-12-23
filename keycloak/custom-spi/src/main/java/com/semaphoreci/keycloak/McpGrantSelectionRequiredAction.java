package com.semaphoreci.keycloak;

import org.keycloak.authentication.RequiredActionContext;
import org.keycloak.authentication.RequiredActionProvider;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.UserModel;
import org.jboss.logging.Logger;

import javax.ws.rs.core.Response;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Keycloak Required Action for MCP OAuth grant selection.
 *
 * This Required Action intercepts the OAuth flow after authentication
 * and redirects to Guard's grant selection UI if the user doesn't have
 * an existing valid grant for the requesting client.
 */
public class McpGrantSelectionRequiredAction implements RequiredActionProvider {

    public static final String PROVIDER_ID = "MCP_GRANT_SELECTION";
    private static final Logger logger = Logger.getLogger(McpGrantSelectionRequiredAction.class);

    @Override
    public void evaluateTriggers(RequiredActionContext context) {
        // Check if this is an MCP OAuth request
        String scope = context.getAuthenticationSession().getClientNote("scope");

        if (scope == null || !scope.contains("mcp")) {
            logger.debugf("Skipping MCP grant selection - scope does not contain 'mcp': %s", scope);
            return; // Not an MCP request, skip
        }

        String clientId = context.getAuthenticationSession().getClient().getClientId();
        UserModel user = context.getUser();

        logger.infof("Evaluating MCP grant selection for user=%s, client=%s", user.getId(), clientId);

        // Check if user has existing valid grant for this client
        // For now, we'll implement a simple check - in production this would call Guard gRPC
        String semaphoreUserId = user.getFirstAttribute("semaphore_user_id");

        if (semaphoreUserId != null && hasExistingGrant(context.getSession(), semaphoreUserId, clientId)) {
            logger.infof("Found existing grant for user=%s, client=%s - reusing", semaphoreUserId, clientId);

            // Reuse existing grant - session notes will be set in requiredActionChallenge
            // by calling Guard API to get the grant details
            // For now, we skip session notes and trigger the action to fetch grant
            context.getUser().addRequiredAction(PROVIDER_ID);
        } else {
            logger.infof("No existing grant for user=%s, client=%s - triggering grant selection",
                         semaphoreUserId, clientId);
            // No grant - trigger Required Action to show grant selection UI
            context.getUser().addRequiredAction(PROVIDER_ID);
        }
    }

    @Override
    public void requiredActionChallenge(RequiredActionContext context) {
        // Build redirect URL to Guard Grant Selection UI
        String guardBaseUrl = System.getenv("GUARD_BASE_URL");
        if (guardBaseUrl == null) {
            guardBaseUrl = "https://id.semaphoreci.com"; // Default
        }

        String state = context.getAuthenticationSession().getTabId(); // Use tab ID as state
        String clientId = context.getAuthenticationSession().getClient().getClientId();
        String userId = context.getUser().getId();
        String scopes = context.getAuthenticationSession().getClientNote("scope");

        if (scopes == null) {
            scopes = "mcp";
        }

        try {
            String redirectUrl = String.format(
                "%s/mcp/oauth/grant-selection?state=%s&client_id=%s&user_id=%s&scopes=%s",
                guardBaseUrl,
                URLEncoder.encode(state, StandardCharsets.UTF_8.name()),
                URLEncoder.encode(clientId, StandardCharsets.UTF_8.name()),
                URLEncoder.encode(userId, StandardCharsets.UTF_8.name()),
                URLEncoder.encode(scopes, StandardCharsets.UTF_8.name())
            );

            logger.infof("Redirecting to MCP grant selection UI: %s", redirectUrl);

            // Redirect to Guard grant selection UI
            Response response = Response.status(Response.Status.FOUND)
                .location(URI.create(redirectUrl))
                .build();

            context.challenge(response);
        } catch (Exception e) {
            logger.error("Error building redirect URL for MCP grant selection", e);
            context.failure();
        }
    }

    @Override
    public void processAction(RequiredActionContext context) {
        // This is called when Guard redirects back after grant selection
        // Read grant_id and tool_scopes from query parameters and set session notes

        logger.infof("Processing MCP grant selection action for user=%s", context.getUser().getId());

        // Get grant_id and tool_scopes from query parameters
        String grantId = context.getHttpRequest().getUri().getQueryParameters().getFirst("mcp_grant_id");
        String toolScopes = context.getHttpRequest().getUri().getQueryParameters().getFirst("mcp_tool_scopes");

        if (grantId != null && !grantId.isEmpty()) {
            // Set session notes - these will be read by JWT mappers
            context.getAuthenticationSession().setUserSessionNote("mcp_grant_id", grantId);
            logger.infof("Set session note mcp_grant_id=%s", grantId);

            if (toolScopes != null && !toolScopes.isEmpty()) {
                context.getAuthenticationSession().setUserSessionNote("mcp_tool_scopes", toolScopes);
                logger.infof("Set session note mcp_tool_scopes=%s", toolScopes);
            }

            // Mark the Required Action as complete
            context.getUser().removeRequiredAction(PROVIDER_ID);
            context.success();
        } else {
            logger.error("Missing mcp_grant_id in callback from Grant Selection UI");
            context.failure();
        }
    }

    @Override
    public void close() {
        // No resources to close
    }

    /**
     * Check if user has an existing valid grant for the client.
     *
     * This is a placeholder - in production this would call Guard gRPC service.
     * For Phase 4, we'll always return false to trigger grant selection UI.
     */
    private boolean hasExistingGrant(KeycloakSession session, String semaphoreUserId, String clientId) {
        // TODO: Call Guard gRPC FindExistingGrant endpoint
        // For now, always return false to show grant selection UI
        return false;
    }
}
