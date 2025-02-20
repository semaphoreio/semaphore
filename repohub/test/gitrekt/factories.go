package gitrekt_test

import (
	"fmt"
	"os"

	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
)

func GithubHelloWorldTestRepo() (*gitrekt.Repository, error) {
	token := os.Getenv("REPOHUB_TEST_GH_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("REPOHUB_TEST_GH_TOKEN is not set")
	}

	creds := &gitrekt.Credentials{
		Username: "x-oauth-token",
		Password: token,
	}

	return &gitrekt.Repository{
		Name:        "integration-repo",
		HttpURL:     "https://github.com/renderedtext/integration-repo.git",
		Credentials: creds,
	}, nil
}
