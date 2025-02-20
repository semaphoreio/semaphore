package testsupport

import (
	models "github.com/semaphoreio/semaphore/repohub/pkg/models"
)

func CreateRepository() *models.Repository {
	return CreateGithubTokenRepository()
}

func CreateGithubTokenRepository() *models.Repository {
	repo := models.Repository{
		Name:            "integration-repo",
		Owner:           "renderedtext",
		Provider:        "github",
		IntegrationType: "github_oauth_token",
	}

	err := DB.Create(&repo).Error

	if err != nil {
		panic(err)
	}

	return &repo
}

func CreateBitbucketTokenRepository() *models.Repository {
	repo := models.Repository{
		Name:            "integration-repo",
		Owner:           "renderedtext",
		Provider:        "github",
		IntegrationType: "github_oauth_token",
	}

	err := DB.Create(&repo).Error

	if err != nil {
		panic(err)
	}

	return &repo
}

func CreateGitlabTokenRepository() *models.Repository {
	repo := models.Repository{
		Name:            "integration-repo",
		Owner:           "renderedtext",
		Provider:        "gitlab",
		IntegrationType: "gitlab",
	}

	err := DB.Create(&repo).Error

	if err != nil {
		panic(err)
	}

	return &repo
}

func CreateGithubAppRepository() *models.Repository {
	repo := models.Repository{
		Name:            "secret-one",
		Owner:           "dummy-one",
		Provider:        "github",
		IntegrationType: "github_app",
	}

	err := DB.Create(&repo).Error

	if err != nil {
		panic(err)
	}

	return &repo
}

func CreateGithubAppNotInstalledRepository() *models.Repository {
	repo := models.Repository{
		Name:            "secret-two",
		Owner:           "dummy-one",
		Provider:        "github",
		IntegrationType: "github_app",
	}

	err := DB.Create(&repo).Error

	if err != nil {
		panic(err)
	}

	return &repo
}

func CreateNotExistingRepository() *models.Repository {
	repo := models.Repository{
		Name:            "hello-void",
		Owner:           "semaforko-vcr-tester",
		Provider:        "github",
		IntegrationType: "github_oauth_token",
	}

	err := DB.Create(&repo).Error

	if err != nil {
		panic(err)
	}

	return &repo
}
