package testsupport

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	jwt "github.com/golang-jwt/jwt/v5"

	ia "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/repository_integrator"
)

const FakeRepositoryIntegratorServiceAppID int = 95937
const FakeRepositoryIntegratorServiceInstallationID string = "14043104"

type FakeRepositoryIntegratorService struct {
	ia.UnimplementedRepositoryIntegratorServiceServer
}

func (*FakeRepositoryIntegratorService) GetToken(ctx context.Context, in *ia.GetTokenRequest) (*ia.GetTokenResponse, error) {
	switch in.IntegrationType {
	case ia.IntegrationType_GITHUB_APP:
		return GetGithubAppToken(in)
	case ia.IntegrationType_GITHUB_OAUTH_TOKEN:
		return GetGithubOauthToken(in)
	case ia.IntegrationType_BITBUCKET:
		return GetBitbucketToken(in)
	case ia.IntegrationType_GITLAB:
		return GetGitlabToken(in)
	}
	return nil, fmt.Errorf("invalid integration type")
}

func GetGithubAppToken(in *ia.GetTokenRequest) (*ia.GetTokenResponse, error) {
	base64PrivatePEM := os.Getenv("REPOHUB_TEST_GH_APP_PRIVATE_KEY")
	if base64PrivatePEM == "" {
		return nil, fmt.Errorf("REPOHUB_TEST_GH_APP_PRIVATE_KEY is not set")
	}

	privatePEM, err := base64.StdEncoding.DecodeString(base64PrivatePEM)
	if err != nil {
		return nil, fmt.Errorf("Failed to decode private key")
	}

	privateKEY, _ := jwt.ParseRSAPrivateKeyFromPEM([]byte(privatePEM))

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iat": time.Now().Unix(),
		"exp": time.Now().Add(10 * time.Minute).Unix(),
		"iss": FakeRepositoryIntegratorServiceAppID,
	})

	tokenString, _ := token.SignedString(privateKEY)

	url := "https://api.github.com/app/installations/" + FakeRepositoryIntegratorServiceInstallationID + "/access_tokens"
	client := &http.Client{
		Timeout: time.Second * 10,
	}
	req, _ := http.NewRequest("POST", url, nil)
	req.Header.Set("Authorization", "Bearer "+tokenString)
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	response, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	var data map[string]interface{}
	err = json.NewDecoder(response.Body).Decode(&data)
	if err != nil {
		return nil, err
	}

	stringToken, _ := data["token"].(string)

	return &ia.GetTokenResponse{
		Token: stringToken,
	}, nil
}

func GetGithubOauthToken(in *ia.GetTokenRequest) (*ia.GetTokenResponse, error) {
	token := os.Getenv("REPOHUB_TEST_GH_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("REPOHUB_TEST_GH_TOKEN is not set")
	}

	return &ia.GetTokenResponse{
		Token: token,
	}, nil
}

func GetBitbucketToken(in *ia.GetTokenRequest) (*ia.GetTokenResponse, error) {
	token := os.Getenv("REPOHUB_TEST_BB_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("REPOHUB_TEST_BB_TOKEN is not set")
	}

	return &ia.GetTokenResponse{
		Token: token,
	}, nil
}

func GetGitlabToken(in *ia.GetTokenRequest) (*ia.GetTokenResponse, error) {
	token := os.Getenv("REPOHUB_TEST_GITLAB_TOKEN")
	if token == "" {
		return nil, fmt.Errorf("REPOHUB_TEST_GITLAB_TOKEN is not set")
	}

	return &ia.GetTokenResponse{
		Token: token,
	}, nil
}
