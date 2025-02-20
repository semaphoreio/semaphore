package models

import (
	"time"

	"github.com/google/uuid"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"gorm.io/gorm"
)

type OccupationRequest struct {
	OrganizationID uuid.UUID `gorm:"primaryKey"`
	AgentTypeName  string    `gorm:"primaryKey"`
	JobID          uuid.UUID `gorm:"primaryKey"`
	CreatedAt      *time.Time
}

func CreateOccupationRequest(orgID uuid.UUID, agentTypeName string, jobID uuid.UUID) error {
	_, err := FindOccupationRequest(orgID, agentTypeName, jobID)
	if err == nil {
		return nil
	}

	request := &OccupationRequest{
		OrganizationID: orgID,
		AgentTypeName:  agentTypeName,
		JobID:          jobID,
	}

	err = database.Conn().Create(&request).Error
	if err != nil {
		return err
	}

	return nil
}

func FindOccupationRequest(orgID uuid.UUID, agentTypeName string, jobID uuid.UUID) (*OccupationRequest, error) {
	return FindOccupationRequestInTransaction(database.Conn(), orgID, agentTypeName, jobID)
}

func FindOccupationRequestInTransaction(tx *gorm.DB, orgID uuid.UUID, agentTypeName string, jobID uuid.UUID) (*OccupationRequest, error) {
	request := &OccupationRequest{}

	query := tx.Where("organization_id = ?", orgID)
	query = query.Where("agent_type_name = ?", agentTypeName)
	query = query.Where("job_id = ?", jobID)

	err := query.First(request).Error
	if err != nil {
		return nil, err
	}

	return request, nil
}
