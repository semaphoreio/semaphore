package models

import (
	"fmt"
	"strings"
	"time"

	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm/clause"
)

var ErrNameAlreadyUsed = fmt.Errorf("name already used")

type Canvas struct {
	ID             uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	Name           string
	OrganizationID uuid.UUID
	CreatedAt      *time.Time
	UpdatedAt      *time.Time
}

func (Canvas) TableName() string {
	return "canvases"
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

func CreateCanvas(orgID uuid.UUID, name string) (*Canvas, error) {
	now := time.Now()
	canvas := Canvas{
		OrganizationID: orgID,
		Name:           name,
		CreatedAt:      &now,
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
