package shared

import (
	"fmt"
	"regexp"
	"strings"
)

var (
	uuidPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
)

// ValidateUUID ensures a string is a valid UUID format.
func ValidateUUID(value, fieldName string) error {
	value = strings.ToLower(strings.TrimSpace(value))
	if value == "" {
		return fmt.Errorf("%s is required", fieldName)
	}
	if !uuidPattern.MatchString(value) {
		return fmt.Errorf("%s must be a valid UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx), got: %s", fieldName, value)
	}
	return nil
}

// ValidateEnum ensures a value is one of the allowed options.
func ValidateEnum(value string, allowed []string, fieldName string) error {
	value = strings.ToLower(strings.TrimSpace(value))
	if value == "" && len(allowed) > 0 {
		return fmt.Errorf("%s must be one of: %v", fieldName, allowed)
	}

	for _, v := range allowed {
		if value == strings.ToLower(v) {
			return nil
		}
	}

	return fmt.Errorf("%s must be one of %v, got: %s", fieldName, allowed, value)
}

// NormalizeMode validates and normalizes mode parameter (summary/detailed).
func NormalizeMode(mode string) (string, error) {
	mode = strings.ToLower(strings.TrimSpace(mode))
	if mode == "" {
		return "summary", nil
	}

	if err := ValidateEnum(mode, []string{"summary", "detailed"}, "mode"); err != nil {
		return "", err
	}

	return mode, nil
}
