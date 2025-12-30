package shared

import (
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/config"
)

var (
	uuidPattern          = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
	cursorPattern        = regexp.MustCompile(`^[A-Za-z0-9\-_.:/+=]*$`)
	branchPattern        = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._/@-]{0,254}$`)
	requesterPattern     = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]{0,62}$`)
	repositoryURLPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:/._?#=&%+\-@]*$`)
)

// ExtractUserID gets the user ID from the X-Semaphore-User-ID header.
// In dev mode, returns DevUserID without validation.
func ExtractUserID(headerValue string) (string, error) {
	if config.IsDevMode() {
		return config.DevUserID, nil
	}

	userID := strings.ToLower(strings.TrimSpace(headerValue))
	if err := ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
		return "", err
	}
	return userID, nil
}

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

// SanitizeCursorToken validates pagination tokens before sending them to downstream services.
func SanitizeCursorToken(raw, fieldName string) (string, error) {
	if hasControlRune(raw) {
		return "", fmt.Errorf("%s contains control characters", fieldName)
	}

	value := strings.TrimSpace(raw)
	if value == "" {
		return "", nil
	}
	if utf8.RuneCountInString(value) > 512 {
		return "", fmt.Errorf("%s must not exceed 512 characters", fieldName)
	}
	if !cursorPattern.MatchString(value) {
		return "", fmt.Errorf("%s contains unsupported characters. Allowed: letters, numbers, and - _ . : / + =", fieldName)
	}
	return value, nil
}

// SanitizeBranch ensures branch filters only contain characters that cannot alter backend queries.
func SanitizeBranch(raw, fieldName string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", nil
	}
	if utf8.RuneCountInString(value) > 255 {
		return "", fmt.Errorf("%s must not exceed 255 characters", fieldName)
	}
	if hasControlRune(value) {
		return "", fmt.Errorf("%s contains control characters", fieldName)
	}
	if strings.Contains(value, "..") || strings.Contains(value, "//") || strings.Contains(value, "@{") {
		return "", fmt.Errorf("%s contains unsupported sequences", fieldName)
	}
	if !branchPattern.MatchString(value) {
		return "", fmt.Errorf("%s may only contain letters, numbers, slash (/), dot (.), underscore (_), hyphen (-), or @", fieldName)
	}
	return value, nil
}

// SanitizeRequesterFilter validates non-UUID requester identifiers prior to user lookup.
func SanitizeRequesterFilter(raw, fieldName string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", nil
	}
	if utf8.RuneCountInString(value) > 64 {
		return "", fmt.Errorf("%s must not exceed 64 characters", fieldName)
	}
	if hasControlRune(value) {
		return "", fmt.Errorf("%s contains control characters", fieldName)
	}
	lower := strings.ToLower(value)
	if !requesterPattern.MatchString(lower) {
		return "", fmt.Errorf("%s may only contain lowercase letters, numbers, dot (.), underscore (_), or hyphen (-)", fieldName)
	}
	return lower, nil
}

// SanitizeSearchQuery strips characters commonly used for injection while allowing flexible search terms.
func SanitizeSearchQuery(raw, fieldName string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", nil
	}
	if utf8.RuneCountInString(value) > 256 {
		return "", fmt.Errorf("%s must not exceed 256 characters", fieldName)
	}
	if hasControlRune(value) {
		return "", fmt.Errorf("%s contains control characters", fieldName)
	}
	if strings.ContainsAny(value, `"'\\`) {
		return "", fmt.Errorf("%s must not contain quotes or backslashes", fieldName)
	}
	return value, nil
}

// SanitizeDocsSearchQuery validates and sanitizes search queries for GitHub docs search.
// It strips GitHub search operators to prevent query injection.
func SanitizeDocsSearchQuery(raw, fieldName string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", fmt.Errorf("%s is required", fieldName)
	}
	if utf8.RuneCountInString(value) > 256 {
		return "", fmt.Errorf("%s must not exceed 256 characters", fieldName)
	}
	if hasControlRune(value) {
		return "", fmt.Errorf("%s contains control characters", fieldName)
	}

	// Remove GitHub search operators that could alter the query scope
	operators := []string{"repo:", "path:", "user:", "org:", "language:", "filename:", "extension:"}
	lower := strings.ToLower(value)
	for _, op := range operators {
		if strings.Contains(lower, op) {
			return "", fmt.Errorf("%s must not contain search operators like %s", fieldName, op)
		}
	}

	return value, nil
}

// SanitizeRepositoryURLFilter restricts repository_url filters to URL-safe characters.
func SanitizeRepositoryURLFilter(raw, fieldName string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", nil
	}
	if utf8.RuneCountInString(value) > 512 {
		return "", fmt.Errorf("%s must not exceed 512 characters", fieldName)
	}
	if hasControlRune(value) {
		return "", fmt.Errorf("%s contains control characters", fieldName)
	}
	if !repositoryURLPattern.MatchString(value) {
		return "", fmt.Errorf("%s contains unsupported characters. Allowed: letters, numbers, and URL punctuation (:/._?#=&%%+-@)", fieldName)
	}
	return value, nil
}

func hasControlRune(value string) bool {
	for _, r := range value {
		if r < 32 || r == 127 {
			return true
		}
	}
	return false
}
