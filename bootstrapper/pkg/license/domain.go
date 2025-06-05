package license

import (
	"time"
)

// LicenseVerificationRequest represents a request to verify a license and send telemetry
type LicenseVerificationRequest struct {
	License         string `json:"license"`
	AppVersion      string `json:"appVersion"`
	InstallationID  string `json:"installationId"`
	KubeVersion     string `json:"kubeVersion"`
	OrgMembersCount int    `json:"orgMembersCount"`
	ProjectsCount   int    `json:"projectsCount"`
}

// LicenseVerificationResponse represents the response from a license verification
type LicenseVerificationResponse struct {
	Valid           bool      `json:"valid"`
	ExpiresAt       time.Time `json:"expiresAt"`
	MaxUsers        int       `json:"maxUsers"`
	EnabledFeatures []string  `json:"enabledFeatures"`
	Message         string    `json:"message,omitempty"`
}
