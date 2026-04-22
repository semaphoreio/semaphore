package shared

import (
	"context"
	"fmt"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

const (
	readToolsFeatureFlag      = "mcp_server_read_tools"
	writeToolsFeatureFlag     = "mcp_server_write_tools"
	artifactsToolsFeatureFlag = "mcp_server_artifacts_tools"
	artifactsJobLogsFlag      = "artifacts_job_logs"
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
		return fmt.Errorf("Semaphore MCP write tools are disabled for this organization. Please contact support if you believe this is an error.")
	}

	return nil
}

// EnsureArtifactsToolsFeature verifies that the organization has artifact MCP tools enabled.
func EnsureArtifactsToolsFeature(ctx context.Context, api internalapi.Provider, orgID string) error {
	featureClient := api.Features()
	if featureClient == nil {
		return fmt.Errorf("Semaphore MCP tools are temporarily unavailable. Please try again later.")
	}

	state, err := featureClient.FeatureState(orgID, artifactsToolsFeatureFlag)
	if err != nil {
		return fmt.Errorf("We couldn't verify access to artifact operations right now. Please try again in a few moments.")
	}

	if state != feature.Enabled {
		return fmt.Errorf("Semaphore artifact operations are disabled for this organization. Please contact support if you believe this is an error.")
	}

	return nil
}

// EnsureArtifactsJobLogsFeature verifies that uploaded artifact-backed job logs are enabled.
func EnsureArtifactsJobLogsFeature(ctx context.Context, api internalapi.Provider, orgID string) error {
	featureClient := api.Features()
	if featureClient == nil {
		return fmt.Errorf("Semaphore MCP tools are temporarily unavailable. Please try again later.")
	}

	state, err := featureClient.FeatureState(orgID, artifactsJobLogsFlag)
	if err != nil {
		return fmt.Errorf("We couldn't verify access to artifact-backed job logs right now. Please try again in a few moments.")
	}

	if state != feature.Enabled {
		return fmt.Errorf("Semaphore uploaded full job logs are disabled for this organization. Please contact support if you believe this is an error.")
	}

	return nil
}

// EnsureArtifactsToolsOrJobLogsFeature verifies that at least one full-log artifact feature is enabled.
func EnsureArtifactsToolsOrJobLogsFeature(ctx context.Context, api internalapi.Provider, orgID string) error {
	featureClient := api.Features()
	if featureClient == nil {
		return fmt.Errorf("Semaphore MCP tools are temporarily unavailable. Please try again later.")
	}

	artifactsToolsState, artifactsToolsErr := featureClient.FeatureState(orgID, artifactsToolsFeatureFlag)
	if artifactsToolsErr == nil && artifactsToolsState == feature.Enabled {
		return nil
	}

	jobLogsState, jobLogsErr := featureClient.FeatureState(orgID, artifactsJobLogsFlag)
	if jobLogsErr == nil && jobLogsState == feature.Enabled {
		return nil
	}

	if artifactsToolsErr != nil && jobLogsErr != nil {
		return fmt.Errorf("We couldn't verify access to full job logs right now. Please try again in a few moments.")
	}

	if artifactsToolsErr != nil || jobLogsErr != nil {
		return fmt.Errorf("We couldn't fully verify access to full job logs right now. Please try again in a few moments.")
	}

	return fmt.Errorf("Semaphore full job logs are disabled for this organization. Enable mcp_server_artifacts_tools or artifacts_job_logs and try again.")
}
