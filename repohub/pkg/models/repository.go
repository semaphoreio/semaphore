package models

import (
	"fmt"
	"log"
	"time"

	gorm "github.com/jinzhu/gorm"
	uuid "github.com/satori/go.uuid"

	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
)

type Repository struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()"`
	ProjectID uuid.UUID

	HookID             string
	Name               string
	Owner              string
	Private            bool
	Provider           string
	URL                string
	EnableCommitStatus bool
	PipelineFile       string
	IntegrationType    string
	DefaultBranch      string

	CreatedAt *time.Time
	UpdatedAt *time.Time
}

func RepositoryCount(db *gorm.DB) (int, error) {
	var count int

	err := db.Model(&Repository{}).Count(&count).Error

	if err != nil {
		return 0, err
	}

	return count, nil
}

func ListAllRepositories(db *gorm.DB) ([]Repository, error) {
	repos := []Repository{}

	err := db.Order(gorm.Expr("random()")).Find(&repos).Error

	if err != nil {
		log.Printf("Unexpected erorr while looking up repositories: %+v", err)

		return nil, fmt.Errorf("Error while listing repositories")
	}

	return repos, nil
}

func ListRepositoriesForProject(db *gorm.DB, projectID string) ([]Repository, error) {
	repos := []Repository{}

	err := db.Where("project_id = ?", projectID).Find(&repos).Error

	if err != nil {
		log.Printf("Unexpected error while looking up repositories for project %s %+v", projectID, err)

		return nil, fmt.Errorf("Error while listing repositories for project %s", projectID)
	}

	return repos, nil
}

func FindRepository(db *gorm.DB, id string) (*Repository, error) {
	r := &Repository{}

	err := db.Where("id = ?", id).First(r).Error

	if err != nil {
		return nil, err
	}

	return r, nil
}

func (r *Repository) ToGitrektRepository() *gitrekt.Repository {
	gitHost := "github.com"

	switch r.Provider {
	case "bitbucket":
		gitHost = "bitbucket.org"
	case "gitlab":
		gitHost = "gitlab.com"
	case "github":
	default:
		gitHost = "github.com"

	}
	return &gitrekt.Repository{
		Name:    r.ID.String(),
		HttpURL: fmt.Sprintf("https://%s/%s/%s", gitHost, r.Owner, r.Name),
	}
}

func (r *Repository) Slug() string {
	return fmt.Sprintf("%s/%s", r.Owner, r.Name)
}
