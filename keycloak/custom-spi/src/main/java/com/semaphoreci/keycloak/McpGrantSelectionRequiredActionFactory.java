package com.semaphoreci.keycloak;

import org.keycloak.Config;
import org.keycloak.authentication.RequiredActionFactory;
import org.keycloak.authentication.RequiredActionProvider;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;

/**
 * Factory for creating MCP Grant Selection Required Action instances.
 */
public class McpGrantSelectionRequiredActionFactory implements RequiredActionFactory {

    @Override
    public RequiredActionProvider create(KeycloakSession session) {
        return new McpGrantSelectionRequiredAction();
    }

    @Override
    public String getId() {
        return McpGrantSelectionRequiredAction.PROVIDER_ID;
    }

    @Override
    public String getDisplayText() {
        return "MCP Grant Selection";
    }

    @Override
    public void init(Config.Scope config) {
        // No initialization needed
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
        // No post-initialization needed
    }

    @Override
    public void close() {
        // No resources to close
    }
}
