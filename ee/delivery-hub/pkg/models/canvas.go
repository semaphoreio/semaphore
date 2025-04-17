package models

import (
	"fmt"
	"strings"
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/datatypes"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrNameAlreadyUsed = fmt.Errorf("name already used")

type Canvas struct {
	ID             uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	Name           string
	OrganizationID uuid.UUID
	CreatedAt      *time.Time
	CreatedBy      uuid.UUID
	UpdatedAt      *time.Time
}

func (Canvas) TableName() string {
	return "canvases"
}

// NOTE: caller must encrypt the key before calling this method.
func (c *Canvas) CreateEventSource(name string, key []byte) (*EventSource, error) {
	now := time.Now()

	eventSource := EventSource{
		Name:           name,
		OrganizationID: c.OrganizationID,
		CanvasID:       c.ID,
		CreatedAt:      &now,
		UpdatedAt:      &now,
		Key:            key,
	}

	err := database.Conn().
		Clauses(clause.Returning{}).
		Create(&eventSource).
		Error

	if err == nil {
		return &eventSource, nil
	}

	if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
		return nil, ErrNameAlreadyUsed
	}

	return nil, err
}

func (c *Canvas) CreateStage(name string, createdBy uuid.UUID, approvalRequired bool, template RunTemplate, connections []StageConnection) error {
	now := time.Now()
	ID := uuid.New()

	return database.Conn().Transaction(func(tx *gorm.DB) error {
		stage := &Stage{
			ID:               ID,
			OrganizationID:   c.OrganizationID,
			CanvasID:         c.ID,
			Name:             name,
			ApprovalRequired: approvalRequired,
			CreatedAt:        &now,
			CreatedBy:        createdBy,
			RunTemplate:      datatypes.NewJSONType(template),
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

func FindCanvasByID(id uuid.UUID, organizationID uuid.UUID) (*Canvas, error) {
	canvas := Canvas{}

	err := database.Conn().
		Where("id = ?", id).
		Where("organization_id = ?", organizationID).
		First(&canvas).
		Error

	if err != nil {
		return nil, err
	}

	return &canvas, nil
}

func CreateCanvas(orgID, requesterID uuid.UUID, name string) (*Canvas, error) {
	now := time.Now()
	canvas := Canvas{
		OrganizationID: orgID,
		Name:           name,
		CreatedAt:      &now,
		CreatedBy:      requesterID,
		UpdatedAt:      &now,
	}

	err := database.Conn().
		Clauses(clause.Returning{}).
		Create(&canvas).
		Error

	if err == nil {
		return &canvas, nil
	}

	if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
		return nil, ErrNameAlreadyUsed
	}

	return nil, err
}
