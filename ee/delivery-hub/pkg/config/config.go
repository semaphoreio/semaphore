package config

import (
	"fmt"
	"os"
)

func RepoProxyURL() (string, error) {
	URL := os.Getenv("INTERNAL_API_URL_REPO_PROXY")
	if URL == "" {
		return "", fmt.Errorf("INTERNAL_API_URL_REPO_PROXY not set")
	}

	return URL, nil
}
