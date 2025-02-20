package service

import (
	"fmt"
	"log"

	"github.com/semaphoreio/semaphore/velocity/pkg/entity"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Organization struct {
	Id uuid.UUID
}

func LookupOrganization(options ...OrganizationFinder) (Organization, error) {
	organization := &Organization{
		Id: uuid.Nil,
	}

	for _, option := range options {
		option(organization)
		if organization.Id != uuid.Nil {
			return *organization, nil
		}
	}
	return *organization, fmt.Errorf("failed to find organization")
}

type OrganizationFinder func(*Organization)

func FindOrganizationInDB(db *gorm.DB, projectId uuid.UUID) OrganizationFinder {
	return func(organization *Organization) {
		result := &entity.ProjectMTTR{}

		err := db.
			Where("project_id = ?", projectId).
			Select("organization_id").
			Find(&result).
			Error

		if err != nil {
			log.Printf("Failed to find organization for project %s: %v", projectId, err)
			return
		}

		organization.Id = result.OrganizationId
	}
}

func FindOrganizationInGrpc(client ProjectHubClient, projectId uuid.UUID) OrganizationFinder {
	return func(organization *Organization) {
		response, err := client.Describe(&ProjectHubDescribeOptions{
			ProjectID: projectId.String(),
		})

		if err != nil {
			log.Printf("Failed to find organization for project %s: %v", projectId, err)
			return
		}

		fmt.Printf("%v", response.Project.Metadata.OrgId)

		organization.Id = uuid.MustParse(response.Project.Metadata.OrgId)
	}
}
