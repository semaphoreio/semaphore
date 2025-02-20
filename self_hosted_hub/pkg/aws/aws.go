package aws

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

var allowedRegex = regexp.MustCompile(`^arn:aws:sts::.+:assumed-role\/(.+)\/(.+)$`)

type PreSignedURLResponse struct {
	GetCallerIdentityResponse GetCallerIdentityResponse
}

type GetCallerIdentityResponse struct {
	GetCallerIdentityResult GetCallerIdentityResult
}

type GetCallerIdentityResult struct {
	Account string
	Arn     string
	UserId  string
}

func IsSTSURL(URL *url.URL) bool {
	return URL.Scheme == "https" && URL.Host == "sts.amazonaws.com"
}

func AssignNameFromSTS(ctx context.Context, httpClient *http.Client, accountID string, rolePatterns []string, URL string) (string, error) {
	response, err := execRequest(ctx, httpClient, URL)
	if err != nil {
		return "", err
	}

	name, err := Validate(accountID, rolePatterns, response)
	if err != nil {
		return "", err
	}

	return name, nil
}

func Validate(accountID string, rolePatterns []string, response *GetCallerIdentityResult) (string, error) {
	if accountID != response.Account {
		return "", fmt.Errorf("AWS account '%s' is not allowed", response.Account)
	}

	matches := allowedRegex.FindStringSubmatch(response.Arn)
	if matches == nil || len(matches) < 3 {
		return "", fmt.Errorf("ARN '%s' is not allowed", response.Arn)
	}

	roleName := matches[1]
	sessionId := matches[2]
	if !MatchesAnyRole(rolePatterns, roleName) {
		return "", fmt.Errorf("ARN '%s' is not allowed", response.Arn)
	}

	return sessionId, nil
}

func execRequest(ctx context.Context, httpClient *http.Client, URL string) (*GetCallerIdentityResult, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, URL, nil)
	if err != nil {
		return nil, fmt.Errorf("error building request to AWS STS: %v", err)
	}

	// We need to explicit set application/json.
	// AWS will give us XML back, if not.
	req.Header.Set("Accept", "application/json")

	res, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("error executing request to AWS STS: %v", err)
	}

	body, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, fmt.Errorf("error reading response from AWS STS: %v", err)
	}

	signedURLResponse := PreSignedURLResponse{}
	err = json.Unmarshal(body, &signedURLResponse)
	if err != nil {
		return nil, fmt.Errorf("error parsing response from AWS STS: %v", err)
	}

	return &signedURLResponse.GetCallerIdentityResponse.GetCallerIdentityResult, nil
}

func MatchesAnyRole(rolePatterns []string, roleName string) bool {
	for _, rolePattern := range rolePatterns {
		if match, _ := regexp.MatchString(HandleWildcards(rolePattern), roleName); match {
			return true
		}
	}

	return false
}

func HandleWildcards(pattern string) string {
	components := strings.Split(pattern, "*")

	// No * is used -> exact match
	if len(components) == 1 {
		return "^" + regexp.QuoteMeta(pattern) + "$"
	}

	var result strings.Builder
	for i, literal := range components {
		if i > 0 {
			result.WriteString(".*")
		}
		result.WriteString(regexp.QuoteMeta(literal))
	}

	return "^" + result.String() + "$"
}
