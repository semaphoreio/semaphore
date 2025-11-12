package tools

import (
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

// ConfigureMetrics initializes global metrics configuration for all tools.
// This should be called once during server initialization before registering any tools.
//
// It configures the organization name resolver used for metrics tagging,
// allowing metrics to be tagged with human-readable organization names
// instead of UUIDs.
func ConfigureMetrics(provider internalapi.Provider) {
	shared.ConfigureDefaultOrgResolver(provider)
}
