package clients

import (
	"context"
	"time"

	user "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/user"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
)

type UserClient struct {
	client user.UserServiceClient
}

func NewUserClient(conn *grpc.ClientConn) *UserClient {
	return &UserClient{
		client: user.NewUserServiceClient(conn),
	}
}

func (c *UserClient) Create(email, name, password string, skipPasswordChange bool, providers []*user.RepositoryProvider) (*user.User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &user.CreateRequest{
		Email:               email,
		Name:                name,
		Password:            password,
		SkipPasswordChange:  skipPasswordChange,
		RepositoryProviders: providers,
	}

	user, err := c.client.Create(ctx, req)
	if err != nil {
		log.Errorf("Failed to create user: %v", err)
		return nil, err
	}

	log.Infof("Created user: ID=%s, Name=%s, Email=%s", user.GetId(), user.GetName(), user.GetEmail())
	return user, nil
}

func (c *UserClient) RegenerateToken(userId string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &user.RegenerateTokenRequest{
		UserId: userId,
	}

	resp, err := c.client.RegenerateToken(ctx, req)
	if err != nil {
		log.Errorf("Failed to regenerate token for user %s: %v", userId, err)
		return "", err
	}

	log.Infof("Regenerated token for user: ID=%s", userId)
	return resp.GetApiToken(), nil
}
