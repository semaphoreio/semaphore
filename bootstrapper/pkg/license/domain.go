package license

import (
	"time"
)

// LicenseVerificationRequest represents a request to verify a license and send telemetry
type LicenseVerificationRequest struct {
	LicenseJWT  string `json:"licenseJwt"`
	Hostname    string `json:"hostname"`
	IPAddress   string `json:"ipAddress"`
	Environment string `json:"environment"`
	Version     string `json:"version"`
}

// LicenseVerificationResponse represents the response from a license verification
type LicenseVerificationResponse struct {
	Valid           bool      `json:"valid"`
	ExpiresAt       time.Time `json:"expiresAt"`
	MaxUsers        int       `json:"maxUsers"`
	EnabledFeatures []string  `json:"enabledFeatures"`
	Message         string    `json:"message,omitempty"`
}
