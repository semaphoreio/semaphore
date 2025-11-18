package shared

import (
	"context"
	"fmt"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

const (
	readToolsFeatureFlag  = "mcp_server_read_tools"
	writeToolsFeatureFlag = "mcp_server_write_tools"
)

// EnsureReadToolsFeature verifies that the organization has the AI read tools feature enabled.
func EnsureReadToolsFeature(ctx context.Context, api internalapi.Provider, orgID string) error {
	featureClient := api.Features()
	if featureClient == nil {
		return fmt.Errorf("Semaphore MCP tools are temporarily unavailable. Please try again later.")
	}

	state, err := featureClient.FeatureState(orgID, readToolsFeatureFlag)
	if err != nil {
		return fmt.Errorf("We couldn't verify access to Semaphore MCP tools right now. Please try again in a few moments.")
	}

	if state != feature.Enabled {
		return fmt.Errorf("Semaphore MCP read tools are disabled for this organization. Please contact support if you believe this is an error.")
	}

	return nil
}

// EnsureWriteToolsFeature verifies that the organization has the AI write tools feature enabled.
func EnsureWriteToolsFeature(ctx context.Context, api internalapi.Provider, orgID string) error {
	featureClient := api.Features()
	if featureClient == nil {
		return fmt.Errorf("Semaphore MCP tools are temporarily unavailable. Please try again later.")
	}

	state, err := featureClient.FeatureState(orgID, writeToolsFeatureFlag)
	if err != nil {
		return fmt.Errorf("We couldn't verify access to Semaphore MCP tools right now. Please try again in a few moments.")
	}

	if state != feature.Enabled {
		return fmt.Errorf("Semaphore MCP write tools actions are disabled for this organization. Please contact support if you believe this is an error.")
	}

	return nil
}
