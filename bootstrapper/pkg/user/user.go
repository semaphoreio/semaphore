package user

import (
	"os"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/config"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/github"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/user"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/random"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/retry"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func CreateSemaphoreUser(kubernetesClient *kubernetes.KubernetesClient, name, email, secretName string) string {
	password := random.Base64String(20)
	conn, err := grpc.NewClient(config.UserEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to user service: %v", err)
	}

	defer conn.Close()

	client := clients.NewUserClient(conn)
	user := createUser(client, email, name, password)
	apiToken := regenerateAPIToken(client, user.GetId())
	err = kubernetesClient.UpsertSecret(secretName, map[string]string{
		"email":    email,
		"password": password,
		"token":    apiToken,
	})

	if err != nil {
		log.Fatalf("Failed to upsert secret: %v", err)
	}

	return user.GetId()
}

func createUser(userClient *clients.UserClient, email, name, password string) *user.User {
	skipPasswordChange := true

	var user *user.User
	err := retry.WithConstantWait("user creation", 5, 10*time.Second, func() error {
		u, err := userClient.Create(email, name, password, skipPasswordChange, repositoryProviders())
		if err != nil {
			return err
		}

		user = u
		return nil
	})

	if err != nil {
		log.Fatalf("Failed to create user: %v", err)
	}

	return user
}

func regenerateAPIToken(client *clients.UserClient, userId string) string {
	var apiToken string
	err := retry.WithConstantWait("api token creation", 5, 10*time.Second, func() error {
		token, err := client.RegenerateToken(userId)
		if err != nil {
			return err
		}

		apiToken = token
		return nil
	})

	if err != nil {
		log.Fatalf("Failed to create API token: %v", err)
	}

	return apiToken
}

func repositoryProviders() []*user.RepositoryProvider {
	githubLogin := os.Getenv("ROOT_GITHUB_LOGIN")
	if githubLogin == "" {
		log.Info("No github login provided, not configuring providers")
		return []*user.RepositoryProvider{}
	}

	id, err := github.GetUserId(githubLogin)
	if err != nil {
		log.Warnf("Error getting github user id for %s, not configuring providers: %v", githubLogin, err)
		return []*user.RepositoryProvider{}
	}

	log.Infof("GitHub user ID for %s: %s", githubLogin, id)
	return []*user.RepositoryProvider{
		{
			Type:  user.RepositoryProvider_GITHUB,
			Login: githubLogin,
			Uid:   id,
		},
	}
}
