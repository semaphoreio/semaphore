package jobdeletion

import (
	"encoding/json"

	uuid "github.com/satori/go.uuid"
)

type JobDeletedEvent struct {
	JobID          uuid.UUID `json:"job_id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	ProjectID      uuid.UUID `json:"project_id"`
	ArtifactID     uuid.UUID `json:"artifact_id"`
}

func ParseJobDeletedEvent(raw []byte) (*JobDeletedEvent, error) {
	event := &JobDeletedEvent{}

	err := json.Unmarshal(raw, &event)
	if err != nil {
		return nil, err
	}

	return event, nil
}

func (e *JobDeletedEvent) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}
