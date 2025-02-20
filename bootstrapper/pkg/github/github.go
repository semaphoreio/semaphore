package github

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/random"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/retry"
)

func ConfigureApp(instanceConfigClient *clients.InstanceConfigClient, repoProxyClient *clients.RepoProxyClient, appName string) error {
	return retry.WithConstantWait("github app configuration", 5, 10*time.Second, func() error {
		err := instanceConfigClient.ConfigureGitHubApp(appParams(appName, random.Base64String(32)))
		if err == nil {
			return initApp(repoProxyClient)
		}

		return err
	})
}

func initApp(repoProxyClient *clients.RepoProxyClient) error {
	return retry.WithConstantWait("github app initialization", 5, 10*time.Second, func() error {
		return repoProxyClient.InitGithubApplication()
	})
}

func appParams(name, webhookSecret string) map[string]string {
	return map[string]string{
		"name":           name,
		"slug":           name,
		"html_url":       fmt.Sprintf("https://github.com/apps/%s", name),
		"app_id":         os.Getenv("GITHUB_APPLICATION_ID"),
		"client_id":      os.Getenv("GITHUB_APPLICATION_CLIENT_ID"),
		"client_secret":  os.Getenv("GITHUB_APPLICATION_CLIENT_SECRET"),
		"pem":            os.Getenv("GITHUB_APPLICATION_PRIVATE_KEY"),
		"webhook_secret": webhookSecret,
	}
}

type GithubUser struct {
	Login string `json:"login"`
	ID    int64  `json:"id"`
}

func GetUserId(login string) (string, error) {
	response, err := http.Get("https://api.github.com/users/" + login)
	if err != nil {
		return "", fmt.Errorf("request failed: %v", err)
	}

	if response.StatusCode != 200 {
		return "", fmt.Errorf("status code %d", response.StatusCode)
	}

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return "", fmt.Errorf("error reading response body: %v", err)
	}

	defer response.Body.Close()

	u := &GithubUser{}
	err = json.Unmarshal(body, u)
	if err != nil {
		return "", fmt.Errorf("error unmarshalling response body: %v", err)
	}

	return fmt.Sprintf("%d", u.ID), nil
}
