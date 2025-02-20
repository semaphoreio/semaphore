package tokenstore

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/semaphoreio/semaphore/repohub/pkg/config"
	"github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"

	ia_projecthub "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/projecthub"
	ia_repository_integrator "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/repository_integrator"
	ia_response_status "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/response_status"
	ia_user "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/user"
	"github.com/semaphoreio/semaphore/repohub/pkg/models"
)

type TokenStore struct {
}

type Project struct {
	Metadata struct {
		OwnerId string
	}
}

type User struct {
	UserId string
}

func New() *TokenStore {
	return &TokenStore{}
}

// FindCommitToken finds the integration token for commit operations
func (s *TokenStore) FindCommitToken(r *models.Repository, userID string) (string, error) {
	return s.findIntegrationToken(r.ProjectID.String(), strings.ToUpper(r.IntegrationType), userID, r.Slug())
}

// FindRepoToken finds the integration token for repository operations
func (s *TokenStore) FindRepoToken(r *models.Repository) (string, error) {
	project, err := s.findProject(r.ProjectID.String())
	if err != nil {
		return "", err
	}

	user, err := s.FindUser(project.Metadata.OwnerId)
	if err != nil {
		log.Printf("User not found %+v", err)
		return "", status.Error(codes.NotFound, "User not found")
	}

	return s.findIntegrationToken(r.ProjectID.String(), strings.ToUpper(r.IntegrationType), user.UserId, r.Slug())
}

func (s *TokenStore) FindUser(userID string) (*ia_user.DescribeResponse, error) {
	conn, err := grpc.Dial(config.UserAPIEndpoint(), grpc.WithInsecure())
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	log.Printf("Looking up user: %s", userID)

	client := ia_user.NewUserServiceClient(conn)
	req := ia_user.DescribeRequest{UserId: userID}

	res, err := client.Describe(context.Background(), &req)
	if err != nil {
		log.Printf("User lookup failed %+v", err)
		return nil, err
	}

	if res.Status.Code != ia_response_status.ResponseStatus_OK {
		log.Printf("User lookup failed %s", res.Status.Message)

		return nil, fmt.Errorf(res.Status.Message)
	}

	return res, nil
}

func (s *TokenStore) findIntegrationToken(projectID string, integrationType string, userID string, slug string) (string, error) {
	if integrationType == "BITBUCKET" || integrationType == "GITLAB" {
		return s.fetchRepositoryToken(userID, ia_repository_integrator.IntegrationType(ia_repository_integrator.IntegrationType_value[integrationType]))
	}

	conn, err := grpc.Dial(config.RepositoryIntegratorAPIEndpoint(), grpc.WithInsecure())
	if err != nil {
		return "", err
	}
	defer conn.Close()

	log.Printf("Looking up token for project: %s", projectID)

	client := ia_repository_integrator.NewRepositoryIntegratorServiceClient(conn)
	req := ia_repository_integrator.GetTokenRequest{
		ProjectId:       projectID,
		UserId:          userID,
		RepositorySlug:  slug,
		IntegrationType: ia_repository_integrator.IntegrationType(ia_repository_integrator.IntegrationType_value[integrationType]),
	}

	res, err := client.GetToken(context.Background(), &req)
	if err != nil {
		log.Printf("Project token lookup failed %+v", err)
		return "", err
	}

	return res.Token, nil
}

func (s *TokenStore) fetchRepositoryToken(userID string, integrationType ia_repository_integrator.IntegrationType) (string, error) {
	conn, err := grpc.Dial(config.UserAPIEndpoint(), grpc.WithInsecure())
	if err != nil {
		return "", err
	}
	defer conn.Close()

	log.Printf("Looking up user: %s", userID)

	client := ia_user.NewUserServiceClient(conn)
	req := ia_user.GetRepositoryTokenRequest{UserId: userID, IntegrationType: integrationType}

	res, err := client.GetRepositoryToken(context.Background(), &req)
	if err != nil {
		log.Printf("User lookup failed %+v", err)
		return "", err
	}

	return res.GetToken(), nil
}

func (s *TokenStore) findProject(projectID string) (*ia_projecthub.Project, error) {
	conn, err := grpc.Dial(config.ProjectAPIEndpoint(), grpc.WithInsecure())
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	client := ia_projecthub.NewProjectServiceClient(conn)
	req := ia_projecthub.DescribeRequest{Id: projectID, Metadata: &ia_projecthub.RequestMeta{OrgId: ""}}

	res, err := client.Describe(context.Background(), &req)
	if err != nil {
		return nil, err
	}
	if res.Metadata.Status.Code != ia_projecthub.ResponseMeta_OK {
		return nil, errors.New("Fetching project: " + res.Metadata.Status.Message)
	}

	log.Printf("Project found: %+v", res.Project)

	return res.Project, nil
}

// ToGitRektRepository sets up credentials for a gitrekt repository based on integration type
func ToGitRektRepository(r *models.Repository, token string) *gitrekt.Repository {
	var username string
	repo := r.ToGitrektRepository()

	switch strings.ToLower(r.IntegrationType) {
	case "github_app":
		username = "x-access-token"
	case "bitbucket":
		username = "x-token-auth"
	case "gitlab":
		username = "oauth2"
	case "github_oauth_token":
		username = "x-oauth-token"
	}

	repo.Credentials = &gitrekt.Credentials{
		Username: username,
		Password: token,
	}

	return repo
}
