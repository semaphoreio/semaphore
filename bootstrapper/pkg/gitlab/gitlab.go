package gitlab

import (
	"os"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/random"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/retry"
)

func ConfigureApp(instanceConfigClient *clients.InstanceConfigClient) error {
	return retry.WithConstantWait("gitlab app configuration", 5, 10*time.Second, func() error {
		return instanceConfigClient.ConfigureGitlabApp(appParams(random.Base64String(32)))
	})
}

func appParams(webhookSecret string) map[string]string {
	return map[string]string{
		"client_id":      os.Getenv("GITLAB_APPLICATION_CLIENT_ID"),
		"client_secret":  os.Getenv("GITLAB_APPLICATION_CLIENT_SECRET"),
		"webhook_secret": webhookSecret,
	}
}
