package models

import (
	"strings"
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type Stage struct {
	ID             uuid.UUID `gorm:"type:uuid;primary_key;"`
	OrganizationID uuid.UUID
	CanvasID       uuid.UUID
	Name           string
	CreatedAt      *time.Time
}

func FindStageByName(orgID, canvasID uuid.UUID, name string) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Where("name = ?", name).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func FindStageByID(id, orgID, canvasID uuid.UUID) (*Stage, error) {
	var stage Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Where("id = ?", id).
		First(&stage).
		Error

	if err != nil {
		return nil, err
	}

	return &stage, nil
}

func ListStagesByCanvasID(orgID, canvasID uuid.UUID) ([]Stage, error) {
	var stages []Stage

	err := database.Conn().
		Where("organization_id = ?", orgID).
		Where("canvas_id = ?", canvasID).
		Order("name ASC").
		Find(&stages).
		Error

	if err != nil {
		return nil, err
	}

	return stages, nil
}

func CreateStage(orgID uuid.UUID, canvasID uuid.UUID, name string, connections []StageConnection) error {
	now := time.Now()
	ID := uuid.New()

	return database.Conn().Transaction(func(tx *gorm.DB) error {
		stage := &Stage{
			ID:             ID,
			OrganizationID: orgID,
			CanvasID:       canvasID,
			Name:           name,
			CreatedAt:      &now,
		}

		err := tx.Clauses(clause.Returning{}).Create(&stage).Error
		if err != nil {
			if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
				return ErrNameAlreadyUsed
			}

			return err
		}

		for _, i := range connections {
			c := i
			c.StageID = ID
			err := tx.Create(&c).Error
			if err != nil {
				return err
			}
		}

		return nil
	})
}
