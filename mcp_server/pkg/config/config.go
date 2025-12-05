// Package config provides global configuration for the MCP server.
package config

var (
	// devMode skips authentication checks when true (for local development)
	devMode = false
	// DevUserID is the user ID used when running in dev mode
	DevUserID = "00000000-0000-0000-0000-000000000000"
)

// SetDevMode enables or disables dev mode (skips auth checks)
func SetDevMode(enabled bool) {
	devMode = enabled
}

// IsDevMode returns true if dev mode is enabled
func IsDevMode() bool {
	return devMode
}
