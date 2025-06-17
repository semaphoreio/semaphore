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

// SearchUsers searches for users based on a query string.
// The query can match against user's name, email, or other searchable fields.
// limit specifies the maximum number of users to return (0 means use server default).
func (c *UserClient) SearchUsers(query string, limit int32) ([]*user.User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	req := &user.SearchUsersRequest{
		Query: query,
		Limit: limit,
	}

	resp, err := c.client.SearchUsers(ctx, req)
	if err != nil {
		log.Errorf("Failed to search users with query '%s': %v", query, err)
		return nil, err
	}

	users := resp.GetUsers()
	log.Debugf("Found %d users matching query '%s'", len(users), query)
	return users, nil
}
