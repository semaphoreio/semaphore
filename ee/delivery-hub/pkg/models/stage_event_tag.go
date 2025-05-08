package models

import (
	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/gorm"
)

type StageEventTag struct {
	Name         string
	Value        string
	StageEventID uuid.UUID
	Healthy      bool
}

func CreateStageEventTag(name, value string, stageEventID uuid.UUID) error {
	return CreateStageEventTagInTransaction(database.Conn(), name, value, stageEventID)
}

func CreateStageEventTagInTransaction(tx *gorm.DB, name, value string, stageEventID uuid.UUID) error {
	v := StageEventTag{
		Name:         name,
		Value:        value,
		StageEventID: stageEventID,
		Healthy:      true,
	}

	return tx.Create(&v).Error
}

type StageTagState struct {
	StageID  uuid.UUID
	TagName  string
	TagValue string
	State    string
	Healthy  bool
}

func FindTagStates(name string) ([]StageTagState, error) {
	var values []StageTagState

	err := database.Conn().
		Table("tags AS t").
		Joins("INNER JOIN stage_events AS e ON e.id = t.stage_event_id").
		Select("e.stage_id, t.name, t.value, e.state, t.healthy").
		Where("name = ?", name).
		Find(&values).
		Error

	if err != nil {
		return nil, err
	}

	return values, nil
}
